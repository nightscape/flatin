import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

const _seeds = [1, 2, 3];

/// Builds every word x bundle pair with only that bundle unlocked and returns
/// the number of pairs; a pair no kind fits fails naming word, bundle, locale.
int sweep(
  List<PracticeItem> items,
  GermanForms german,
  String locale, {
  List<ExerciseGenerator> registry = exerciseGenerators,
}) {
  final pools = {
    for (final id in {for (final i in items) i.dataFileId})
      id: items.where((i) => i.dataFileId == id).toList(),
  };
  var pairs = 0;
  for (final word in items) {
    final pool = pools[word.dataFileId]!;
    final bundles = {for (final key in word.formOrder) bundleOf(word, key)};
    for (final bundle in bundles) {
      final ctx = ExerciseContext(
        unlocked: {bundle},
        pool: pool,
        german: german,
      );
      pairs++;
      for (final seed in _seeds) {
        try {
          buildExercise(word, bundle, ctx, 0, Random(seed), registry: registry);
        } on AssertionError catch (e) {
          fail('${word.id} / $bundle / $locale: ${e.message}');
        }
      }
    }
  }
  return pairs;
}

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

  test('every word x bundle pair builds an exercise in the German UI', () {
    expect(sweep(items, german, 'de'), greaterThan(0));
  }, tags: 'sweep');

  test('every word x bundle pair builds an exercise in the English UI', () {
    expect(sweep(items, const NoForms(), 'en'), greaterThan(0));
  }, tags: 'sweep');

  test('a pair no kind fits fails naming word, bundle and locale', () {
    expect(
      () => sweep(items, const NoForms(), 'en', registry: const []),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          allOf(contains(items.first.id), contains('en'), contains('/')),
        ),
      ),
    );
  });
}
