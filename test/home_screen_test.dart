import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/services/reward_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('with everything due the home entry opens an enabled type', (
    tester,
  ) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    final enabledType = nouns.availableTypes.first;
    await seedEverythingDue({
      'nouns': nouns.availableTypes.skip(1).toSet(),
      'verbs': verbs.availableTypes.toSet(),
    });

    await tester.pumpWidget(wrapInApp(const HomeScreen()));
    await letItLoad(tester);

    await tester.tap(find.byKey(const Key('home.nouns.button')));
    await letItLoad(tester);

    final opened = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(opened.item.type, enabledType);
  });

  testWidgets('with nothing due the home entries honour the type selection', (
    tester,
  ) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    final enabledType = nouns.availableTypes.first;
    await seedNothingDue({
      'nouns': nouns.availableTypes.skip(1).toSet(),
      'verbs': verbs.availableTypes.toSet(),
    });

    await tester.pumpWidget(wrapInApp(const HomeScreen()));
    await letItLoad(tester);

    final verbsButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('home.verbs.button')),
    );
    expect(verbsButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('home.nouns.button')));
    await letItLoad(tester);

    final opened = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(opened.item.type, enabledType);
  });

  testWidgets('the drawer entries honour the type selection', (tester) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    final enabledType = nouns.availableTypes.first;
    await seedNothingDue({
      'nouns': nouns.availableTypes.skip(1).toSet(),
      'verbs': verbs.availableTypes.toSet(),
    });

    await tester.pumpWidget(wrapInApp(const HomeScreen()));
    await letItLoad(tester);

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await letItLoad(tester);

    expect(
      tester.widget<ListTile>(find.byKey(const Key('drawer.verbs'))).enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('drawer.nouns')));
    await letItLoad(tester);

    final opened = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(opened.item.type, enabledType);
  });

  group('town panel', () {
    Future<void> pumpHome(
      WidgetTester tester, {
      RewardLedger ledger = const RewardLedger(),
      Settings? settings,
    }) async {
      await seedNothingDue({'nouns': <String>{}, 'verbs': <String>{}});
      if (settings != null) {
        await (await SharedPreferences.getInstance()).setString(
          'practice_settings',
          jsonEncode(settings.toJson()),
        );
      }
      await RewardStorage.save(ledger);
      await tester.pumpWidget(
        wrapInApp(const HomeScreen(), forcedLocale: const Locale('de')),
      );
      await letItLoad(tester);
    }

    testWidgets('invites the learner to build the first building', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.byKey(const Key('home.town')), findsOneWidget);
      expect(
        find.text('Tippe auf die Stadt, um dein erstes Gebäude zu kaufen.'),
        findsOneWidget,
      );
      expect(find.textContaining('Geübte Tage'), findsNothing);
    });

    testWidgets('shows the earned buildings and the practice days', (
      tester,
    ) async {
      await pumpHome(
        tester,
        ledger: RewardLedger(buildings: ['hortus', 'domus'], practiceDays: 3),
      );

      expect(find.text('Geübte Tage: 3'), findsOneWidget);
      expect(find.byKey(const Key('town.building.domus')), findsOneWidget);
      expect(find.byKey(const Key('town.building.hortus')), findsOneWidget);
    });
  });
}
