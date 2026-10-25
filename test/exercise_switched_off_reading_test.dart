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
  test(
    'a typed answer accepts a reading whose tense is switched off',
    () async {
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
              'tempus': {'perf'},
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
      final typing = exerciseGenerators.singleWhere(
        (g) => g.kind == ExerciseKind.deLatTippen,
      );
      TypedAnswer? asked;
      for (final bundle in ctx.unlocked) {
        for (var seed = 0; seed < 200 && asked == null; seed++) {
          final Exercise e;
          try {
            e = typing.build(amare, bundle, ctx, Random(seed));
          } on CannotBuild {
            break;
          }
          if (e.questionParams['german'] == 'du liebtest') {
            asked = e.answer as TypedAnswer;
          }
        }
      }
      expect(asked, isNotNull);
      expect(asked!.accepted, contains('amāvistī'));
    },
  );
}
