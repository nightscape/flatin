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

  for (final device in const [Locale('en', 'US'), Locale('fr', 'FR')]) {
    testWidgets('a $device device shows the German home title', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpAppOnDevice(tester, device);

      expect(titleOf(tester), 'Latein Übung');
    });
  }

  testWidgets('a stored language the app no longer offers is dropped', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await pumpAppOnDevice(tester, const Locale('en', 'US'));

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
    expect(resolveLocale([const Locale('en')]), courseLocale);
    expect(resolveLocale([const Locale('fr')]), courseLocale);
    expect(resolveLocale(null), courseLocale);
  });
}
