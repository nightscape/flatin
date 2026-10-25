import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/services/reward_storage.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('the shop greys out what is too expensive and shows what is '
      'missing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await seedNothingDue({'nouns': <String>{}, 'verbs': <String>{}});
    await RewardStorage.save(
      const RewardLedger(points: 300, buildings: ['domus']),
    );
    await tester.pumpWidget(
      wrapInApp(const HomeScreen(), forcedLocale: const Locale('de')),
    );
    await letItLoad(tester);
    await tester.tap(find.byKey(const Key('home.town')));
    await letItLoad(tester);
    await tester.tap(find.byKey(const Key('town.build')));
    await letItLoad(tester);

    expect(find.byKey(const Key('shop.item.domus')), findsNothing);
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('shop.item.hortus')))
          .enabled,
      isTrue,
    );
    expect(find.text('600 Münzen – dir fehlen 300'), findsWidgets);
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('shop.item.templum')))
          .enabled,
      isFalse,
    );
  });

  testWidgets(
    'buying asks for confirmation, then spends the price and builds',
    (tester) async {
      await seedNothingDue({'nouns': <String>{}, 'verbs': <String>{}});
      await RewardStorage.save(const RewardLedger(points: 900));
      await tester.pumpWidget(
        wrapInApp(const HomeScreen(), forcedLocale: const Locale('de')),
      );
      await letItLoad(tester);
      await tester.tap(find.byKey(const Key('home.town')));
      await letItLoad(tester);
      await tester.tap(find.byKey(const Key('town.build')));
      await letItLoad(tester);
      await tester.tap(find.byKey(const Key('shop.item.taberna')));
      await letItLoad(tester);
      expect(find.text('Laden für 400 Münzen kaufen?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shop.confirm')));
      await letItLoad(tester);

      final ledger = await RewardStorage.load();
      expect(ledger.balance, 500);
      expect(ledger.buildings, ['taberna']);
    },
  );
}
