import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';
import 'package:latin_practice/screens/exercise_tap_widget.dart';

import 'support/course_providers.dart';
import 'support/exercise_fakes.dart';
import 'support/gen_sentence_learner.dart';
import 'support/word_classification_harness.dart';

// Finger travel is a physical size, so the bound is absolute, not a screen fraction.
const _maxReachDp = 280.0;

/// Every string of the German `exercise.tap` block.
List<String> _germanTapTexts() {
  final de = jsonDecode(File('assets/flutter_i18n/de.json').readAsStringSync());
  final texts = <String>[];
  void walk(dynamic node) => switch (node) {
    final String s => texts.addAll(
      s.split(RegExp(r'\{\w+\}')).map((t) => t.replaceAll('.', '').trim()),
    ),
    final Map<String, dynamic> m => m.values.forEach(walk),
    _ => throw ArgumentError('$node'),
  };
  walk(de['exercise']['tap']);
  return texts.where((t) => t.length > 3).toList();
}

/// A building kind that fits every pair, tried after the marking kind.
class _Fallback implements ExerciseGenerator {
  const _Fallback();

  @override
  ExerciseKind get kind => ExerciseKind.formBilden;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final form = FormOption(
      text: 'x',
      formKey: word.formOrder.first,
      lexemeId: word.id,
    );
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'q',
      answer: TypedAnswer(form, ['x']),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SentenceCorpus corpus;
  late List<PracticeItem> items;
  final generator = generatorFor(ExerciseKind.markieren, exerciseGenerators);

  setUpAll(() async {
    corpus = await loadSentenceCorpus();
    items = await loadAllPracticeItems();
  });

  /// An exercise on [s], asked through the word of its head.
  ({PracticeItem word, Exercise exercise}) on(Sentence s, {int from = 0}) {
    final ctx = ExerciseContext(
      unlocked: {
        for (final w in items)
          for (final k in w.formOrder) bundleOf(w, k),
      },
      pool: items,
      german: fakeExerciseContext().german,
      sentences: corpus,
      reachedLesson: laterLesson,
    );
    final t = s.tokens[s.construction.head] as FormToken;
    final word = itemOfToken(items, t);
    for (var seed = from; seed < from + 200; seed++) {
      final e = generator.build(word, bundleOf(word, t.key), ctx, Random(seed));
      if ((e.answer as MarksAnswer).sentenceId == s.id) {
        return (word: word, exercise: e);
      }
    }
    throw StateError('no exercise on ${s.id}');
  }

  Sentence longest() => corpus.sentences
      .where((s) => s.construction.reference != null)
      .reduce((a, b) => b.latin.length > a.latin.length ? b : a);

