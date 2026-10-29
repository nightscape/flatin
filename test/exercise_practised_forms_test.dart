import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/course_fixture.dart';

Set<FormKey> _keysOf(Exercise e) => switch (e.answer) {
  ChoiceAnswer(:final options) => {for (final o in options) o.formKey},
  TypedAnswer(:final expected) => {expected.formKey},
  MatchingAnswer(:final pairs) => {
    for (final (a, b) in pairs) ...[a.formKey, b.formKey],
  },
  SortingAnswer(:final forms) => {
    for (final (o, _) in forms)
      if (o.lexemeId == e.wordCardId) o.formKey,
  },
};

void main() {
  late List<PracticeItem> adjectives;
  late GermanForms german;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    adjectives = [
      for (final i in await loadAllPracticeItems())
        if (i.formOrder.any((k) => k.contains('komp'))) i,
    ];
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    german = await container.read(germanFormsProvider.future);
    container.dispose();
  });

  test('no exercise of a round asks a switched-off degree', () {
    expect(adjectives, isNotEmpty);
    final offGrad = {'komp', 'sup'};
    var built = 0;
    for (final word in adjectives) {
      final settings = Settings(
        disabledFeatures: {
          word.dataFileId: {'grad': offGrad},
        },
      );
      final filter = filterTeachingAll(settings, word);
      final ctx = ExerciseContext(
        unlocked: unlockedBundles(filter, [word]),
        pool: adjectives.where((a) => a.dataFileId == word.dataFileId).toList(),
        german: german,
        formPracticed: (w, l) => filter.formPracticed(w.dataFileId, l),
      );
      final off =
          {
            for (var i = 0; i < word.formOrder.length; i++)
              if (!filter.formPracticed(word.dataFileId, word.formLabels[i]))
                ...word.acceptedForms[i],
          }..removeAll([
            for (var i = 0; i < word.formOrder.length; i++)
              if (filter.formPracticed(word.dataFileId, word.formLabels[i]))
                ...word.acceptedForms[i],
          ]);
      for (final bundle in ctx.unlocked) {
        for (var seed = 0; seed < 20; seed++) {
          final exercise = buildExercise(
            word,
            bundle,
            ctx,
            0,
            Random(seed),
            registry: exerciseGenerators,
          );
          built++;
          for (final param in ['start', 'form', 'wrong']) {
            expect(
              off,
              isNot(contains(exercise.questionParams[param])),
              reason: '${word.id} ${exercise.kind.name} shows $param',
            );
          }
          for (final key in _keysOf(exercise)) {
            expect(
              word.formLabels[word.formOrder.indexOf(key)].features['grad'],
              isNot(anyOf('komp', 'sup')),
              reason: '${word.id} ${exercise.kind.name} asks $key',
            );
          }
        }
      }
    }
    expect(built, greaterThan(0));
  });
}
