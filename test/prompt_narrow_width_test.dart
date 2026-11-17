import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/widgets/exercise_question.dart';
import 'package:latin_practice/models/settings.dart' show StemMarking;
import 'package:latin_practice/widgets/form_text.dart';

import 'support/gen_form_text.dart';
import 'support/gen_prompt_exercises.dart';
import 'support/word_classification_harness.dart';

/// One drawn exercise per kind and split class whose prompt shows Latin
/// text, on each narrow phone width, at each text scale a learner can set.
Iterable<(Exercise, double, double)> narrowPromptForms(
  List<(PracticeItem, Exercise)> drawn,
) sync* {
  for (final (_, e) in firstPerKindAndClass(
    drawn.where((d) => d.$2.formParams.isNotEmpty),
  )) {
    for (final width in const [320.0, 360.0]) {
      for (final scale in formTextScales) {
        yield (e, width, scale);
      }
    }
  }
}

void main() {
  late List<(PracticeItem, Exercise)> drawn;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final items = await loadAllPracticeItems();
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

  testWidgets('on a narrow screen every letter of a prompt form stays inside '
      'the question, as the plain text does, in every stem marking', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    final wrong = <String>[];
    for (final mode in StemMarking.values) {
      await tester.pumpWidget(const SizedBox());
      for (final (e, width, scale) in narrowPromptForms(drawn)) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          wrapInApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ExerciseQuestion(e),
                  ),
                ),
              ),
            ),
            forcedLocale: const Locale('de'),
            overrides: [
              if (mode != StemMarking.zeigen)
                stemMarkingProvider.overrideWithValue(mode),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final question = tester.getRect(
          find.byKey(ExerciseQuestion.questionKey),
        );
        for (final el in find.byType(FormText).evaluate()) {
          final form = el.widget as FormText;
          final letters = tester.getRect(
            find.descendant(
              of: find.byWidget(form),
              matching: find.byKey(FormText.textKey),
            ),
          );
          if (letters.right > question.right + 0.5) {
            wrong.add(
              '$mode ${e.kind.name} ${width}px x$scale "${form.text}": letters end '
              'at ${letters.right}, question at ${question.right}',
            );
          }
        }
      }
    }
    expect(wrong, isEmpty);
  });
}
