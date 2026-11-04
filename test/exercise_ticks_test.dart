import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exercise_feedback.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/screens/exercise_ticks_widget.dart';

import 'support/exercise_invariants.dart';
import 'support/gen_sentence_learner.dart';
import 'support/i18n_keys.dart';
import 'support/key_echo_i18n.dart';
import 'support/latin_course.dart';

const _kind = ExerciseKind.satzAnkreuzen;

/// score / (k·B) of ticking [c] right and [w] wrong, as an exact fraction.
({int top, int bottom}) _share(int n, int k, int c, int w) => (
  top: c * pow(n + 1 - 2 * k, w).toInt(),
  bottom: k * pow(2 * (n - k), w).toInt(),
);

Rating _expectedRating(int n, int k, int c, int w) {
  final (:top, :bottom) = _share(n, k, c, w);
  return top == bottom
      ? Rating.good
      : 2 * top >= bottom
      ? Rating.hard
      : Rating.again;
}

/// Every non-empty set of indices below [n].
Iterable<Set<int>> _tickSets(int n) => [
  for (var mask = 1; mask < 1 << n; mask++)
    {
      for (var i = 0; i < n; i++)
        if (mask & 1 << i != 0) i,
    },
];

String _feedbackKey(({String text, Mistake? mistake}) option, bool ticked) =>
    switch ((option.mistake, ticked)) {
      (null, true) => 'exercise.ticks.feedback.rightTicked',
      (null, false) => 'exercise.ticks.feedback.rightLeft',
      (final m?, true) => 'exercise.ticks.feedback.wrongTicked.${m.name}',
      (_?, false) => 'exercise.ticks.feedback.wrongLeft',
    };

Map<String, dynamic> _translations(String code) =>
    jsonDecode(File('assets/flutter_i18n/$code.json').readAsStringSync())
        as Map<String, dynamic>;

