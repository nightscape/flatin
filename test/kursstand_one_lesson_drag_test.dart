// Property: on a one-lesson range with both bounds tied, the two bows lie on
// each other, and dragging them moves a bound either way.
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/kursstand_shelf_driver.dart';
import 'support/kursstand_sliders_harness.dart';

void main() {
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    for (final (to, expected) in [
      (20, LessonRange(20, 24)),
      (28, LessonRange(24, 28)),
    ]) {
      testWidgets('the bows on L24 drag to L$to ($kind)', (tester) async {
        final probe = await pumpSliders(
          tester,
          words: LessonRange(24, 24),
          grammar: LessonRange(24, 24),
          from: true,
          to: true,
        );
        await dragBound(
          tester,
          words: true,
          start: to < 24,
          to: to,
          kind: kind,
        );
        expect(probe.settings.courseWords, expected);
        expect(probe.settings.courseGrammar, expected);
        await tester.pump(const Duration(seconds: 4));
      });
    }
  }
}
