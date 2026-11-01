// Property: the book scale maps lessons to x strictly increasing, and its
// inverse gives back every lesson at its x and anywhere on its page, so a
// ribbon's thumb and the hit test agree. Within a book, every reached lesson
// has the same page and every lesson after the Kursstand [shelfSqueeze] of
// it, or else the least of [shelfMinPage] and an even page. A book with no
// reached lesson opens to at most [shelfMinPage] per lesson; the books with
// a reached lesson are never narrower than without the compression.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/widgets/kursstand_shelf.dart';

import 'support/gen_settings.dart';

void _check(BookScaleCase c, String when) {
  BookScale scale(int kursstand) =>
      BookScale(c.starts, c.expansion, c.left, c.width, kursstand: kursstand);
  final s = scale(c.kursstand);
  final plain = scale(lastLesson);
  for (var l = 2; l <= laterLesson; l++) {
    expect(s.x(l), greaterThan(s.x(l - 1)), reason: '$when: L$l after L$l-1');
  }
  for (var l = 1; l <= laterLesson; l++) {
    expect(s.lessonAt(s.x(l)), l, reason: '$when: the thumb of L$l');
  }
  for (var b = 0; b < c.starts.length; b++) {
    final edges = s.pageEdges(b);
    final first = c.starts[b];
    expect(edges.first, s.starts[b], reason: '$when: book ${b + 1} left');
    expect(
      edges.last,
      moreOrLessEquals(s.starts[b] + s.widths[b]),
      reason: '$when: book ${b + 1} right',
    );
    final reached = [
      for (var i = 0; i < edges.length - 1; i++)
        if (first + i <= c.kursstand) s.cell(first + i),
    ];
    final n = s.lessonsIn(b);
    if (reached.isEmpty) {
      expect(
        s.widths[b],
        lessThanOrEqualTo(max(22, n * shelfMinPage) + 1e-9),
        reason: '$when: book ${b + 1} has no reached lesson',
      );
    } else {
      expect(
        s.widths[b],
        greaterThanOrEqualTo(plain.widths[b] - 1e-9),
        reason: '$when: book ${b + 1} as wide as uncompressed',
      );
    }
    final unit = reached.isEmpty ? s.widths[b] / n : reached.first;
    for (var i = 0; i < edges.length - 1; i++) {
      final l = first + i;
      final cell = s.cell(l);
      expect(cell, moreOrLessEquals(edges[i + 1] - edges[i]), reason: when);
      for (final f in [0.0, 0.3, 0.99]) {
        expect(
          s.lessonAt(edges[i] + f * cell),
          l,
          reason: '$when: a finger on the page of L$l',
        );
      }
      if (reached.isEmpty || l <= c.kursstand) {
        expect(cell, moreOrLessEquals(unit), reason: '$when: the page of L$l');
      } else {
        final floor = min(shelfMinPage, s.widths[b] / n);
        expect(cell, lessThanOrEqualTo(unit + 1e-9), reason: '$when: L$l');
        expect(
          (cell - unit * shelfSqueeze).abs() < 1e-9 ||
              ((cell - floor).abs() < 1e-9 && cell > unit * shelfSqueeze),
          isTrue,
          reason: '$when: the page of L$l is squeezed, or at its floor',
        );
      }
      if (l <= c.kursstand) {
        expect(
          cell,
          greaterThanOrEqualTo(plain.cell(l) - 1e-9),
          reason: '$when: a reached page is never narrower',
        );
      }
    }
  }
}

void main() {
  test('the scale is strictly increasing, exactly inverted and squeezes '
      'only after the Kursstand', () {
    const course = [1, 21];
    final fixed = <BookScaleCase>[
      // The ribbon is dragged into the volume after the Kursstand.
      (
        starts: course,
        expansion: const [0.3, 1.0],
        left: 24,
        width: 240,
        kursstand: 5,
      ),
      for (final k in [1, 20, 21, 24, lastLesson])
        for (final expansion in [
          [1.0, 0.3],
          [0.3, 1.0],
          [1.0, 1.0],
          [0.0, 0.0],
        ])
          for (final width in [240.0, 1200.0])
            (
              starts: course,
              expansion: expansion,
              left: 24,
              width: width,
              kursstand: k,
            ),
    ];
    for (final (i, c) in fixed.indexed) {
      _check(c, 'fixed $i: $c');
    }
    final rng = Random(3512);
    for (var i = 0; i < 3000; i++) {
      final c = drawBookScaleCase(rng);
      _check(c, 'case $i: $c');
    }
  });

  test('a squeezed page of the book a finger drags in stays wide enough to '
      'land on at 360 px', () {
    // The track of the shelf in the settings card on a 360 px phone.
    const track = 240.0;
    var narrowest = double.infinity;
    for (var k = 1; k <= lastLesson; k++) {
      for (final (dragged, other) in [(0, 1), (1, 0)]) {
        for (final rest in [0.0, 0.3, 1.0]) {
          final expansion = [0.0, 0.0]
            ..[dragged] = 1
            ..[other] = rest;
          final s = BookScale([1, 21], expansion, 24, track, kursstand: k);
          final first = dragged == 0 ? 1 : 21;
          for (var l = first; l < first + s.lessonsIn(dragged); l++) {
            narrowest = min(narrowest, s.cell(l));
          }
        }
      }
    }
    expect(narrowest, greaterThanOrEqualTo(shelfMinPage - 1e-9));
  });
}
