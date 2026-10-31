import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/input_strategy.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/exercise_parts_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/round_driver.dart';
import 'support/word_classification_harness.dart';

const _german = [
  'Infinitiv',
  'Supinum',
  'Perfekt',
  'Präsens',
  'Partizip',
  'Aktiv',
  'Passiv',
  'Indikativ',
];

/// The principal-parts exercise of [word]: with [known] part cards the
/// prompt is a form past the present, else the infinitive.
Exercise _build(
  PracticeItem word,
  List<PracticeItem> pool, {
  required bool known,
  int seed = 0,
  GrammarBundle bundle = 'ind.perf.akt',
}) => generatorFor(ExerciseKind.stammformen, exerciseGenerators).build(
  word,
  bundle,
  ExerciseContext(
    unlocked: {for (final k in word.formOrder) bundleOf(word, k)},
    pool: pool,
    german: const FakeGermanForms(),
    stabilityOf: (_) => known ? 30 : null,
  ),
  Random(seed),
);

void main() {
  late PracticeItem cognoscere;
  late List<PracticeItem> verbs;

  Future<void> load(WidgetTester tester, String language) async {
    SharedPreferences.setMockInitialValues({'app_locale': language});
    final c = ProviderContainer(retry: noRetry);
    addTearDown(c.dispose);
    verbs = (await tester.runAsync(
      () => c.read(practicableItemsByTypeProvider.future),
    ))!['verbs']!;
    cognoscere = verbs.singleWhere((v) => v.id == 'verbs:cognoscere');
  }

  Future<List<TypedTexts>> pump(
    WidgetTester tester,
    Exercise e,
    String language, {
    String strategyId = 'text_field',
    PracticeItem? word,
  }) async {
    final responses = <TypedTexts>[];
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapInApp(
        ExercisePartsWidget(
          word: word ?? cognoscere,
          exercise: e,
          inputStrategy: InputStrategy.byId(strategyId),
          optionForms: const {},
          onResponse: responses.add,
        ),
        forcedLocale: Locale(language),
      ),
    );
    await tester.pumpAndSettle();
    return responses;
  }

  String shownText(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(find.byType(Text)))
      t.data ?? t.textSpan?.toPlainText() ?? '',
  ].join(' | ');

  for (final strategyId in ['text_field', 'dropdown_all_forms']) {
    testWidgets('360x640 with the keyboard: $strategyId in every slot, check, '
        'feedback', (tester) async {
      await load(tester, 'de');
      final e = _build(cognoscere, [cognoscere], known: true);
      final slots = (e.answer as PartsAnswer).slots;
      expect(slots, hasLength(4));
      final responses = await pump(tester, e, 'de', strategyId: strategyId);
      for (var i = 0; i < slots.length; i++) {
        await reveal(tester, find.byKey(Key('exercise.slot.$i')));
        expect(
          find.descendant(
            of: find.byKey(Key('exercise.slot.$i')),
            matching: find.byType(
              strategyId == 'text_field'
                  ? TextField
                  : DropdownButtonFormField<String>,
            ),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Supinum'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await answer(tester, e, right: false);
      expect(tester.takeException(), isNull);
      final texts = responses.single.texts;
      expect(texts, hasLength(4));
      expect(slots.first.answer.accepted, isNot(contains(texts.first)));
      for (var i = 1; i < slots.length; i++) {
        expect(texts[i], slots[i].answer.expected.text);
      }
    });
  }

  testWidgets('a right row says so', (tester) async {
    await load(tester, 'de');
    final e = _build(cognoscere, [cognoscere], known: false);
    final responses = await pump(tester, e, 'de');
    for (final (i, s) in (e.answer as PartsAnswer).slots.indexed) {
      await reveal(tester, find.byKey(Key('exercise.slot.$i')));
      final field = find.descendant(
        of: find.byKey(Key('exercise.slot.$i')),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, s.answer.expected.text);
    }
    final check = find.byKey(const Key('exercise.check.button'));
    await reveal(tester, check);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('exercise.feedback'))).data,
      'Richtig',
    );
    expect(find.byKey(const Key('exercise.feedback.lines')), findsOneWidget);
    expect(responses, isEmpty);
  });

  testWidgets('the next exercise starts with empty slots', (tester) async {
    await load(tester, 'de');
    final first = _build(cognoscere, [cognoscere], known: false);
    final responses = await pump(tester, first, 'de');
    await answer(tester, first, right: false);
    expect(responses, hasLength(1));
    final next = _build(cognoscere, [cognoscere], known: false, seed: 1);
    await pump(tester, next, 'de');
    for (var i = 0; i < (next.answer as PartsAnswer).slots.length; i++) {
      final field = find.descendant(
        of: find.byKey(Key('exercise.slot.$i')),
        matching: find.byType(TextField),
      );
      await reveal(tester, field);
      expect(
        tester.widget<TextField>(field).controller!.text,
        isEmpty,
        reason: 'slot $i',
      );
    }
  });

  testWidgets('the prompt fuī shows the perfect as given text and asks the '
      'other parts', (tester) async {
    await load(tester, 'de');
    final esse = verbs.singleWhere((v) => v.id == 'verbs:esse');
    final e = _build(esse, [esse], known: true, bundle: 'ind.praes.akt');
    final parts = e.answer as PartsAnswer;
    expect(parts.prompt.text, 'fuī');
    expect(
      [for (final s in parts.slots) s.answer.expected.text],
      ['esse', 'sum'],
    );
    final responses = await pump(tester, e, 'de', word: esse);
    await reveal(tester, find.byKey(const Key('exercise.given.2')));
    expect(
      tester.widget<Text>(find.byKey(const Key('exercise.given.2'))).data,
      'fuī',
    );
    expect(find.byKey(const Key('exercise.slot.2')), findsNothing);
    await answer(tester, e, right: true);
    expect(responses.single.texts, ['esse', 'sum']);
    expect(
      tester.widget<Text>(find.byKey(const Key('exercise.feedback'))).data,
      'Richtig',
    );
  });

  for (final language in ['en', 'de']) {
    testWidgets('app locale $language: part names and feedback labels', (
      tester,
    ) async {
      await load(tester, language);
      final e = _build(cognoscere, verbs, known: true);
      await pump(tester, e, language);
      tester.view.physicalSize = const Size(360, 4000);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise.check.button')));
      await tester.pumpAndSettle();
      final text = shownText(tester);
      expect(
        _german.where((w) => RegExp('\\b$w\\b').hasMatch(text)),
        language == 'en' ? isEmpty : isNotEmpty,
        reason: '$language: $text',
      );
    });
  }
}
