import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'exercise_pair_sweep_test.dart' show expectedPairs, sweep;

/// The shipped registry with the spec kinds in place of their generators.
final _registry = [
  for (final g in exerciseGenerators)
    specGenerators.where((s) => s.kind == g.kind).firstOrNull ?? g,
];

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

  test('the registry swaps in every spec kind', () {
    expect(
      [for (final g in _registry) g.kind],
      [for (final g in exerciseGenerators) g.kind],
    );
    expect(specGenerators.every(_registry.contains), isTrue);
  });

  test(
    'with the spec kinds every pair builds an exercise in the German UI',
    () => expect(
      sweep(items, german, 'de', registry: _registry),
      expectedPairs(items),
    ),
    tags: 'sweep',
  );

  test(
    'with the spec kinds every pair builds an exercise in the English UI',
    () => expect(
      sweep(items, const NoForms(), 'en', registry: _registry),
      expectedPairs(items),
    ),
    tags: 'sweep',
  );
}