  Future<List<MarksResponse>> pump(
    WidgetTester tester,
    ({PracticeItem word, Exercise exercise}) task, {
    String language = 'de',
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final responses = <MarksResponse>[];
    await tester.pumpWidget(
      wrapInApp(
        ExerciseTapWidget(
          word: task.word,
          exercise: task.exercise,
          onResponse: responses.add,
        ),
        forcedLocale: Locale(language),
      ),
    );
    await tester.pumpAndSettle();
    return responses;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Finder placedOn(int pill, int word) => find.descendant(
    of: find.byKey(Key('exercise.tap.word.$word')),
    matching: find.byKey(Key('exercise.tap.placed.$pill')),
  );

  bool checkEnabled(WidgetTester tester) => tester
      .widget<ElevatedButton>(find.byKey(const Key('exercise.check.button')))
      .enabled;

  // Example-based: the observable is a pumped screen driven by a tap
  // sequence; the pill and word logic behind it is covered by the properties
  // in exercise_tap_test.dart.
  testWidgets('360x640, longest sentence: words, tray and check on screen '
      'and close; tap a pill then a word places it, a tap on it returns it; '
      'check only once every pill is placed', (tester) async {
    final task = on(longest());
    final answer = task.exercise.answer as MarksAnswer;
    final responses = await pump(tester, task);
    final screen = Offset.zero & const Size(360, 640);
    bool onScreen(Finder f) {
      final r = tester.getRect(f);
      return screen.contains(r.topLeft) && screen.contains(r.bottomRight);
    }

    final pills = [
      for (var p = 0; p < answer.pills.length; p++)
        find.byKey(Key('exercise.tap.pill.$p')),
    ];
    for (var w = 0; w < answer.words.length; w++) {
      final word = find.byKey(Key('exercise.tap.word.$w'));
      expect(onScreen(word), isTrue, reason: answer.words[w]);
      final nearest = pills
          .map((p) => (tester.getCenter(p) - tester.getCenter(word)).distance)
          .reduce(min);
      expect(nearest, lessThanOrEqualTo(_maxReachDp), reason: '$w');
    }
    for (final p in pills) {
      expect(onScreen(p), isTrue);
    }
    expect(onScreen(find.byKey(const Key('exercise.check.button'))), isTrue);
    expect(checkEnabled(tester), isFalse);

    final first = answer.pills.first;
    await tap(tester, 'exercise.tap.pill.0');
    await tap(tester, 'exercise.tap.word.${first.word}');
    expect(placedOn(0, first.word), findsOneWidget);
    expect(find.byKey(const Key('exercise.tap.pill.0')), findsNothing);
    expect(checkEnabled(tester), isFalse);

    await tap(tester, 'exercise.tap.placed.0');
    expect(placedOn(0, first.word), findsNothing);
    expect(find.byKey(const Key('exercise.tap.pill.0')), findsOneWidget);

    for (final (p, pill) in answer.pills.indexed) {
      expect(checkEnabled(tester), isFalse);
      await tap(tester, 'exercise.tap.pill.$p');
      await tap(tester, 'exercise.tap.word.${pill.word}');
    }
    expect(checkEnabled(tester), isTrue);
    await tap(tester, 'exercise.check.button');
    expect(find.text('Richtig'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('exercise.next.button')));
    await tap(tester, 'exercise.next.button');
    expect(responses.single.wordOf, [for (final p in answer.pills) p.word]);
    expect(attribute(task.word, task.exercise, responses.single), (
      word: Rating.good,
      grammar: Rating.good,
    ));
  });

  testWidgets('one pill on another word: the check names it and rates Hard', (
    tester,
  ) async {
    final task = on(longest());
    final answer = task.exercise.answer as MarksAnswer;
    final responses = await pump(tester, task);
    final other = [
      for (var w = 0; w < answer.words.length; w++)
        if (answer.pills.every((p) => p.word != w)) w,
    ].first;
    await tap(tester, 'exercise.tap.pill.0');
    await tap(tester, 'exercise.tap.word.$other');
    await tap(tester, 'exercise.tap.pill.1');
    await tap(tester, 'exercise.tap.word.${answer.pills[1].word}');
    await tap(tester, 'exercise.check.button');
    expect(
      find.textContaining('So heißt es: ${answer.words[answer.pills[0].word]}'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('exercise.next.button')));
    await tap(tester, 'exercise.next.button');
    expect(
      attribute(task.word, task.exercise, responses.single).grammar,
      Rating.hard,
    );
  });

  testWidgets('a second exercise in the same widget starts with an empty '
      'state', (tester) async {
    final firstTask = on(longest());
    final next = on(longest(), from: 1000);
    expect(next.exercise, isNot(firstTask.exercise));
    final responses = await pump(tester, firstTask);
    final first = (firstTask.exercise.answer as MarksAnswer).pills.first;
    await tap(tester, 'exercise.tap.pill.0');
    await tap(tester, 'exercise.tap.word.${first.word}');
    await tap(tester, 'exercise.tap.pill.1');
    await tester.pumpWidget(
      wrapInApp(
        ExerciseTapWidget(
          word: next.word,
          exercise: next.exercise,
          onResponse: responses.add,
        ),
        forcedLocale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();
    final answer = next.exercise.answer as MarksAnswer;
    for (var p = 0; p < answer.pills.length; p++) {
      expect(find.byKey(Key('exercise.tap.placed.$p')), findsNothing);
      expect(find.byKey(Key('exercise.tap.pill.$p')), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(Key('exercise.tap.pill.$p')))
            .selected,
        isFalse,
      );
    }
    expect(checkEnabled(tester), isFalse);
  });

  test('a round in the English UI asks the marking kind with English pill '
      'names only', () async {
    final english = [
      for (final w in await loadAllPracticeItems(language: 'en')) w,
    ];
    final inSentences = {
      for (final s in corpus.sentences)
        for (final t in s.tokens.whereType<FormToken>()) t.lemma,
    };
    seedSettings(
      Settings(
        courseWords: LessonRange(1, 25),
        deselectedWords: {
          for (final w in english)
            if (!inSentences.contains(w.lemma)) w.lemma,
        },
      ),
    );
    final c = ProviderContainer(
      retry: noRetry,
      overrides: [
        dataLanguageProvider.overrideWith((ref) => 'en'),
        exerciseRandomProvider.overrideWithValue(Random(0)),
        exerciseRegistryProvider.overrideWithValue([
          generator,
          const _Fallback(),
        ]),
      ],
    );
    addTearDown(c.dispose);
    final tasks = (await c.read(
      roundProvider(const MixedRound(FileFocus('nouns'))).future,
    )).queue;
    final marking = [
      for (final t in tasks)
        if (t.exercise.kind == ExerciseKind.markieren) t,
    ];
    expect(marking, isNotEmpty);
    final en = jsonDecode(
      File('assets/flutter_i18n/en.json').readAsStringSync(),
    );
    final german = _germanTapTexts();
    for (final task in marking) {
      final answer = task.exercise.answer as MarksAnswer;
      for (final p in answer.pills) {
        final name = en['exercise']['tap']['pill'][p.role] as String;
        expect(german, isNot(contains(name)), reason: p.role);
      }
    }
  });

  testWidgets('the English page shows no German text of the tap block', (
    tester,
  ) async {
    final task = on(longest());
    await pump(tester, task, language: 'en');
    final answer = task.exercise.answer as MarksAnswer;
    for (final (p, pill) in answer.pills.indexed) {
      await tap(tester, 'exercise.tap.pill.$p');
      await tap(tester, 'exercise.tap.word.${pill.word}');
    }
    await tap(tester, 'exercise.check.button');
    final text = [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? '',
    ].join(' ');
    final en = jsonDecode(
      File('assets/flutter_i18n/en.json').readAsStringSync(),
    );
    for (final p in answer.pills) {
      expect(text, contains(en['exercise']['tap']['pill'][p.role] as String));
    }
    for (final g in _germanTapTexts()) {
      expect(text, isNot(contains(g)), reason: g);
    }
  });
}
