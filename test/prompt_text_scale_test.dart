import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/widgets/exercise_question.dart';
import 'package:latin_practice/widgets/form_text.dart';

import 'support/gen_prompt_exercises.dart';
import 'support/word_classification_harness.dart';

/// One drawn exercise per kind whose prompt shows Latin text, at each text
/// scale a learner can set.
Iterable<(Exercise, double)> scaledPromptForms(
  List<(PracticeItem, Exercise)> drawn,
) sync* {
  final byKind = <ExerciseKind, Exercise>{};
  for (final (_, e) in drawn) {
    if (e.formParams.isNotEmpty) byKind.putIfAbsent(e.kind, () => e);
  }
  for (final e in byKind.values) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      yield (e, scale);
    }
  }
}

void main() {
  late List<(PracticeItem, Exercise)> drawn;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final items = await loadAllPracticeItems();
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    final german = await container.read(germanFormsProvider.future);
    container.dispose();
    drawn = drawExercises(
      items,
      german,
      await loadSentenceCorpus(),
      stride: 17,
    );
  });

  testWidgets('a form in a prompt has the size of the plain text at every '
      'text scale', (tester) async {
    final wrong = <String>[];
    for (final (e, scale) in scaledPromptForms(drawn)) {
      Widget scaled(Widget child) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: child),
        ),
      );
      await tester.pumpWidget(
        wrapInApp(
          scaled(ExerciseQuestion(e)),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      final shown = [
        for (final el in find.byType(FormText).evaluate())
          (
            (el.widget as FormText).text,
            tester.getRect(find.byWidget(el.widget)).size,
          ),
      ];
      for (final (text, size) in shown) {
        await tester.pumpWidget(
          wrapInApp(
            scaled(
              Builder(
                builder: (context) => Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ),
            forcedLocale: const Locale('de'),
          ),
        );
        await tester.pumpAndSettle();
        final plain = tester.getSize(find.text(text));
        if ((plain.height - size.height).abs() > 0.5 ||
            (plain.width - size.width).abs() > 0.5) {
          wrong.add('${e.kind.name} x$scale "$text": $size vs plain $plain');
        }
      }
    }
    expect(wrong, isEmpty);
  });
}
