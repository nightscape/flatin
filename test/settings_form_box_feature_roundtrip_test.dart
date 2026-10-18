import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';

import 'package:flutter/material.dart';
import 'support/stored_settings.dart';

void main() {
  testWidgets('a form box keeps its own state while its feature is off', (
    tester,
  ) async {
    await openSettingsWith(tester, {
      settingsVersionField: settingsVersion,
      'disabledForms': {
        'verbs': ['ind.perf.akt.1.sg'],
      },
      'disabledFeatures': <String, dynamic>{},
      'disabledTypes': <String, List<String>>{},
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
    }, page: 'verbs');
    final tile = formTile('verbs', 'ind.perf.akt.1.sg');
    final feature = find.byKey(const Key('feature.verbs.tempus.perf'));
    expect(isChecked(tester, tile), isFalse);

    await tester.tap(feature);
    await tester.pumpAndSettle();
    expect(isChecked(tester, tile), isFalse);
    expect(isChecked(tester, formTile('verbs', 'ind.perf.akt.2.sg')), isTrue);

    await tester.tap(feature);
    await tester.pumpAndSettle();

    expect(isChecked(tester, tile), isFalse);
    expect(isChecked(tester, formTile('verbs', 'ind.perf.akt.2.sg')), isTrue);
  });
}
