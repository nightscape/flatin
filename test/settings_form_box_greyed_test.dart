import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';

import 'support/stored_settings.dart';

Color? titleColor(WidgetTester tester, Finder tile) =>
    (tester.widget<CheckboxListTile>(tile).title! as Text).style?.color;

void main() {
  testWidgets('the label of a feature-off form row is greyed', (tester) async {
    await openSettingsWith(tester, {
      settingsVersionField: settingsVersion,
      'disabledForms': <String, List<String>>{},
      'disabledFeatures': {
        'verbs': {
          'tempus': ['perf'],
        },
      },
      'disabledTypes': <String, List<String>>{},
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
    });
    final off = formTile('verbs', 'ind.perf.akt.1.sg');
    final on = formTile('verbs', 'ind.praes.akt.1.sg');
    expect(
      titleColor(tester, off),
      isNot(titleColor(tester, on)),
      reason:
          'a feature-off row must look greyed, not identical to an active row',
    );
  });
}
