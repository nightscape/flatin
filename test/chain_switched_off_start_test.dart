import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/course_fixture.dart';

void main() {
  test('a chain never starts from a switched-off number', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final items = await loadAllPracticeItems();
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    final german = await container.read(germanFormsProvider.future);
    container.dispose();
    final amare = items.singleWhere((i) => i.id == 'verbs:amare');
    final filter = filterTeachingAll(
      Settings(
        disabledFeatures: {
          amare.dataFileId: {
            'numerus': {'pl'},
          },
        },
      ),
      amare,
    );
    final ctx = ExerciseContext(
      unlocked: unlockedBundles(filter, [amare]),
      pool: [amare],
      german: german,
      formPracticed: (w, l) => filter.formPracticed(w.dataFileId, l),
    );
    bool practised(int i) =>
        filter.formPracticed(amare.dataFileId, amare.formLabels[i]);
    final off =
        {
          for (var i = 0; i < amare.formOrder.length; i++)
            if (!practised(i)) ...amare.acceptedForms[i],
        }..removeAll([
          for (var i = 0; i < amare.formOrder.length; i++)
            if (practised(i)) ...amare.acceptedForms[i],
        ]);
    var built = 0;
    for (final kind in [ExerciseKind.umformen, ExerciseKind.formenKette]) {
      final generator = exerciseGenerators.singleWhere((g) => g.kind == kind);
      for (final bundle in ctx.unlocked) {
        for (var seed = 0; seed < 20; seed++) {
          final Exercise e;
          try {
            e = generator.build(amare, bundle, ctx, Random(seed));
          } on CannotBuild {
            break;
          }
          built++;
          expect(
            off,
            isNot(contains(e.questionParams['start'])),
            reason: '${kind.name} in $bundle',
          );
        }
      }
    }
    expect(built, greaterThan(0));
  });
}
