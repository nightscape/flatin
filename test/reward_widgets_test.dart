import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/rewards.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/settings_screen.dart';
import 'package:latin_practice/widgets/reward_burst.dart';
import 'package:latin_practice/widgets/town_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/word_classification_harness.dart';

const _storeKey = 'practice_settings';

void _store(Settings settings) => SharedPreferences.setMockInitialValues({
  _storeKey: jsonEncode(settings.toJson()),
});

void main() {
  group('reward settings', () {
    test('the switches survive a JSON round trip', () {
      final settings = Settings(
        disabledRewards: {'town'},
        rewardAnimation: false,
      );

      final back = Settings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );

      expect(back.disabledRewards, {'town'});
      expect(back.rewardAnimation, isFalse);
    });

    test('stored settings without reward fields load with everything on', () {
      final json = Settings().toJson()
        ..remove('disabledRewards')
        ..remove('rewardAnimation');

      final loaded = Settings.fromJson(json);

      expect(loaded.disabledRewards, isEmpty);
      expect(loaded.rewardAnimation, isTrue);
    });

    test('only the strategies that can be switched off are listed', () {
      expect(switchableRewardIds, ['points', 'town']);
    });

    test('toggles through the notifier persist across a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(settingsProvider.future);
      final notifier = first.read(settingsProvider.notifier);
      await notifier.toggleReward('points');
      await notifier.toggleReward('town');
      await notifier.toggleReward('town');
      await notifier.setRewardAnimation(false);
      first.dispose();

      final second = ProviderContainer();
      final loaded = await second.read(settingsProvider.future);
      expect(loaded.disabledRewards, {'points'});
      expect(loaded.rewardAnimation, isFalse);
      second.dispose();
    });

    test('a reward that cannot be switched off is refused', () {
      expect(() => Settings().toggleReward('days'), throwsAssertionError);
    });

    testWidgets('the settings screen offers the three switches and stores a '
        'flip', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapInApp(const SettingsScreen()));
      await letItLoad(tester);

      const labels = {
        'points': 'Points',
        'town': 'Roman town',
        'animation': 'Animation',
      };
      for (final MapEntry(key: id, value: label) in labels.entries) {
        final tile = find.byKey(
          Key('settings.reward.$id'),
          skipOffstage: false,
        );
        final switchTile = tester.widget<SwitchListTile>(tile);
        expect(switchTile.value, isTrue);
        expect((switchTile.title! as Text).data, label);
      }

      final town = find.byKey(const Key('settings.reward.town'));
      await tester.tap(town);
      await letItLoad(tester);

      expect(tester.widget<SwitchListTile>(town).value, isFalse);
      final stored = Settings.fromJson(
        jsonDecode(
              (await SharedPreferences.getInstance()).getString(_storeKey)!,
            )
            as Map<String, dynamic>,
      );
      expect(stored.disabledRewards, {'town'});
    });
  });

  group('TownView', () {
    Future<void> pumpTown(WidgetTester tester, List<String> ids) async {
      await tester.pumpWidget(
        wrapInApp(
          TownView(RewardLedger(buildings: ids)),
          forcedLocale: const Locale('de'),
        ),
      );
      await letItLoad(tester);
    }

    testWidgets('shows the built buildings back to front, named in German, '
        'and one construction site for the next', (tester) async {
      await pumpTown(tester, ['fons', 'domus']);

      expect(
        tester.widgetList<Tooltip>(find.byType(Tooltip)).map((t) => t.message),
        ['Haus', 'Brunnen'],
      );
      expect(find.byKey(const Key('town.building.domus')), findsOneWidget);
      expect(find.byKey(const Key('town.building.fons')), findsOneWidget);
      expect(find.byKey(const Key('town.next.hortus')), findsOneWidget);
      expect(find.byKey(const Key('town.next.taberna')), findsNothing);
    });

    testWidgets('shows no construction site when all are built', (
      tester,
    ) async {
      await pumpTown(tester, [for (final b in romanTown) b.id]);

      expect(find.byType(Tooltip), findsNWidgets(romanTown.length));
      expect(
        find.byWidgetPredicate((w) => w.key.toString().contains('town.next')),
        findsNothing,
      );
    });

    testWidgets('renders repeated ids from old ledgers once', (tester) async {
      await pumpTown(tester, ['domus', 'hortus', 'domus']);

      expect(find.byType(Tooltip), findsNWidgets(2));
      expect(find.byKey(const Key('town.next.fons')), findsOneWidget);
    });
  });

  group('RewardBurst', () {
    Future<void> pumpBurst(
      WidgetTester tester,
      Settings settings, {
      bool disableAnimations = false,
      VoidCallback? onTapBelow,
      int bonus = 0,
    }) async {
      _store(settings);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: disableAnimations);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.runAsync(() => container.read(settingsProvider.future));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapBelow,
                    ),
                  ),
                  RewardBurst(10, bonus: bonus),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the bonus next to the points only when above 0', (
      tester,
    ) async {
      await pumpBurst(tester, Settings(), bonus: 10);
      expect(find.text('🪙 +10'), findsOneWidget);
      expect(find.text('⭐ +10'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows no bonus text without a bonus', (tester) async {
      await pumpBurst(tester, Settings());
      expect(find.text('🪙 +10'), findsOneWidget);
      expect(find.textContaining('⭐'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('is absent when the animation is switched off', (tester) async {
      await pumpBurst(tester, Settings(rewardAnimation: false));
      expect(find.text('🪙 +10'), findsNothing);
    });

    testWidgets('is absent when the device disables animations', (
      tester,
    ) async {
      await pumpBurst(tester, Settings(), disableAnimations: true);
      expect(find.text('🪙 +10'), findsNothing);
    });

    testWidgets('shows, moves up and is gone after 700 ms', (tester) async {
      var taps = 0;
      await pumpBurst(tester, Settings(), onTapBelow: () => taps++);
      final start = tester.getTopLeft(find.text('🪙 +10')).dy;

      await tester.tap(find.text('🪙 +10'), warnIfMissed: false);
      expect(taps, 1, reason: 'the burst must pass taps to the widget below');

      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getTopLeft(find.text('🪙 +10')).dy, closeTo(start - 16, 1));

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('🪙 +10'), findsNothing);
    });
  });
}
