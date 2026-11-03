import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
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
import 'support/key_echo_i18n.dart';
import 'support/word_classification_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SentenceWorld world;
  final generator = generatorFor(
    ExerciseKind.satzAnkreuzen,
    exerciseGenerators,
  );

  setUpAll(() async {
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    world = (
      items: await loadAllPracticeItems(),
      curriculum: await loadCurriculum(bookAssets),
      lessons: await loadLessonData(bookAssets),
      corpus: await loadSentenceCorpus(),
      german: await container.read(germanFormsProvider.future),
    );
    container.dispose();
  });

  /// One tick exercise per mistake, ticked so that every feedback line kind
  /// shows: a right and a wrong tick, a right and a wrong option left.
  List<(PracticeItem, Exercise, Set<int>)> staticExamples() {
    final l = settingsLearnerOf(world, Settings());
    final homo = l.ctx.pool.singleWhere((w) => w.lemma == 'homō');
    final built = generator.build(
      homo,
      bundleOf(homo, 'akk.sg'),
      l.ctx,
      Random(0),
    );
    final s = world.corpus.sentences.singleWhere((s) => s.id == 'l24-ne-1');
    return [
      for (final m in Mistake.values)
        (
          homo,
          Exercise(
            wordCardId: built.wordCardId,
            grammarCardId: built.grammarCardId,
            kind: built.kind,
            questionKey: built.questionKey,
            questionParams: built.questionParams,
            answer: TickAnswer(s, [
              (text: s.right[0], mistake: null),
              (text: s.wrong[0].german, mistake: m),
              (text: s.right[1], mistake: null),
              (text: s.wrong[1].german, mistake: s.wrong[1].mistake),
            ]),
          ),
          {0, 1},
        ),
    ];
  }

  /// A tick exercise for a pair a corpus sentence holds, with a drawn
  /// non-empty tick set; null when the kind declines. Half the learners have
  /// the default settings, as few drawn ones reach a sentence lesson.
  (PracticeItem, Exercise, Set<int>)? draw(Random rng) {
    final l = rng.nextBool()
        ? drawSettingsLearner(rng, world)
        : settingsLearnerOf(world, Settings());
    final held = [
      for (final s in world.corpus.sentences)
        for (final t in s.tokens.whereType<FormToken>())
          for (final w in l.ctx.pool)
            if (w.lemma == t.lemma && w.formOrder.contains(t.key))
              (w, bundleOf(w, t.key)),
    ];
    if (held.isEmpty) return null;
    final (word, bundle) = held[rng.nextInt(held.length)];
    final Exercise e;
    try {
      e = generator.build(word, bundle, l.ctx, rng);
    } on CannotBuild {
      return null;
    }
    final n = (e.answer as TickAnswer).options.length;
    final ticked = {for (var i = 0; i < n; i++) i}
      ..retainWhere((_) => rng.nextBool());
    return (word, e, ticked.isEmpty ? {rng.nextInt(n)} : ticked);
  }

  testWidgets('no feedback text of the tick exercise says an attempt failed, '
      'for every mistake in both languages and for drawn settings, '
      'exercises and ticks', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final rng = Random(378);
    final cases = [
      for (final c in staticExamples()) ...[(c, 'de'), (c, 'en')],
    ];
    var drawn = 0;
    for (var attempt = 0; drawn < 12; attempt++) {
      expect(attempt, lessThan(400), reason: 'the kind builds too rarely');
      if (draw(rng) case final c?) {
        cases.add((c, 'de'));
        drawn++;
      }
    }
    for (final ((word, e, ticked), code) in cases) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        wrapInApp(
          ExerciseTicksWidget(word: word, exercise: e, onResponse: (_) {}),
          forcedLocale: Locale(code),
        ),
      );
      await tester.pumpAndSettle();
      for (final i in ticked) {
        await tester.tap(find.byKey(Key('exercise.ticks.option.$i')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      final options = (e.answer as TickAnswer).options;
      final texts = [
        for (final key in ['exercise.feedback', 'exercise.feedback.lines'])
          for (final t in tester.widgetList<RichText>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(RichText),
            ),
          ))
            t.text.toPlainText(),
      ];
      expect(texts.length, 1 + options.length, reason: '$code $ticked');
      for (final text in texts) {
        final own = options.fold(text, (t, o) => t.replaceAll(o.text, ''));
        expect(
          failureWord.hasMatch(own),
          isFalse,
          reason: '$code ${e.questionParams} $ticked: "$text"',
        );
      }
    }
  });

  // Static example: one fixed exercise and one fixed tick set, so there is no
  // input space to draw from.
  testWidgets('a wrong option rightly left unticked shows the wrongLeft line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (word, e, _) = staticExamples().first;
    await tester.pumpWidget(
      wrapInKeyEchoApp(
        ExerciseTicksWidget(word: word, exercise: e, onResponse: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    for (final i in [0, 2]) {
      await tester.tap(find.byKey(Key('exercise.ticks.option.$i')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('exercise.check.button')));
    await tester.pumpAndSettle();
    final lines = [
      for (final t in tester.widgetList<RichText>(
        find.descendant(
          of: find.byKey(const Key('exercise.feedback.lines')),
          matching: find.byType(RichText),
        ),
      ))
        t.text.toPlainText(),
    ];
    expect(lines, [
      'exercise.ticks.feedback.rightTicked',
      'exercise.ticks.feedback.wrongLeft',
      'exercise.ticks.feedback.rightTicked',
      'exercise.ticks.feedback.wrongLeft',
    ]);
  });

  // Wording rule over the JSON values: no fixed input space beyond the files.
  test('"not quite" never words a line shown for a right action', () {
    for (final code in ['de', 'en']) {
      final tree = jsonDecode(
        File('assets/flutter_i18n/$code.json').readAsStringSync(),
      );
      final feedback = tree['exercise']['ticks']['feedback'] as Map;
      final tap = tree['exercise']['tap']['feedback'] as Map;
      final rightActions = {
        'rightTicked': feedback['rightTicked'],
        'rightLeft': feedback['rightLeft'],
        'wrongLeft': feedback['wrongLeft'],
        for (final MapEntry(:key, :value) in tap.entries)
          'tap.$key.right': value['right'],
      };
      for (final MapEntry(:key, :value) in rightActions.entries) {
        expect(
          value,
          isNot(matches(RegExp('nicht ganz|not quite'))),
          reason: '$code $key',
        );
      }
    }
  });
}
