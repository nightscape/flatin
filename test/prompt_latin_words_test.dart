import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/data/exercise_cube.dart' as cube;
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/exercise_spec.dart';
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

/// The question params whose value is Latin text, read from the kind's spec.
Set<String> latinParams(Exercise e) {
  final spec = exerciseGenerators.firstWhere((g) => g.spec.kind == e.kind).spec;
  return {
    for (final MapEntry(:key, :value) in spec.params.entries)
      if (value is SentenceText ||
          (value is Show && value.view == cube.View.form))
        key,
  };
}

/// Every Latin word a drawn prompt shows.
List<String> promptLatinWords(Exercise e) => [
  for (final p in latinParams(e))
    for (final w in e.questionParams[p]!.split(RegExp(r'[\s,.;:!?„“"()]+')))
      if (w.characters.length >= 2) w,
];

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
    drawn = drawExercises(
      items,
      german,
      await loadSentenceCorpus(),
      stride: 17,
    );
  });

  testWidgets('every Latin word of a prompt is a free-marking form text', (
    tester,
  ) async {
    final byKind = <ExerciseKind, (PracticeItem, Exercise)>{};
    for (final d in drawn) {
      if (exerciseGenerators.any((g) => g.spec.kind == d.$2.kind)) {
        byKind.putIfAbsent(d.$2.kind, () => d);
      }
    }
    expect(byKind.keys, contains(ExerciseKind.satzAnkreuzen));
    final missing = <String>[];
    for (final (word, e) in byKind.values) {
      await tester.pumpWidget(
        wrapInApp(
          Scaffold(body: ExerciseQuestion(e)),
          forcedLocale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      final marked = [
        for (final f in tester.widgetList<FormText>(find.byType(FormText)))
          if (f.mode == StemMarking.frei) f.text,
      ];
      for (final w in promptLatinWords(e)) {
        if (!marked.any((t) => t.split(' ').contains(w))) {
          missing.add('${e.kind.name} ${word.id}: "$w"');
        }
      }
    }
    expect(missing, isEmpty);
  });
}
