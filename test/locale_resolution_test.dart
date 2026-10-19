import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/locale_harness.dart';

void main() {
  testWidgets('a German device shows the German home title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAppOnDevice(tester, const Locale('de', 'DE'));

    expect(titleOf(tester), 'Latein Übung');
  });

  testWidgets('an English device shows the English home title',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAppOnDevice(tester, const Locale('en', 'US'));

    expect(titleOf(tester), 'Latin Practice');
  });

  testWidgets('a device whose language the app lacks falls back to German',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAppOnDevice(tester, const Locale('fr', 'FR'));

    expect(titleOf(tester), 'Latein Übung');
  });

  test('resolution takes the first device language the app offers', () {
    expect(resolveLocale([const Locale('fr'), const Locale('en')]),
        const Locale('en'));
    expect(resolveLocale([const Locale('fr')]), courseLocale);
    expect(resolveLocale(null), courseLocale);
  });
}
