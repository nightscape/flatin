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

  testWidgets('an en_US device shows the English home title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAppOnDevice(tester, const Locale('en', 'US'));

    expect(titleOf(tester), 'Latin Practice');
  });

  testWidgets('a fr_FR device shows the German home title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAppOnDevice(tester, const Locale('fr', 'FR'));

    expect(titleOf(tester), 'Latein Übung');
  });

  testWidgets('a stored English choice survives the load', (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await pumpAppOnDevice(tester, const Locale('de', 'DE'));

    expect(titleOf(tester), 'Latin Practice');
    expect(
      (await SharedPreferences.getInstance()).getString('app_locale'),
      'en',
    );
  });

  testWidgets('a stored language the app does not offer is dropped', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'fr'});
    await pumpAppOnDevice(tester, const Locale('fr', 'FR'));

    expect(titleOf(tester), 'Latein Übung');
    expect(
      (await SharedPreferences.getInstance()).containsKey('app_locale'),
      isFalse,
    );
  });

  test('resolution takes the first device language the app offers', () {
    expect(
      resolveLocale([const Locale('fr'), const Locale('de')]),
      const Locale('de'),
    );
    expect(
      resolveLocale([const Locale('fr'), const Locale('en', 'GB')]),
      const Locale('en'),
    );
    expect(resolveLocale([const Locale('fr')]), courseLocale);
    expect(resolveLocale(null), courseLocale);
  });
}
