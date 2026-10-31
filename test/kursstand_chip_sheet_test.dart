import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/i18n_keys.dart';
import 'support/word_classification_harness.dart';

final _chip = find.byKey(const Key('home.kursstand'));
final _coins = find.byKey(const Key('home.coins'));
final _next = find.byKey(const Key('kursstand.next'));
final _picker = find.byKey(const Key('kursstand.picker'));

Future<void> _openHome(WidgetTester tester, Settings settings) async {
  SharedPreferences.setMockInitialValues({
    'practice_settings': jsonEncode(settings.toJson()),
  });
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapInApp(const HomeScreen(), forcedLocale: const Locale('de')),
  );
  await letItLoad(tester);
}

String _chipText(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: _chip, matching: find.byType(Text)))
    .data!;

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(_chip);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final at24 = Settings(courseWords: LessonRange(1, 24), kursstand: 24);

  testWidgets('the app bar shows the Kursstand beside the coins at 360x640', (
    tester,
  ) async {
    await _openHome(tester, at24);

    expect(tester.takeException(), isNull);
    expect(_chipText(tester), '24');
    expect(_coins, findsOneWidget);
    final bar = tester.getRect(find.byType(AppBar));
    expect(bar.contains(tester.getCenter(_chip)), isTrue);
    expect(bar.contains(tester.getCenter(_coins)), isTrue);
    expect(tester.getRect(_chip).right, lessThan(tester.getRect(_coins).left));
  });

  testWidgets('the next button is the first and largest control of the '
      'sheet at 360x640', (tester) async {
    await _openHome(tester, at24);
    await _openSheet(tester);

    expect(tester.takeException(), isNull);
    final next = tester.getRect(_next);
    final picker = tester.getRect(_picker);
    expect(next.bottom, lessThanOrEqualTo(picker.top));
    expect(next.width * next.height, greaterThan(picker.width * picker.height));
  });

  test('every Kursstand text exists in German and English', () {
    Set<String> kursstand(String code) =>
        translationKeys(code).where((k) => k.startsWith('kursstand.')).toSet();
    expect(kursstand('de'), isNotEmpty);
    expect(kursstand('en'), kursstand('de'));
  });
}
