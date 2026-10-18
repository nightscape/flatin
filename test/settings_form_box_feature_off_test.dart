import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';

import 'support/stored_settings.dart';

void main() {
  testWidgets('a form box off by its feature is greyed and ignores taps', (
    tester,
  ) async {
    final stored = {
      'disabledForms': <String, List<String>>{},
      'disabledFeatures': {
        'verbs': {
          'tempus': ['perf'],
        },
      },
      'disabledTypes': <String, List<String>>{},
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
      settingsVersionField: settingsVersion,
    };
    await openSettingsWith(tester, stored, page: 'verbs');
    final before = await storedSettings();

    final tile = formTile('verbs', 'ind.perf.akt.1.sg');
    expect(tester.widget<CheckboxListTile>(tile).onChanged, isNull);
    expect(
      find.descendant(
        of: tile,
        matching: find.text('Perfekt ist ausgeschaltet'),
      ),
      findsOneWidget,
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(await storedSettings(), before);
  });
}
