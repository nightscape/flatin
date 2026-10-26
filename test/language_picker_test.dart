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

    expect(german.label, '🇩🇪 Deutsch (German)');
    expect(offeredLocales.last.label, '🇬🇧 English');
    expect(offeredLocales.map((o) => o.code), ['de', 'en']);
  });

  test('search matches endonym, English name and code', () {
    final german = offeredLocales.firstWhere((o) => o.code == 'de');

    for (final query in ['deutsch', 'DEUTSCH', 'German', 'de', ' de ']) {
      expect(german.matches(query), isTrue, reason: query);
    }
    expect(german.matches('english'), isFalse);
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

    await tester.enterText(find.byKey(const Key('language.search')), 'French');
    await settle(tester);

    expect(find.byKey(const Key('language.de')), findsNothing);
    expect(find.byKey(const Key('language.system')), findsOneWidget);
  });

  test('a picked language is there for the next start', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final container = freshContainer();
    addTearDown(container.dispose);
    await container.read(localeOverrideProvider.future);
    await container
        .read(localeOverrideProvider.notifier)
        .select(const Locale('de'));

    final restarted = freshContainer();
    addTearDown(restarted.dispose);
    expect(
      await restarted.read(localeOverrideProvider.future),
      const Locale('de'),
    );

    await restarted.read(localeOverrideProvider.notifier).select(null);
    final andAgain = freshContainer();
    addTearDown(andAgain.dispose);
    expect(await andAgain.read(localeOverrideProvider.future), isNull);
  });

  testWidgets('the System entry hands the choice back to the device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'de'});
    await pumpAppOnDevice(tester, const Locale('en', 'US'));

    await openLanguageScreen(tester);
    await tester.tap(find.byKey(const Key('language.system')));
    await settle(tester);

    expect(nounsLabelOf(tester), 'Nouns (declension)');
    expect(
      (await SharedPreferences.getInstance()).containsKey('app_locale'),
      isFalse,
    );
  });
}
