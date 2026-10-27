import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/app_fonts.dart';
import 'support/kursstand_sliders_harness.dart';

const _width = 366.0;

/// The labels clear each other, the card and the dragged range's ribbon
/// ends.
void _expectClear(SlidersProbe probe, LessonRange r, double y) {
  expect(probe.labels, hasLength(2));
  final [start, end] = probe.labels;
  expect(start.overlaps(end), isFalse, reason: '$start $end');
  for (final label in probe.labels) {
    expect(
      label.left >= 0 && label.right <= _width && label.top >= 0,
      isTrue,
      reason: '$label leaves the card',
    );
    for (final l in [r.from, r.to]) {
      final thumb = Rect.fromCircle(
        center: Offset(probe.scale.x(l), y),
        radius: 10,
      );
      expect(label.overlaps(thumb), isFalse, reason: '$label covers $thumb');
    }
  }
}

void main() {
  setUpAll(loadAppFonts);

  // (name, words, grammar, left linked, right linked, grab words?, grab lesson)
  final cases = [
    (
      'words one lesson apart',
      LessonRange(20, 21),
      LessonRange(5, 30),
      false,
      false,
      true,
      20,
    ),
    (
      'grammar one lesson apart',
      LessonRange(5, 30),
      LessonRange(20, 21),
      false,
      false,
      false,
      21,
    ),
    ('words at L1', LessonRange(1, 2), LessonRange(1, 2), true, true, true, 1),
    (
      'words at the end',
      LessonRange(laterLesson - 1, laterLesson),
      LessonRange(3, laterLesson),
      false,
      true,
      true,
      laterLesson,
    ),
    (
      'grammar at L1, thumbs close',
      LessonRange(5, 30),
      LessonRange(1, 4),
      false,
      false,
      false,
      1,
    ),
    (
      'grammar at the end, thumbs close',
      LessonRange(5, 30),
      LessonRange(laterLesson - 3, laterLesson),
      false,
      false,
      false,
      laterLesson,
    ),
    (
      'grammar shallow chains',
      LessonRange(18, 19),
      LessonRange(1, laterLesson),
      false,
      false,
      false,
      1,
    ),
    (
      'words shallow chains',
      LessonRange(1, laterLesson),
      LessonRange(18, 19),
      false,
      false,
      true,
      laterLesson,
    ),
  ];
  for (final (name, words, grammar, left, right, onWords, lesson) in cases) {
    testWidgets('value labels: $name', (tester) async {
      final probe = await pumpSliders(
        tester,
        words: words,
        grammar: grammar,
        from: left,
        to: right,
      );
      expect(probe.labels, isEmpty);
      final before = probe.settings;

      final y = probe.y(tester, words: onWords);
      final gesture = await tester.startGesture(
        probe.origin(tester) + Offset(probe.scale.x(lesson), y),
      );
      // Past the drag slop outwards and back, so the slider picks the
      // grabbed thumb and the drag ends on its lesson.
      final r = onWords ? before.courseWords : before.courseGrammar;
      final outwards = lesson == r.from ? -20.0 : 20.0;
      await gesture.moveBy(Offset(outwards, 0));
      await tester.pump();
      await gesture.moveBy(Offset(-outwards, 0));
      await tester.pumpAndSettle();

      expect(
        (probe.shown(tester).courseWords, probe.shown(tester).courseGrammar),
        (before.courseWords, before.courseGrammar),
        reason: 'the drag must not move the thumbs',
      );
      _expectClear(probe, r, y);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(probe.labels, isEmpty);
    });
  }

  // (where, words, grammar, grab words?, grab lesson, drag to, expected)
  for (final (where, words, grammar, onWords, grab, to, expected) in [
    (
      'a compressed book',
      LessonRange(25, 32),
      LessonRange(1, 20),
      false,
      20,
      2,
      LessonRange(1, 2),
    ),
    (
      'an open book',
      LessonRange(25, 32),
      LessonRange(21, 32),
      true,
      32,
      26,
      LessonRange(25, 26),
    ),
  ]) {
    testWidgets('thumbs on neighbouring lessons in $where, with labels', (
      tester,
    ) async {
      final probe = await pumpSliders(
        tester,
        words: words,
        grammar: grammar,
        from: false,
        to: false,
      );
      final origin = probe.origin(tester);
      final y = probe.y(tester, words: onWords);
      final x = probe.scale.x;

      // Inwards in small steps, so the drag stays inside the book.
      final gesture = await tester.startGesture(origin + Offset(x(grab), y));
      var fx = x(grab);
      while (fx > x(to)) {
        fx = max(fx - 2, x(to));
        await gesture.moveTo(origin + Offset(fx, y));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      final settings = probe.shown(tester);
      expect(onWords ? settings.courseWords : settings.courseGrammar, expected);
      if (!onWords) {
        expect(
          probe.scale.widths[0],
          lessThan(probe.scale.widths[1]),
          reason: 'book 1 stays compressed',
        );
        expect(
          probe.scale.cell(1),
          lessThan(8),
          reason: 'the default thumb separation would not fit',
        );
      }
      _expectClear(probe, expected, y);
      // A label leaves the thumb height only to clear a chain, and never
      // the slider's own band.
      for (final label in probe.labels) {
        expect(
          label.top >= y - 24 && label.bottom <= y + 24,
          isTrue,
          reason: '$label leaves the slider at $y',
        );
      }
      if (onWords) {
        // Open book, nothing flips: each label sits just outside its thumb.
        final [start, end] = probe.labels;
        expect(start.right, moreOrLessEquals(x(25) - 14, epsilon: 0.5));
        expect(end.left, moreOrLessEquals(x(26) + 14, epsilon: 0.5));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(probe.labels, isEmpty);
    });
  }
}
