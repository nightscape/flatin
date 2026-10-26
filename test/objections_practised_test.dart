import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('objections reject an option whose form is switched off', () async {
    final mirus = (await loadPracticeItems(
      'lib/data/latin_nouns.yaml',
    )).singleWhere((i) => i.id == 'nouns:mirus');
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    final german = await container.read(germanFormsProvider.future);
    container.dispose();
    final generator = exerciseGenerators.singleWhere(
      (g) => g.kind == ExerciseKind.bestimmen,
    );
    final bundles = {for (final k in mirus.formOrder) bundleOf(mirus, k)};
    ExerciseContext ctx(bool Function(PracticeItem, dynamic) practised) =>
        ExerciseContext(
          unlocked: bundles,
          pool: [mirus],
          german: german,
          formPracticed: practised,
        );
    final all = ctx((_, _) => true);
    final gradOff = ctx((_, l) => l.features['grad'] != 'sup');

    for (final bundle in bundles) {
      for (var seed = 0; seed < 50; seed++) {
        final Exercise e;
        try {
          e = generator.build(mirus, bundle, all, Random(seed));
        } on CannotBuild {
          continue;
        }
        final options = (e.answer as ChoiceAnswer).options;
        final showsSup = options.any(
          (o) =>
              mirus
                  .formLabels[mirus.formOrder.indexOf(o.formKey)]
                  .features['grad'] ==
              'sup',
        );
        if (!showsSup) continue;
        expect(generator.objections(e, mirus, bundle, all), isEmpty);
        expect(generator.objections(e, mirus, bundle, gradOff), isNotEmpty);
        return;
      }
    }
    fail('no exercise offers a superlative');
  });
}
