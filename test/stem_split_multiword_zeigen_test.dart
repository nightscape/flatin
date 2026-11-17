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
import 'package:latin_practice/widgets/form_text.dart';

import 'support/gen_prompt_exercises.dart';
import 'support/word_classification_harness.dart';

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
    prompts = firstPerKindAndClass(
      drawPromptExercises(
        items,
        german,
        await loadSentenceCorpus(),
        stride: 17,
      ).where((d) => showsMultiWordSplit(d.$2)),
    );
  });

  testWidgets('in zeigen no word of a shown split form takes a tap', (
    tester,
  ) async {
    expect(prompts, isNotEmpty);
    final tappable = <String>[];
    for (final (word, e) in prompts) {
      for (final key in e.stemSplits.keys) {
        for (final w in e.questionParams[key]!.split(' ')) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            wrapInApp(
              Scaffold(body: ExerciseQuestion(e)),
              forcedLocale: const Locale('de'),
              overrides: [
                stemMarkingProvider.overrideWithValue(StemMarking.zeigen),
              ],
            ),
          );
          await tester.pumpAndSettle();
          final text = find.byWidgetPredicate(
            (x) => x is FormText && x.text == w,
          );
          int bars() => find
              .descendant(
                of: text.first,
                matching: find.byKey(FormText.separatorKey),
              )
              .evaluate()
              .length;
          final before = bars();
          await tester.tapAt(tester.getRect(text.first).center);
          await tester.pump();
          if (bars() != before) {
            tappable.add(
              '${e.kind.name} ${word.id} "$w" of "${e.questionParams[key]}"',
            );
          }
        }
      }
    }
    expect(tappable, isEmpty);
  });
}
