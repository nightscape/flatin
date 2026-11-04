// Example tests over the one real course: each pins a place that reads a data
// file id, and the course is a fixed input, so a generator has nothing to draw.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/course_providers.dart';
import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('vocab has no grammar gap and its dropdowns offer exactly its '
      'practised forms', () async {
    seedSettings(Settings());
    final c = ProviderContainer(retry: noRetry);
    addTearDown(c.dispose);
    final filter = await c.read(courseFilterProvider.future);
    final vocab = (await c.read(
      practicableItemsByTypeProvider.future,
    ))['vocab']!;
    expect(vocab, isNotEmpty);

    for (final item in vocab) {
      expect(filter.typeGap('vocab', item.type), isNull, reason: item.lemma);
      for (final label in item.formLabels) {
        expect(filter.formGap('vocab', label), isNull, reason: item.lemma);
      }
      expect(
        filter.optionForms('vocab', item.formLabels),
        filter.practicedForms('vocab', item.formLabels),
        reason: item.lemma,
      );
    }
  });

  test('the translation choices of a verb are translations of verbs', () async {
    seedSettings(Settings());
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final verbTranslations = {for (final v in verbs) v.translation};
    final c = ProviderContainer(retry: noRetry);
    addTearDown(c.dispose);

    for (final item in verbs) {
      final choices = await c.read(translationChoicesProvider(item).future);
      expect(verbTranslations, containsAll(choices), reason: item.lemma);
    }
  });

  for (final (file, titleKey) in [
    ('nouns', 'wordClassification.declension'),
    ('verbs', 'wordClassification.conjugation'),
  ]) {
    testWidgets('word classification asks the one due $file item with its '
        'title', (tester) async {
      seedSettings(Settings());
      final due = (await loadPracticeItems('lib/data/latin_$file.yaml')).first;
      tester.view.physicalSize = const Size(1200, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapInApp(
          const WordClassificationScreen(),
          forcedLocale: const Locale('de'),
          overrides: [
            dueItemsByTypeProvider.overrideWith(
              (ref) async => {
                'nouns': [if (file == 'nouns') due],
                'verbs': [if (file == 'verbs') due],
                'vocab': [],
              },
            ),
          ],
        ),
      );
      await letItLoad(tester);

      final word = tester
          .widget<Text>(find.byKey(const Key('wordClassification.word')))
          .data!;
      expect(due.forms, contains(word));
      expect(find.byKey(Key(titleKey)), findsOneWidget);
    });
  }

  testWidgets('the input page has one dropdown per grammar file', (
    tester,
  ) async {
    await openSettingsWith(tester, Settings().toJson(), page: 'input');

    expect(find.byKey(const Key('input.nouns')), findsOneWidget);
    expect(find.byKey(const Key('input.verbs')), findsOneWidget);
  });

  testWidgets('a topic chip shows the icon of the file of its topic', (
    tester,
  ) async {
    await openSettingsWith(tester, Settings().toJson());

    final chips = tester.widgetList<FilterChip>(
      find.byWidgetPredicate(
        (w) =>
            w is FilterChip &&
            (w.key as ValueKey<String>?)?.value.startsWith(
                  'kursstand.topic.',
                ) ==
                true,
      ),
    );
    final iconsByFile = <String, Set<IconData?>>{};
    for (final chip in chips) {
      final file = (chip.key! as ValueKey<String>).value.split('/')[1];
      iconsByFile.putIfAbsent(file, () => {}).add((chip.avatar! as Icon).icon);
    }
    expect(iconsByFile, {
      'nouns': {Icons.account_balance},
      'verbs': {Icons.directions_run},
    });
  });
}