String _translate(Map<String, dynamic> json, String key, String text) =>
    (key.split('.').fold<dynamic>(json, (node, k) => node[k]) as String)
        .replaceAll('{text}', text);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SentenceWorld world;
  final generator = generatorFor(_kind, exerciseGenerators) as SpecGenerator;

  setUpAll(() async {
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    world = (
      items: await loadAllPracticeItems(),
      curriculum: await loadCurriculum(latinCourse.books),
      lessons: await loadLessonData(latinCourse.books),
      corpus: await loadSentenceCorpus(),
      german: await container.read(germanFormsProvider.future),
    );
    container.dispose();
  });

  bool holds(Sentence s, PracticeItem word, GrammarBundle bundle) =>
      s.tokens.whereType<FormToken>().any(
        (t) =>
            t.lemma == word.lemma &&
            word.formOrder.contains(t.key) &&
            bundleOf(word, t.key) == bundle,
      );

  bool fits(Sentence s, SettingsLearner l) =>
      s.lesson <= l.ctx.reachedLesson! &&
      s.tokens.whereType<FormToken>().every((t) {
        final w = l.ctx.pool.where((w) => w.lemma == t.lemma).firstOrNull;
        if (w == null || !w.formOrder.contains(t.key)) return false;
        return l.ctx.unlocked.contains(bundleOf(w, t.key)) &&
            l.filter.formPracticed(
              w.dataFileId,
              w.formLabels[w.formOrder.indexOf(t.key)],
            );
      });

  /// homō in akk.sg, which sentence l24-ne-1 holds.
  (PracticeItem, GrammarBundle) homoAkkSg(SettingsLearner l) {
    final w = l.ctx.pool.singleWhere((w) => w.lemma == 'homō');
    return (w, bundleOf(w, 'akk.sg'));
  }

  /// A pair of the pool that a corpus sentence holds, or with chance 1/4 any
  /// bundle of any pool word; null for an empty pool.
  (PracticeItem, GrammarBundle)? drawPair(Random rng, SettingsLearner l) {
    final pool = l.ctx.pool;
    if (pool.isEmpty) return null;
    final held = [
      for (final s in world.corpus.sentences)
        for (final t in s.tokens.whereType<FormToken>())
          for (final w in pool)
            if (w.lemma == t.lemma && w.formOrder.contains(t.key))
              (w, bundleOf(w, t.key)),
    ];
    if (held.isNotEmpty && rng.nextInt(4) > 0) {
      return held[rng.nextInt(held.length)];
    }
    final word = pool[rng.nextInt(pool.length)];
    return (
      word,
      bundleOf(word, word.formOrder[rng.nextInt(word.formOrder.length)]),
    );
  }

  test('the tick score is never negative, gives B per right tick without a '
      'wrong one, and random extra ticks never raise the expected score', () {
    const table = [
      (n: 4, k: 1, c: 1, w: 0, score: 1.0),
      (n: 4, k: 1, c: 1, w: 1, score: 0.5),
      (n: 4, k: 1, c: 1, w: 2, score: 0.25),
      (n: 4, k: 2, c: 2, w: 0, score: 2.0),
      (n: 4, k: 2, c: 2, w: 1, score: 0.5),
      (n: 4, k: 2, c: 1, w: 1, score: 0.25),
      (n: 4, k: 2, c: 1, w: 0, score: 1.0),
      (n: 5, k: 2, c: 1, w: 1, score: 1 / 3),
      (n: 6, k: 3, c: 1, w: 1, score: 1 / 6),
    ];
    for (final (:n, :k, :c, :w, :score) in table) {
      expect(
        tickScore(n: n, k: k, c: c, w: w),
        closeTo(score, 1e-12),
        reason: 'n $n, k $k, c $c, w $w',
      );
    }
    int choose(int n, int r) => r < 0 || r > n
        ? 0
        : [
            for (var i = 0; i < r; i++) i,
          ].fold(1, (p, i) => p * (n - i) ~/ (i + 1));
    var cases = 0;
    for (var n = 3; n <= 8; n++) {
      for (var k = 1; 2 * k <= n; k++) {
        for (var c = 0; c <= k; c++) {
          for (var w = 0; w <= n - k; w++) {
            final score = tickScore(n: n, k: k, c: c, w: w);
            expect(score, greaterThanOrEqualTo(0), reason: '$n $k $c $w');
            if (c < k) {
              expect(
                tickScore(n: n, k: k, c: c + 1, w: 0) -
                    tickScore(n: n, k: k, c: c, w: 0),
                closeTo(1, 1e-12),
              );
            }
            cases++;
          }
        }
        // `sure` right ticks the learner knows, then `extra` random ones
        // among the other n - sure options.
        for (var sure = 0; sure <= k; sure++) {
          for (var extra = 1; extra <= n - sure; extra++) {
            var expected = 0.0;
            for (var x = 0; x <= extra; x++) {
              final ways = choose(k - sure, x) * choose(n - k, extra - x);
              if (ways == 0) continue;
              expected +=
                  ways /
                  choose(n - sure, extra) *
                  tickScore(n: n, k: k, c: sure + x, w: extra - x);
            }
            expect(
              expected,
              lessThan(sure == 0 ? 1 : sure),
              reason: 'n $n, k $k, $sure sure, $extra random',
            );
          }
        }
      }
    }
    expect(cases, greaterThan(100));
  });

  test('the rating is Good for the best score, Hard from half of it and '
      'Again below, for every tick set of every drawn exercise', () {
    final sentence = world.corpus.sentences.firstWhere(
      (s) => s.wrong.length == 3,
    );
    ({String text, Mistake? mistake}) right(int i) =>
        (text: sentence.right[i], mistake: null);
    ({String text, Mistake? mistake}) wrong(int i) =>
        (text: sentence.wrong[i].german, mistake: sentence.wrong[i].mistake);
    final k2 = TickAnswer(sentence, [right(0), right(1), wrong(0), wrong(1)]);
    final k1 = TickAnswer(sentence, [right(0), wrong(0), wrong(1), wrong(2)]);
    final fixed = [
      (k2, {0}, Rating.hard),
      (k2, {0, 1, 2}, Rating.again),
      (k1, {0, 1}, Rating.hard),
      (k2, {0, 1}, Rating.good),
      (k1, {0}, Rating.good),
      (k1, {1}, Rating.again),
    ];
    for (final (answer, ticked, rating) in fixed) {
      expect(tickRating(answer, ticked), rating, reason: '$ticked');
    }
    final rng = Random(324);
    final answers = <TickAnswer>[k1, k2];
    while (answers.length < 40) {
      final l = settingsLearnerOf(world, Settings());
      final (word, bundle) = drawPair(rng, l)!;
      try {
        answers.add(
          generator.build(word, bundle, l.ctx, rng).answer as TickAnswer,
        );
      } on CannotBuild {
        continue;
      }
    }
    for (final answer in answers) {
      final k = answer.right.length;
      for (final ticked in _tickSets(answer.options.length)) {
        final c = ticked.intersection(answer.right).length;
        final w = ticked.length - c;
        expect(
          tickRating(answer, ticked),
          _expectedRating(answer.options.length, k, c, w),
          reason: '${answer.sentence.id} k $k ticked $ticked',
        );
      }
    }
  });

  test('a learner gets a sentence exercise exactly when a sentence up to the '
      'Kursstand holds the asked cell with every form reached and practised, '
      'in the German UI; it shows k of 1 or 2 right renderings and the rest '
      'typical mistakes, rates and explains every tick set', () {
    final de = translationKeys('de');
    final en = translationKeys('en');
    final rng = Random(3240);
    final full = settingsLearnerOf(world, Settings());
    final early = settingsLearnerOf(world, Settings(kursstand: 1));
    final english = settingsLearnerOf(
      world,
      Settings(),
      german: const NoForms(),
    );
    final earlyWord = early.ctx.pool.first;
    final fixed = <(SettingsLearner, (PracticeItem, GrammarBundle)?)>[
      (full, homoAkkSg(full)),
      (early, (earlyWord, bundleOf(earlyWord, earlyWord.formOrder.first))),
      (english, homoAkkSg(english)),
    ];
    final ks = <int>{};
    final outcomes = <String, int>{};
    for (var run = 0; run < fixed.length + 300; run++) {
      final (l, pair) = run < fixed.length
          ? fixed[run]
          : () {
              final l = drawSettingsLearner(rng, world);
              return (l, drawPair(rng, l));
            }();
      if (pair == null) {
        outcomes.update('empty pool', (n) => n + 1, ifAbsent: () => 1);
        continue;
      }
      final (word, bundle) = pair;
      final candidates = [
        for (final s in world.corpus.sentences)
          if (fits(s, l) && holds(s, word, bundle)) s.id,
      ];
      final builds =
          !word.isVocab &&
          l.ctx.unlocked.contains(bundle) &&
          l.ctx.german is! NoForms &&
          candidates.isNotEmpty;
      final Exercise e;
      try {
        e = generator.build(word, bundle, l.ctx, rng);
      } on CannotBuild catch (error) {
        expect(builds, isFalse, reason: '${word.id} $bundle: $error');
        if (l.ctx.reachedLesson! <
            world.corpus.sentences.map((s) => s.lesson).reduce(min)) {
          if (!word.isVocab && l.ctx.unlocked.contains(bundle)) {
            expect(
              error.reason,
              'no sentence up to lesson ${l.ctx.reachedLesson}',
            );
            outcomes.update(
              'no sentence reached',
              (n) => n + 1,
              ifAbsent: () => 1,
            );
          }
        }
        if (l.ctx.german is NoForms &&
            candidates.isNotEmpty &&
            !word.isVocab &&
            l.ctx.unlocked.contains(bundle)) {
          expect(error.reason, contains('are German'));
          outcomes.update('English UI', (n) => n + 1, ifAbsent: () => 1);
        }
        outcomes.update('declined', (n) => n + 1, ifAbsent: () => 1);
        continue;
      }
      expect(builds, isTrue, reason: '${word.id} $bundle');
      outcomes.update('built', (n) => n + 1, ifAbsent: () => 1);
      final answer = e.answer as TickAnswer;
      expect(e.questionKey, 'exercise.ticks.question');
      expect(violations(e, generator.spec, word, bundle, l.ctx), isEmpty);
      expect(candidates, contains(answer.sentence.id));
      final k = answer.right.length;
      ks.add(k);
      expect(generator.objections(e, word, bundle, l.ctx), isEmpty);
      for (final ticked in _tickSets(4)) {
        final rating = _expectedRating(
          4,
          k,
          ticked.intersection(answer.right).length,
          ticked.difference(answer.right).length,
        );
        expect(attribute(word, e, TickedOptions(ticked)), (
          word: rating,
          grammar: rating,
        ));
        final lines = feedbackLines(word, e, TickedOptions(ticked));
        expect(
          [for (final line in lines) '${line.key} ${line.params}'],
          [
            for (final (i, o) in answer.options.indexed)
              '${_feedbackKey(o, ticked.contains(i))} ${{'text': o.text}}',
          ],
        );
        for (final line in lines) {
          expect(de, contains(line.key));
          expect(en, contains(line.key));
        }
      }
    }
    expect(ks, {1, 2});
    expect(
      outcomes.keys,
      containsAll(['built', 'declined', 'no sentence reached', 'English UI']),
      reason: '$outcomes',
    );
  });

  test('in the English UI the kind declines and none of its texts is the '
      'German one', () async {
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'en')],
    );
    addTearDown(container.dispose);
    final german = await container.read(germanFormsProvider.future);
    final l = settingsLearnerOf(world, Settings(), german: german);
    final rng = Random(1);
    for (var i = 0; i < 20; i++) {
      final (word, bundle) = drawPair(rng, l)!;
      expect(
        () => generator.build(word, bundle, l.ctx, rng),
        throwsA(isA<CannotBuild>()),
      );
    }
    final de = _translations('de');
    final en = _translations('en');
    final keys = [
      for (final k in translationKeys('en'))
        if (k.startsWith('exercise.ticks.')) k,
    ];
    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(
        _translate(en, key, 'x'),
        isNot(_translate(de, key, 'x')),
        reason: key,
      );
    }
  });

  group('widget', () {
    /// Scrolls to the top, then down until [target] is on screen.
    Future<void> reveal(WidgetTester tester, Finder target) async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        target,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String key) async {
      final target = find.byKey(Key(key));
      await reveal(tester, target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<bool> checkEnabled(WidgetTester tester) async {
      final button = find.byKey(const Key('exercise.check.button'));
      await reveal(tester, button);
      return tester.widget<ElevatedButton>(button).enabled;
    }

    Future<List<bool>> ticks(WidgetTester tester) async => [
      for (var i = 0; i < 4; i++)
        await () async {
          final box = find.byKey(Key('exercise.ticks.option.$i'));
          await reveal(tester, box);
          return tester.widget<CheckboxListTile>(box).value!;
        }(),
    ];

    testWidgets('ticks follow the taps, check needs a tick, the feedback '
        'names each wrong tick by its mistake, and the next exercise starts '
        'empty, at 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final rng = Random(32);
      final l = settingsLearnerOf(world, Settings());
      final (homo, akkSg) = homoAkkSg(l);
      final built = generator.build(homo, akkSg, l.ctx, rng);
      final sentence = world.corpus.sentences.singleWhere(
        (s) => s.id == 'l24-ne-1',
      );
      final exercises = <(PracticeItem, Exercise)>[
        (
          homo,
          Exercise(
            wordCardId: built.wordCardId,
            grammarCardId: built.grammarCardId,
            kind: built.kind,
            questionKey: built.questionKey,
            questionParams: built.questionParams,
            answer: TickAnswer(sentence, [
              (text: sentence.right[0], mistake: null),
              (
                text: sentence.wrong[0].german,
                mistake: sentence.wrong[0].mistake,
              ),
              (text: sentence.right[1], mistake: null),
              (
                text: sentence.wrong[1].german,
                mistake: sentence.wrong[1].mistake,
              ),
            ]),
          ),
        ),
      ];
      while (exercises.length < 6) {
        final (word, bundle) = drawPair(rng, l)!;
        try {
          exercises.add((word, generator.build(word, bundle, l.ctx, rng)));
        } on CannotBuild {
          continue;
        }
      }
      // Each case: the taps, by option index; the fixed case first.
      final cases = [
        [0, 2, 1],
        for (var i = 1; i < exercises.length; i++)
          [for (var t = 0; t < 1 + rng.nextInt(6); t++) rng.nextInt(4)],
      ];
      for (final (i, taps) in cases.indexed) {
        final (word, e) = exercises[i];
        final answer = e.answer as TickAnswer;
        final responses = <TickedOptions>[];
        Widget widgetOf(Exercise e) => wrapInKeyEchoApp(
          ExerciseTicksWidget(
            word: word,
            exercise: e,
            onResponse: responses.add,
          ),
        );
        await tester.pumpWidget(widgetOf(e));
        await tester.pumpAndSettle();
        expect(await ticks(tester), [false, false, false, false]);
        expect(await checkEnabled(tester), isFalse);
        final model = <int>{};
        for (final t in taps) {
          await tap(tester, 'exercise.ticks.option.$t');
          model.contains(t) ? model.remove(t) : model.add(t);
          expect(await ticks(tester), [
            for (var j = 0; j < 4; j++) model.contains(j),
          ]);
          expect(await checkEnabled(tester), model.isNotEmpty);
        }
        if (model.isEmpty) {
          await tap(tester, 'exercise.ticks.option.0');
          model.add(0);
        }
        await tap(tester, 'exercise.check.button');
        await reveal(tester, find.byKey(const Key('exercise.feedback.lines')));
        for (final (j, o) in answer.options.indexed) {
          final line = keyEcho(_feedbackKey(o, model.contains(j)), {
            'text': o.text,
          });
          expect(
            find.text(line, skipOffstage: false),
            findsOneWidget,
            reason: line,
          );
        }
        await tap(tester, 'exercise.next.button');
        expect(responses.single.ticked, model);

        final (_, next) = exercises[(i + 1) % exercises.length];
        await tester.pumpWidget(widgetOf(next));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const Key('exercise.question'))).dy,
          lessThan(kToolbarHeight + 20),
        );
        expect(await ticks(tester), [false, false, false, false]);
        expect(await checkEnabled(tester), isFalse);
        expect(find.byKey(const Key('exercise.feedback')), findsNothing);
      }
    });
  });
}
