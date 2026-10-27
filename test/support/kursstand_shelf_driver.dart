import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/screens/kursstand_sliders.dart';
import 'package:latin_practice/widgets/kursstand_shelf.dart';

import 'word_classification_harness.dart' show letItLoad;

final _shelf = find.descendant(
  of: find.byType(KursstandSliders),
  matching: find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is ShelfPainter,
  ),
);

/// What the shelf painted last.
ShelfPainter shelfPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_shelf).painter! as ShelfPainter;

/// The point on the screen at [lesson] and height [y] on the shelf.
Offset shelfAt(WidgetTester tester, int lesson, double y) =>
    tester.getTopLeft(_shelf) + Offset(shelfPainter(tester).scale.x(lesson), y);

double shelfX(WidgetTester tester, int lesson) => shelfAt(tester, lesson, 0).dx;

/// Where a finger grabs a bound: a tied word bound at its bow, a word
/// ribbon above the bows, a grammar ribbon below the word ribbons' ends.
Offset shelfGrip(
  WidgetTester tester, {
  required bool words,
  required bool start,
}) {
  final shelf = shelfPainter(tester);
  final r = words ? shelf.words : shelf.grammar;
  final lesson = start ? r.from : r.to;
  final tied = start ? shelf.tiedFrom : shelf.tiedTo;
  if (words && tied) {
    return tester.getTopLeft(_shelf) + shelfBowAt(shelf.scale, lesson).$1;
  }
  return shelfAt(tester, lesson, words ? 56 : 140);
}

/// Drags a bound (see [shelfGrip]) onto lesson [to], following the books as
/// they open, and lets go.
Future<void> dragBound(
  WidgetTester tester, {
  required bool words,
  required bool start,
  required int to,
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final grip = shelfGrip(tester, words: words, start: start);
  final gesture = await tester.startGesture(grip, kind: kind);
  for (var i = 1; i <= 20; i++) {
    await gesture.moveTo(
      Offset(grip.dx + (shelfX(tester, to) - grip.dx) * i / 20, grip.dy),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  for (var i = 0; i < 5; i++) {
    await tester.pumpAndSettle();
    await gesture.moveTo(Offset(shelfX(tester, to), grip.dy));
  }
  await gesture.up();
  await tester.pumpAndSettle();
  await letItLoad(tester);
}

/// Moves a range onto [to] by dragging the bound that has to move first.
Future<void> dragRange(
  WidgetTester tester, {
  required bool words,
  required LessonRange to,
}) async {
  final shelf = shelfPainter(tester);
  final r = words ? shelf.words : shelf.grammar;
  final endFirst = to.from > r.to;
  for (final start in endFirst ? [false, true] : [true, false]) {
    await dragBound(
      tester,
      words: words,
      start: start,
      to: start ? to.from : to.to,
    );
  }
}
