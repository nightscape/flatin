import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/word_classification_harness.dart';

const _storeKey = 'practice_settings';

void main() {
  test('macron twins are avoided unless stored settings say otherwise', () {
    expect(Settings().avoidMacronTwins, isTrue);
    final json = Settings().toJson()..remove('avoidMacronTwins');
    expect(Settings.fromJson(json).avoidMacronTwins, isTrue);
    final back = Settings.fromJson(
      jsonDecode(jsonEncode(Settings(avoidMacronTwins: false).toJson()))
          as Map<String, dynamic>,
    );
    expect(back.avoidMacronTwins, isFalse);
  });

  test('the notifier persists the macron switch across a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    await first.read(settingsProvider.future);
    await first.read(settingsProvider.notifier).setAvoidMacronTwins(false);
    first.dispose();

    final second = ProviderContainer();
    expect(
      (await second.read(settingsProvider.future)).avoidMacronTwins,
      isFalse,
    );
    second.dispose();
  });

  testWidgets(
    'the settings screen offers the macron switch and stores a flip',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapInApp(const SettingsScreen()));
      await letItLoad(tester);

      final tile = find.byKey(const Key('settings.avoidMacronTwins'));
      final before = tester.widget<SwitchListTile>(tile);
      expect(before.value, isTrue);
      expect(
        (before.title! as Text).data,
        'Avoid forms that differ only in macrons',
      );

      await tester.tap(tile);
      await letItLoad(tester);

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      final stored = Settings.fromJson(
        jsonDecode(
              (await SharedPreferences.getInstance()).getString(_storeKey)!,
            )
            as Map<String, dynamic>,
      );
      expect(stored.avoidMacronTwins, isFalse);
    },
  );
}
