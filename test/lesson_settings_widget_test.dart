import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/screens/settings_screen.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('the lesson list reaches the second volume', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(wrapInApp(const SettingsScreen()));
    await letItLoad(tester);

    for (final lesson in ['Lektion 21', 'Lektion 40 Junkturen']) {
      final tile = find.byKey(Key('lesson.$lesson'));
      await tester.scrollUntilVisible(
        tile,
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 2000,
      );
      expect(tile, findsOneWidget, reason: lesson);
    }
  });
}
