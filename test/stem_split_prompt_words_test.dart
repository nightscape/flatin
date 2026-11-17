import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart' show StemMarking;
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/widgets/exercise_question.dart';

import 'support/gen_prompt_exercises.dart';
import 'support/word_classification_harness.dart';

/// Drawn prompts that show a split form whose text holds more than one word.
List<(PracticeItem, Exercise)> multiWordSplitPrompts(
  List<(PracticeItem, Exercise)> drawn,
) => [
  for (final d in drawn)
    if (d.$2.stemSplits.keys.any((k) => d.$2.questionParams[k]!.contains(' ')))
      d,
];

void main() {
  late List<(PracticeItem, Exercise)> prompts;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final items = await loadAllPracticeItems();
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    final german = await container.read(germanFormsProvider.future);
    container.dispose();
    prompts = multiWordSplitPrompts(
      drawExercises(
        [
          for (final w in items)
            if (w.formOrder.contains('inf.fut.pass')) w,
        ].take(5).toList(),
        german,
        await loadSentenceCorpus(),
        stride: 1,
      ),
    );
  });

  testWidgets('a prompt whose split form is more than one word renders in '
      'every stem marking', (tester) async {
    expect(prompts, isNotEmpty);
    final (word, e) = prompts.first;
    for (final mode in StemMarking.values) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        wrapInApp(
          Scaffold(body: ExerciseQuestion(e)),
          forcedLocale: const Locale('de'),
          overrides: [stemMarkingProvider.overrideWithValue(mode)],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$mode ${e.kind.name} ${word.id} ${e.questionParams}',
      );
    }
  });
}
