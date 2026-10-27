// Property: a drag shows each new lesson on the shelf at once, but passes
// the course on only when the finger lets go.
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/kursstand_shelf_driver.dart';
import 'support/kursstand_sliders_harness.dart';

void main() {
  testWidgets('the course is passed on when the finger lets go', (
    tester,
  ) async {
    final probe = await pumpSliders(
      tester,
      words: LessonRange(5, 12),
      grammar: LessonRange(5, 12),
      from: true,
      to: true,
    );
    final grip = shelfGrip(tester, words: true, start: false);
    final gesture = await tester.startGesture(grip);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(grip + Offset(-6.0 * i, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final shown = probe.shown(tester).courseWords;
    expect(shown.to, lessThan(12));
    expect(probe.settings.courseWords, LessonRange(5, 12));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(probe.settings.courseWords, shown);
    expect(probe.settings.courseGrammar, shown);
    await tester.pump(const Duration(seconds: 4));
  });
}
