import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/kursstand_sliders_harness.dart';

void main() {
  for (final words in [false, true]) {
    final slider = words ? 'word' : 'grammar';
    testWidgets('pushing the $slider start thumb onto the end thumb in another '
        'book leaves the end where it was', (tester) async {
      final pushed = LessonRange(19, 30), other = LessonRange(1, 16);
      final probe = await pumpSliders(
        tester,
        words: words ? pushed : other,
        grammar: words ? other : pushed,
        from: false,
        to: false,
      );
      final origin = probe.origin(tester);
      final y = probe.y(tester, words: words);
      final gesture = await tester.startGesture(
        origin + Offset(probe.scale.x(19), y),
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      // Two moves in one frame: the first puts the start on the end.
      await gesture.moveBy(const Offset(100, 0));
      await gesture.moveBy(const Offset(5, 0));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      final settings = probe.settings;
      expect((words ? settings.courseWords : settings.courseGrammar).to, 30);
    });
  }
}
