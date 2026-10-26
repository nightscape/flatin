import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/town_screen.dart';
import 'package:latin_practice/screens/town_shop_screen.dart';
import 'package:latin_practice/services/reward_storage.dart';

import 'support/word_classification_harness.dart';

Future<void> _openTown(WidgetTester tester) async {
  await seedNothingDue({'nouns': <String>{}, 'verbs': <String>{}});
  await RewardStorage.save(const RewardLedger(earned: {coins: 900}));
  await tester.pumpWidget(
    wrapInApp(const HomeScreen(), forcedLocale: const Locale('de')),
  );
  await letItLoad(tester);
  await tester.tap(find.byKey(const Key('home.town')));
  await letItLoad(tester);
}

void main() {
  testWidgets('the town view is immersive, restores the system UI and zooms '
      'to 3x at most', (tester) async {
    final modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _openTown(tester);

    expect(find.byType(TownScreen), findsOneWidget);
    expect(modes, [SystemUiMode.immersiveSticky.toString()]);

    final center = tester.getCenter(find.byType(InteractiveViewer));
    final a = await tester.startGesture(center - const Offset(20, 0));
    final b = await tester.startGesture(center + const Offset(20, 0));
    await a.moveTo(center - const Offset(380, 0));
    await b.moveTo(center + const Offset(380, 0));
    await a.up();
    await b.up();
    await tester.pump();
    final zoomed = tester.widget<Transform>(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(Transform),
      ),
    );
    expect(zoomed.transform.getMaxScaleOnAxis(), closeTo(townMaxScale, 1e-6));

    await tester.tap(find.byKey(const Key('town.close')));
    await letItLoad(tester);
    expect(modes.last, SystemUiMode.edgeToEdge.toString());
  });

  testWidgets('Bauen opens the shop', (tester) async {
    await _openTown(tester);
    expect(find.byType(TownShopScreen), findsNothing);

    await tester.tap(find.byKey(const Key('town.build')));
    await letItLoad(tester);

    expect(find.byType(TownShopScreen), findsOneWidget);
  });
}
