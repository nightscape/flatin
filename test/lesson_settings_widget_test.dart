import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stored_settings.dart';

void main() {
  testWidgets('the word page lists the lessons of the second volume',
      (tester) async {
    await openSettingsWith(tester, {}, page: 'words');

    for (final lesson in ['Lektion 21', 'Lektion 40']) {
      var scrolls = 0;
      while (find.text(lesson).evaluate().isEmpty) {
        expect(scrolls++, lessThan(200), reason: lesson);
        await tester.drag(find.byType(ListView), const Offset(0, -20000));
        await tester.pump();
      }
      expect(find.text(lesson), findsOneWidget, reason: lesson);
    }
  });
}
