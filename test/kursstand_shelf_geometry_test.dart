// Property: on the shelf, the page top of every lesson lies at the x the
// book scale gives it, in every frame, while books are closed, opening and
// open; the tops of a book form one smooth arc, lowest in the middle, where
// the pages reach furthest forward. The spine of every book stays as wide as
// a closed book.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/kursstand_shelf_driver.dart';
import 'support/kursstand_sliders_harness.dart';

const _squeezed = 22.0;

void main() {
  testWidgets('lesson tops on the arc keep the x of the book scale', (
    tester,
  ) async {
    final probe = await pumpSliders(
      tester,
      words: LessonRange(5, 12),
      grammar: LessonRange(5, 12),
      from: true,
      to: true,
    );
    final open = probe.scale.widths[0];
    final books = probe.scale.bookStarts.length;
    final seen = <String>{};

    void check(String when) {
      final scale = probe.scale;
      final tops = probe.tops;
      expect(tops, hasLength(laterLesson));
      for (var l = 1; l <= laterLesson; l++) {
        expect(
          (tops[l - 1].dx - scale.x(l)).abs(),
          lessThanOrEqualTo(0.5),
          reason: '$when: L$l',
        );
      }
      for (var b = 0; b <= books; b++) {
        expect(
          probe.spines[b].width,
          moreOrLessEquals(_squeezed),
          reason: '$when: spine of book ${b + 1}',
        );
        expect(
          probe.spines[b].center.dx,
          moreOrLessEquals(scale.starts[b] + scale.widths[b] / 2),
          reason: '$when: spine of book ${b + 1}',
        );
      }
      final closedTop = tops.map((t) => t.dy).reduce(min);
      for (var b = 0; b < books; b++) {
        final w = scale.widths[b];
        final state = w == _squeezed
            ? 'closed'
            : (w == open ? 'open' : 'opening');
        seen.add(state);
        final first = scale.bookStarts[b], n = scale.lessonsIn(b);
        final ys = [for (var i = 0; i < n; i++) tops[first - 1 + i].dy];
        // The outer lessons sit half a lesson inside the covers, which
        // stand in line with the closed books.
        for (final y in [ys.first, ys.last]) {
          expect(
            y - closedTop,
            inInclusiveRange(0, 2),
            reason: '$when: book ${b + 1} covers in line',
          );
        }
        final rise = ys.reduce(max) - ys.first;
        if (state == 'closed') {
          expect(rise, lessThan(0.5), reason: '$when: book ${b + 1} is flat');
          continue;
        }
        for (var i = 1; i < n ~/ 2; i++) {
          expect(ys[i], greaterThan(ys[i - 1]), reason: '$when: book ${b + 1}');
          expect(
            ys[n - 1 - i],
            greaterThan(ys[n - i]),
            reason: '$when: book ${b + 1}',
          );
        }
        expect(rise, lessThan(w / 4), reason: '$when: book ${b + 1} shallow');
        if (state == 'open') {
          expect(rise, greaterThan(8), reason: '$when: book ${b + 1} curved');
        }
      }
    }

    check('settled');
    // The bow of the word end leaves book 1 for book 2, which opens.
    final grip = shelfGrip(tester, words: true, start: false);
    var x = grip.dx;
    final gesture = await tester.startGesture(grip);
    for (var f = 0; f < 60; f++) {
      x += 3;
      await gesture.moveTo(Offset(x, grip.dy));
      await tester.pump(const Duration(milliseconds: 16));
      check('frame $f');
    }
    await gesture.up();
    await tester.pumpAndSettle();
    check('released');
    expect(probe.settings.courseWords.to, greaterThan(20));
    expect(seen, {'closed', 'opening', 'open'});
    await tester.pump(const Duration(seconds: 4));
  });
}
