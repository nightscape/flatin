import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/kursstand_sliders_harness.dart';

void main() {
  testWidgets('after the thumb enters a book, the widths hold while it stays '
      'there: holding 5 s, fine drags, release', (tester) async {
    final probe = await pumpSliders(
      tester,
      words: LessonRange(25, 32),
      grammar: LessonRange(1, 32),
      from: false,
      to: true,
    );
    final origin = probe.origin(tester);
    final y = probe.y(tester, words: true);
    final before = probe.scale.widths;
    expect(before[0], lessThan(before[1]), reason: 'book 1 starts squeezed');

    // The word start leaves book 2 to the left in 4 px steps.
    var x = probe.scale.x(25);
    final gesture = await tester.startGesture(origin + Offset(x, y));
    while (probe.scale.lessonAt(x) > 20) {
      x -= 4;
      await gesture.moveTo(origin + Offset(x, y));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    final entered = probe.scale.widths;
    expect(entered[0], greaterThan(before[0]), reason: 'book 1 opens');

    void expectHeld(String when) {
      expect(probe.scale.widths, entered, reason: when);
      expect(probe.scale.lessonAt(x), lessThanOrEqualTo(20), reason: when);
    }

    for (var t = 0; t < 50; t++) {
      await tester.pump(const Duration(milliseconds: 100));
      expectHeld('holding, ${t * 100} ms');
    }
    for (final dx in [-3.0, -3.0, 3.0, -2.0]) {
      x += dx;
      await gesture.moveTo(origin + Offset(x, y));
      for (var f = 0; f < 20; f++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectHeld('fine drag by $dx, frame $f');
      }
    }
    await gesture.up();
    for (var t = 0; t < 35; t++) {
      await tester.pump(const Duration(milliseconds: 100));
      expectHeld('released, ${t * 100} ms');
    }
  });

  testWidgets('a screen-reader tie that moves a ribbon into another book '
      'counts as a book change: that book grows', (tester) async {
    final probe = await pumpSliders(
      tester,
      words: LessonRange(5, 30),
      grammar: LessonRange(21, 35),
      from: false,
      to: false,
    );
    final before = probe.scale.widths;
    expect(before[0], lessThan(before[1]), reason: 'book 1 starts half open');

    tester
        .widget<Semantics>(find.byKey(const Key('kursstand.tie.left')))
        .properties
        .onTap!();
    await tester.pumpAndSettle();

    expect(probe.settings.courseGrammar, LessonRange(5, 35));
    expect(probe.scale.widths[0], greaterThan(before[0]));
  });
}
