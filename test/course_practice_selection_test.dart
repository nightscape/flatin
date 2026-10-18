import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/practice_screen.dart';

import 'support/course_providers.dart';
import 'support/word_classification_harness.dart';

/// The course position of a learner in the middle of the first volume.
final _upToFive = Settings(courseWords: LessonRange(1, 5));

Future<ProviderContainer> _containerWithLateGenitive() async {
  final curriculum = await lateGenitiveCurriculum();
  return ProviderContainer(
    overrides: [curriculumProvider.overrideWith((ref) async => curriculum)],
  );
}

Set<String> _idsOf(Map<String, List<PracticeItem>> byType) =>
    {for (final items in byType.values) ...items.map((item) => item.id)};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a narrowed course hides the later lessons and the later forms',
      () async {
    seedSettings(_upToFive);
    final lessons = await loadLessonData(lessonDataAssets);
    final container = await _containerWithLateGenitive();
    addTearDown(container.dispose);

    final practicable =
        await container.read(practicableItemsByTypeProvider.future);
    final shown = [...practicable['nouns']!, ...practicable['verbs']!];
    expect(shown, isNotEmpty);
    expect(
      shown.where((item) => lessons.lessonNumberOf(item) > 5),
      isEmpty,
    );

    final later = (await loadAllPracticeItems())
        .where((item) => lessons.lessonNumberOf(item) > 5);
    expect(later, isNotEmpty);
    expect(_idsOf(practicable).intersection(later.map((i) => i.id).toSet()),
        isEmpty);

    final filter = await container.read(courseFilterProvider.future);
    final forms = {
      for (final item in practicable['nouns']!)
        ...filter.practicedForms('nouns', item.formLabels),
    };
    expect(forms, contains('nom.sg'));
    expect(forms.where((key) => key.startsWith('gen.')), isEmpty);
  });

  testWidgets('the practice screen drops a form the course has not taught',
      (tester) async {
    seedSettings(_upToFive);
    final curriculum = await lateGenitiveCurriculum();
    final rosa = (await loadPracticeItems('lib/data/latin_nouns.yaml'))
        .firstWhere((item) => item.lemma == 'rosa');
    tester.view.physicalSize = const Size(1200, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(
      PracticeScreen(item: rosa),
      forcedLocale: const Locale('de'),
      overrides: [curriculumProvider.overrideWith((ref) async => curriculum)],
    ));
    await letItLoad(tester);

    expect(find.text('Nominativ Singular'), findsOneWidget);
    expect(find.text('Genitiv Singular'), findsNothing);
  });

  test('an item whose forms are all switched off is not practised', () async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    seedSettings(Settings(disabledForms: {'nouns': nouns.formOrder.toSet()}));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final practicable =
        await container.read(practicableItemsByTypeProvider.future);
    expect(practicable['nouns'], isEmpty);
    expect(practicable['verbs'], isNotEmpty);
  });

  test('a word forced on outside the range is practised', () async {
    final lessons = await loadLessonData(lessonDataAssets);
    seedSettings(_upToFive.copyWith(forcedOnWords: {'animus'}));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final practicable =
        await container.read(practicableItemsByTypeProvider.future);
    final shown = [...practicable['nouns']!, ...practicable['verbs']!];
    final ahead = shown.where((item) => lessons.lessonNumberOf(item) > 5);
    expect(ahead.map((item) => item.lemma), ['animus']);
  });

  test('a word forced off inside the range is not practised', () async {
    final lessons = await loadLessonData(lessonDataAssets);
    seedSettings(_upToFive.copyWith(deselectedWords: {'rosa'}));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final practicable =
        await container.read(practicableItemsByTypeProvider.future);
    final shown = [...practicable['nouns']!, ...practicable['verbs']!];
    expect(shown.where((item) => lessons.lessonNumberOf(item) > 5), isEmpty);
    expect(shown.where((item) => item.lemma == 'rosa'), isEmpty);
    expect(shown, isNotEmpty);
  });

  test('narrowing the course deletes no card', () async {
    seedSettings(Settings());
    final wide = ProviderContainer();
    final before = (await wide.read(fsrsCardsProvider.future)).keys.toSet();
    wide.dispose();
    expect(before, isNotEmpty);

    await storeSettings(_upToFive);
    final narrow = ProviderContainer();
    addTearDown(narrow.dispose);
    final practicable =
        await narrow.read(practicableItemsByTypeProvider.future);
    expect(_idsOf(practicable).length, lessThan(before.length));
    expect((await narrow.read(fsrsCardsProvider.future)).keys.toSet(), before);
  });
}
