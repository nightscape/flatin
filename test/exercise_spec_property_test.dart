import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/exercise_invariants.dart';

/// Every [_stride]th word with all its bundles, so the test stays fast.
const _stride = 7;
const _seeds = 3;

void main() {
  late List<PracticeItem> items;
  late GermanForms german;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    items = await loadAllPracticeItems();
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    german = await container.read(germanFormsProvider.future);
    container.dispose();
  });

  test('every spec exercise is valid and carries its rating fields', () {
    final invalid = <String>[];
    var built = 0;
    final builtKinds = <ExerciseKind>{};
    for (final forms in [german, const NoForms()]) {
      for (var i = 0; i < items.length; i += _stride) {
        final word = items[i];
        for (final bundle in {
          for (final k in word.formOrder) bundleOf(word, k),
        }) {
          for (final g in specGenerators) {
            final ctx = ExerciseContext(
              unlocked: unlockedFor(g.spec, word, bundle),
              pool: [word],
              german: forms,
            );
            for (var seed = 0; seed < _seeds; seed++) {
              final Exercise e;
              try {
                e = g.build(word, bundle, ctx, Random(seed));
              } on CannotBuild {
                continue;
              }
              built++;
              builtKinds.add(g.kind);
              final why = violations(e, g.spec, word, bundle, ctx);
              if (why.isNotEmpty) {
                invalid.add('${g.kind.name} ${word.id} $bundle: $why');
              }
            }
          }
        }
      }
    }
    expect(invalid, isEmpty);
    expect(built, greaterThan(1000));
    expect(builtKinds, {for (final g in specGenerators) g.kind});
  });
}
