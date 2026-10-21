import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _germanTextKinds = {
  ExerciseKind.latDeWahl,
  ExerciseKind.deLatWahl,
  ExerciseKind.deLatTippen,
  ExerciseKind.zuordnen,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container(String language, int seed) => ProviderContainer(
    retry: noRetry,
    overrides: [
      dataLanguageProvider.overrideWith((ref) => language),
      exerciseRandomProvider.overrideWithValue(Random(seed)),
    ],
  );

  test('the English UI has no German form texts', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container('en', 0);
    addTearDown(c.dispose);
    expect(await c.read(germanFormsProvider.future), isA<NoForms>());
  });

  test('the German UI has the German form texts', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container('de', 0);
    addTearDown(c.dispose);
    expect(await c.read(germanFormsProvider.future), isA<GrammarGermanForms>());
  });

  test('every kind that shows German text builds for a verb in the German UI '
      'and throws CannotBuild in the English UI', () async {
    SharedPreferences.setMockInitialValues({});
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final de = container('de', 0);
    final en = container('en', 0);
    addTearDown(de.dispose);
    addTearDown(en.dispose);
    final german = await de.read(germanFormsProvider.future);
    final noForms = await en.read(germanFormsProvider.future);
    final word = verbs.singleWhere((i) => i.id == 'verbs:vocare');
    final bundle = bundleOf(
      word,
      word.formOrder.firstWhere((k) => german.covers(word, k)),
    );
    ExerciseContext ctx(GermanForms forms) =>
        ExerciseContext(unlocked: {bundle}, pool: verbs, german: forms);
    for (final kind in _germanTextKinds) {
      final generator = generatorFor(kind, exerciseGenerators);
      expect(generator.build(word, bundle, ctx(german), Random(0)).kind, kind);
      expect(
        () => generator.build(word, bundle, ctx(noForms), Random(0)),
        throwsA(isA<CannotBuild>()),
        reason: kind.name,
      );
    }
  });
}
