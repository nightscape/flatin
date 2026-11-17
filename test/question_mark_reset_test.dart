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
import 'package:latin_practice/widgets/form_text.dart';

import 'support/gen_prompt_exercises.dart';
import 'support/word_classification_harness.dart';

/// Pairs of exercises whose single shown form has the same text.
List<((PracticeItem, Exercise), (PracticeItem, Exercise))> markCarryPairs(
  List<(PracticeItem, Exercise)> single,
) {
  final pairs = <((PracticeItem, Exercise), (PracticeItem, Exercise))>[];
  for (var i = 0; i < single.length && pairs.length < 6; i++) {
    for (var j = i + 1; j < single.length; j++) {
      final a = single[i].$2, b = single[j].$2;
      if (!identical(a, b) &&
          a.questionParams[a.formParams.single] ==
              b.questionParams[b.formParams.single]) {
        pairs.add((single[i], single[j]));
        break;
      }
    }
  }
  return pairs;
}

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

  testWidgets('in each marking that takes taps, a mark does not carry over: '
      'the next exercise looks as when shown fresh', (tester) async {
    final single = [
      for (final d in drawn)
        if (d.$2.formParams.length == 1 &&
            (d.$2.answer is TypedAnswer || d.$2.answer is ChoiceAnswer) &&
            d.$2.questionParams[d.$2.formParams.single]!.characters.length >= 2)
          d,
    ];
    final pairs = markCarryPairs(single);
    expect(pairs, isNotEmpty);
    final carried = <String>[];
    for (final mode in [StemMarking.zeigen, StemMarking.selbstMarkieren]) {
      for (final ((w1, e1), (w2, e2)) in pairs) {
        Widget screen(PracticeItem w, Exercise e) => wrapInApp(
          ExerciseScreen(
            word: w,
            exercise: e,
            inputStrategy: InputStrategy.byId('text_field'),
            optionForms: w.formOrder.toSet(),
            onResponse: (_) {},
          ),
          forcedLocale: const Locale('de'),
          overrides: [
            if (mode != StemMarking.zeigen)
              stemMarkingProvider.overrideWithValue(mode),
          ],
        );
        List<Rect> bars() => [
          for (final b in find.byKey(FormText.separatorKey).evaluate())
            tester.getRect(find.byWidget(b.widget)),
        ];
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen(w1, e1));
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(find.byType(FormText)));
        await tester.pump();
        expect(find.byKey(FormText.separatorKey), findsOneWidget);
        await tester.pumpWidget(screen(w2, e2));
        await tester.pumpAndSettle();
        final after = bars();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen(w2, e2));
        await tester.pumpAndSettle();
        if ('$after' != '${bars()}') {
          carried.add(
            '$mode ${e1.kind.name} -> ${e2.kind.name}: '
            '${e2.questionParams[e2.formParams.single]}',
          );
        }
      }
    }
    expect(carried, isEmpty);
  });
}
