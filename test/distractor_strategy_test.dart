import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/distractor_strategy.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RandomDistractors', () {
    final strategy = RandomDistractors();

    test('distinct, never the correct one, deterministic per seed', () async {
      final pool = await loadPracticeItems('lib/data/latin_verbs.yaml');
      for (final item in pool.take(40)) {
        final picked = strategy.pick(item, pool, 3, Random(7));
        expect(picked.length, 3);
        expect(picked.toSet().length, 3);
        expect(picked, isNot(contains(item.translation)));
        expect(strategy.pick(item, pool, 3, Random(7)), picked);
      }
    });

    test('throws when the pool has too few distinct translations', () async {
      final pool = (await loadPracticeItems(
        'lib/data/latin_verbs.yaml',
      )).take(3).toList();
      expect(
        () => strategy.pick(pool.first, pool, 3, Random(1)),
        throwsStateError,
      );
    });
  });

  test('the registry throws on an unknown id', () {
    expect(distractorStrategyById('random'), isA<RandomDistractors>());
    expect(() => distractorStrategyById('nope'), throwsStateError);
  });

  group('settings', () {
    test('default random, persists, unknown id on load throws', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        (await container.read(settingsProvider.future)).distractorStrategyId,
        'random',
      );
      await container
          .read(settingsProvider.notifier)
          .setDistractorStrategy('random');
      final prefs = await SharedPreferences.getInstance();
      final json =
          jsonDecode(prefs.getString('practice_settings')!)
              as Map<String, dynamic>;
      expect(Settings.fromJson(json).distractorStrategyId, 'random');
      json['distractorStrategyId'] = 'nope';
      expect(() => Settings.fromJson(json), throwsStateError);
    });

    testWidgets('the settings screen offers the registry entries', (
      tester,
    ) async {
      await openSettingsWith(tester, Settings().toJson(), page: 'input');
      await tester.tap(find.byKey(const Key('input.distractors')));
      await tester.pumpAndSettle();
      expect(find.text('Zufällig'), findsWidgets);
      expect(distractorStrategies.length, 1);
    });
  });

  testWidgets('the dropdown holds the correct translation and 3 others', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final item = (await loadPracticeItems('lib/data/latin_nouns.yaml')).first;
    await tester.pumpWidget(
      wrapInApp(PracticeScreen(item: item), forcedLocale: const Locale('de')),
    );
    await letItLoad(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    final choices = tester
        .widgetList<DropdownMenuItem<String>>(
          find.byType(DropdownMenuItem<String>),
        )
        .map((i) => i.value)
        .toSet();
    expect(choices.length, 4);
    expect(choices, contains(item.translation));
  });

  for (final asset in ['nouns', 'verbs']) {
    testWidgets('$asset: the title is the lemma, no type name is shown', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final items = await loadPracticeItems('lib/data/latin_$asset.yaml');
      final item = items.first;
      await tester.pumpWidget(
        wrapInApp(PracticeScreen(item: item), forcedLocale: const Locale('de')),
      );
      await letItLoad(tester);
      expect(find.text(item.lemma), findsWidgets);
      for (final type in items.map((i) => i.type).toSet()) {
        expect(find.text(type), findsNothing, reason: type);
      }
    });
  }
}
