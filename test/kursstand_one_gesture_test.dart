import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/kursstand_shelf_driver.dart';
import 'support/kursstand_sliders_harness.dart';

void main() {
  testWidgets('while a ribbon is held, a drag with a second finger and a tap '
      'change neither the settings nor the layout', (tester) async {
    final probe = await pumpSliders(
      tester,
      words: LessonRange(25, 32),
      grammar: LessonRange(1, 32),
      from: false,
      to: true,
    );
    final before = probe.settings.toJson();

    final held = await tester.startGesture(
      shelfGrip(tester, words: true, start: false),
      pointer: 10,
    );
    await held.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await held.moveBy(const Offset(-20, 0));
    await tester.pumpAndSettle();
    final layout = probe.scale.widths;

    final second = await tester.startGesture(
      shelfGrip(tester, words: false, start: true),
      pointer: 11,
    );
    for (var i = 0; i < 10; i++) {
      await second.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await second.up();
    await tester.tapAt(shelfGrip(tester, words: true, start: true));
    await tester.pumpAndSettle();

    expect(probe.settings.toJson(), before);
    expect(probe.scale.widths, layout);

    await held.up();
    await tester.pumpAndSettle();
    expect(probe.settings.toJson(), before);
    expect(probe.scale.widths, layout);
  });
}
