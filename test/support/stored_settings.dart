import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'word_classification_harness.dart';

Future<Map<String, dynamic>> storedSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString('practice_settings')!)
      as Map<String, dynamic>;
}

/// Opens the settings screen on an app whose stored settings are [stored].
Future<void> openSettingsWith(
  WidgetTester tester,
  Map<String, dynamic> stored,
) async {
  SharedPreferences.setMockInitialValues({
    'practice_settings': jsonEncode(stored),
  });
  tester.view.physicalSize = const Size(1200, 60000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(wrapInApp(
    const SettingsScreen(),
    forcedLocale: const Locale('de'),
  ));
  await letItLoad(tester);
}

bool isChecked(WidgetTester tester, Finder tile) =>
    tester.widget<CheckboxListTile>(tile).value!;

Finder formTile(String dataFileId, String key) =>
    find.byKey(Key('form.$dataFileId.$key'));

Finder typeTile(String typeName) =>
    find.widgetWithText(CheckboxListTile, typeName);
