import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/locale_harness.dart';

Future<void> openLanguageScreen(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
  await settle(tester);
  await tester.tap(find.byKey(const Key('drawer.language')));
  await settle(tester);
}

void main() {
  test('an entry names the language in both tongues', () {
    final german = offeredLocales.firstWhere((o) => o.code == 'de');
    final english = offeredLocales.firstWhere((o) => o.code == 'en');

    expect(german.label, '🇩🇪 Deutsch (German)');
    expect(english.label, '🇬🇧 English');
  });

  test('search matches endonym, English name and code', () {
    final german = offeredLocales.firstWhere((o) => o.code == 'de');
    final english = offeredLocales.firstWhere((o) => o.code == 'en');

    for (final query in ['deutsch', 'DEUTSCH', 'German', 'de', ' de ']) {
      expect(german.matches(query), isTrue, reason: query);
      expect(english.matches(query), isFalse, reason: query);
    }
    expect(german.matches(''), isTrue);
  });

  test('search ignores accents on either side', () {
    const french = OfferedLocale('fr', 'Français', 'French', '🇫🇷');

    expect(french.matches('francais'), isTrue);
    expect(french.matches('Français'), isTrue);
    expect(foldForSearch('Español'), 'espanol');
  });

  testWidgets('the picker lists only what the search matches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAppOnDevice(tester, const Locale('de', 'DE'));
    await openLanguageScreen(tester);

    expect(find.byKey(const Key('language.de')), findsOneWidget);
    expect(find.byKey(const Key('language.en')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('language.search')), 'German');
    await settle(tester);

    expect(find.byKey(const Key('language.de')), findsOneWidget);
    expect(find.byKey(const Key('language.en')), findsNothing);
    expect(find.byKey(const Key('language.system')), findsOneWidget);
  });

  testWidgets('a picked language applies without a restart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAppOnDevice(tester, const Locale('de', 'DE'));
    expect(titleOf(tester), 'Latein Übung');

    await openLanguageScreen(tester);
    await tester.tap(find.byKey(const Key('language.en')));
    await settle(tester);

    expect(titleOf(tester), 'Latin Practice');
  });

  test('a picked language is there for the next start', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final container = freshContainer();
    addTearDown(container.dispose);
    await container.read(localeOverrideProvider.future);
    await container
        .read(localeOverrideProvider.notifier)
        .select(const Locale('en'));

    final restarted = freshContainer();
    addTearDown(restarted.dispose);
    expect(await restarted.read(localeOverrideProvider.future),
        const Locale('en'));

    await restarted.read(localeOverrideProvider.notifier).select(null);
    final andAgain = freshContainer();
    addTearDown(andAgain.dispose);
    expect(await andAgain.read(localeOverrideProvider.future), isNull);
  });

  testWidgets('a stored choice outranks the device language', (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await pumpAppOnDevice(tester, const Locale('de', 'DE'));

    expect(titleOf(tester), 'Latin Practice');
  });

  testWidgets('the System entry hands the choice back to the device',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await pumpAppOnDevice(tester, const Locale('de', 'DE'));
    expect(titleOf(tester), 'Latin Practice');

    await openLanguageScreen(tester);
    await tester.tap(find.byKey(const Key('language.system')));
    await settle(tester);

    expect(titleOf(tester), 'Latein Übung');
  });
}
