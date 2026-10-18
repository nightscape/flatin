import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';

import 'support/stored_settings.dart';

void main() {
  testWidgets('a feature box switches its axis value off and stores it', (
    tester,
  ) async {
    await openSettingsWith(tester, {
      settingsVersionField: settingsVersion,
      'disabledForms': <String, List<String>>{},
      'disabledFeatures': <String, dynamic>{},
      'disabledTypes': <String, List<String>>{},
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
    }, page: 'verbs');
    final feature = find.byKey(const Key('feature.verbs.tempus.perf'));
    expect(isChecked(tester, feature), isTrue);

    await tester.tap(feature);
    await tester.pumpAndSettle();

    expect(isChecked(tester, feature), isFalse);
    final stored = await storedSettings();
    expect(stored['disabledFeatures']['verbs']['tempus'], ['perf']);
  });
}
