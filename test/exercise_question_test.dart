import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/input_strategy.dart';
import 'package:latin_practice/models/settings.dart' show StemMarking;
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/screens/exercise_screen.dart';
import 'package:latin_practice/widgets/exercise_question.dart';
import 'package:latin_practice/widgets/form_text.dart';

import 'support/gen_prompt_exercises.dart';
import 'support/round_driver.dart';
import 'support/word_classification_harness.dart';

// Generators: drawExercises (new, test/support/gen_prompt_exercises.dart):
// every 17th real word x all its bundles x every shipped generator, built
// with the fake German texts. The tap sequences reuse drawGapTaps.

void main() {
  late List<PracticeItem> items;
  late List<(PracticeItem, Exercise)> drawn;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    items = await loadAllPracticeItems();
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    final german = await container.read(germanFormsProvider.future);
    container.dispose();
    drawn = drawPromptExercises(
      items,
      german,
      await loadSentenceCorpus(),
      stride: 17,
    );
  });

  test('a form in a question is never a text the learner has to give, and '
      'every kind that asks about a form shows one', () {
    final leaks = [
      for (final (word, e) in drawn)
        for (final p in e.formParams)
          if (expectedLatin(e).contains(e.questionParams[p]))
            '${e.kind.name} ${word.id}: $p = ${e.questionParams[p]}',
    ];
    expect(leaks, isEmpty);
    expect(
      {
        for (final (_, e) in drawn)
          if (e.formParams.isNotEmpty) e.kind,
      },
      {
        ExerciseKind.bedeutungWahl,
        ExerciseKind.umformen,
        ExerciseKind.fehlerFinden,
        ExerciseKind.bestimmen,
        ExerciseKind.formenKette,
        ExerciseKind.satzAnkreuzen,
        ExerciseKind.stammformen,
      },
    );
  });

  test('a stem split marks only a shown form, never a text the learner has '
      'to give, and some kinds show one', () {
    final leaks = [
      for (final (word, e) in drawn)
        for (final p in e.stemSplits.keys)
          if (expectedLatin(e).contains(e.questionParams[p]) ||
              !e.formParams.contains(p))
            '${e.kind.name} ${word.id}: $p = ${e.questionParams[p]}',
    ];
    expect(leaks, isEmpty);
    expect(drawn.where((d) => d.$2.stemSplits.isNotEmpty), isNotEmpty);
  });

  testWidgets('in every stem marking the question shows exactly its form '
      'params as form texts in that marking, and a shown form with a stem '
      'split carries it', (tester) async {
    final picked = firstPerKindAndClass([
      ...drawn.where((d) => d.$2.stemSplits.isNotEmpty),
      ...drawn,
    ]);
    expect(picked.where((d) => d.$2.stemSplits.isNotEmpty), isNotEmpty);
    expect(picked.where((d) => showsMultiWordSplit(d.$2)), isNotEmpty);
    for (final mode in StemMarking.values) {
      await tester.pumpWidget(const SizedBox());
      for (final (word, e) in picked) {
        await tester.pumpWidget(
          wrapInApp(
            Scaffold(body: ExerciseQuestion(e)),
            forcedLocale: const Locale('de'),
            overrides: [
              if (mode != StemMarking.zeigen)
                stemMarkingProvider.overrideWithValue(mode),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final reason = '$mode ${e.kind.name} ${word.id}';
        final forms = tester.widgetList<FormText>(find.byType(FormText));
        expect(forms.map((f) => f.mode), everyElement(mode), reason: reason);
        expect(
          {
            for (final f in forms)
              if (f.split != null) f.text: f.split,
          },
          {
            for (final MapEntry(:key, :value) in e.stemSplits.entries)
              ..._splitWords(e.questionParams[key]!, value.stemLength),
          },
          reason: reason,
        );
        expect(
          [for (final f in forms) f.text]..sort(),
          [
            for (final p in e.formParams)
              ...RegExp(
                r'[\p{L}\p{M}]{2,}',
                unicode: true,
              ).allMatches(e.questionParams[p]!).map((m) => m[0]!),
          ]..sort(),
          reason: reason,
        );
        expect(find.byKey(ExerciseQuestion.questionKey), findsOneWidget);
      }
    }
  });

  testWidgets('marking and confirming gaps in the question changes neither '
      'the response nor its wording, in each marking that takes taps', (
    tester,
  ) async {
    final cases = [
      for (final d in drawn)
        if (d.$2.formParams.isNotEmpty &&
            (d.$2.answer is TypedAnswer || d.$2.answer is ChoiceAnswer))
          d,
    ].take(12);
    expect(cases, isNotEmpty);
    for (final (word, e) in cases) {
      for (final mode in [StemMarking.zeigen, StemMarking.selbstMarkieren]) {
        final responses = <List<ExerciseResponse>>[];
        for (final tapGaps in [false, true]) {
          final got = <ExerciseResponse>[];
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            wrapInApp(
              ExerciseScreen(
                word: word,
                exercise: e,
                inputStrategy: InputStrategy.byId('text_field'),
                optionForms: word.formOrder.toSet(),
                onResponse: got.add,
              ),
              forcedLocale: const Locale('de'),
              overrides: [
                if (mode != StemMarking.zeigen)
                  stemMarkingProvider.overrideWithValue(mode),
              ],
            ),
          );
          await tester.pumpAndSettle();
          if (tapGaps) {
            for (final f in find.byType(FormText).evaluate()) {
              final box = tester.getRect(find.byWidget(f.widget));
              if ((f.widget as FormText).text.length >= 2) {
                await tester.tapAt(box.center);
                await tester.pump();
              }
            }
            expect(find.byKey(FormText.separatorKey), findsWidgets);
            for (final confirm in find.byKey(FormText.confirmKey).evaluate()) {
              await tester.tap(find.byWidget(confirm.widget));
            }
            await tester.pumpAndSettle();
          }
          await answer(tester, e, right: true);
          responses.add(got);
        }
        expect(responses[1].length, responses[0].length, reason: e.kind.name);
        expect(
          [for (final r in responses[1]) r.runtimeType],
          [for (final r in responses[0]) r.runtimeType],
        );
        expect(
          [for (final r in responses[1]) '${_texts(r)}'],
          [for (final r in responses[0]) '${_texts(r)}'],
          reason: '$mode ${e.kind.name}',
        );
      }
    }
  });
}

/// The word of a shown form that holds the end of its stem, with the stem
/// letters in that word.
Map<String, int> _splitWords(String form, int stemLength) {
  var before = 0;
  for (final w in form.split(' ')) {
    final n = w.characters.length;
    if (stemLength < before + n) return {w: stemLength - before};
    before += n + 1;
  }
  throw StateError('the stem of "$form" is longer than the form');
}

Object? _texts(ExerciseResponse r) => switch (r) {
  TypedText(:final text) => text,
  ChosenOption(:final chosen) => chosen.text,
  _ => r,
};
