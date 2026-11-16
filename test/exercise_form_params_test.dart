import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/gen_prompt_exercises.dart';

/// Every drawn exercise, rebuilt with one form param that names no question
/// param.
Iterable<Exercise Function()> strayFormParams(List<Exercise> drawn) sync* {
  for (final e in drawn) {
    for (final stray in ['form', 'start', 'wrong', 'word', 'x']) {
      if (e.questionParams.containsKey(stray)) continue;
      yield () => Exercise(
        wordCardId: e.wordCardId,
        grammarCardId: e.grammarCardId,
        kind: e.kind,
        questionKey: e.questionKey,
        languageName: e.languageName,
        questionParams: e.questionParams,
        formParams: {...e.formParams, stray},
        answer: e.answer,
      );
    }
  }
}

void main() {
  test('a form param must name a question param', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final items = await loadAllPracticeItems();
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    final german = await container.read(germanFormsProvider.future);
    container.dispose();
    final drawn = drawExercises(
      items,
      german,
      await loadSentenceCorpus(),
      stride: 17,
    );
    final cases = strayFormParams([for (final (_, e) in drawn) e]).toList();
    expect(cases, isNotEmpty);
    for (final build in cases) {
      expect(build, throwsA(isA<AssertionError>()));
    }
  });
}
