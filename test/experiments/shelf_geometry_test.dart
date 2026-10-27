// Property: on the shelf, the page top of every lesson lies at the x the
// book scale gives it, in every frame, while books are closed, opening and
// open; the tops of a book form one smooth arc, lowest in the middle, where
// the pages reach furthest forward. The spine of every book stays as wide as
// a closed book.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

import '../support/preloaded_i18n.dart';

const _books = 5, _perBook = 20, _squeezed = 22.0;

late final LocalizationsDelegate<FlutterI18n> _i18n;

void main() {
  setUpAll(() async => _i18n = await preloadedI18n());
  testWidgets('lesson tops on the arc keep the x of the book scale', (
    tester,
  ) async {
    late BookScale scale;
    var tops = <Offset>[];
    var spines = <Rect>[];
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [_i18n],
        theme: romanTheme,
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 366,
              child: BookSliders(
                key: key,
                focus: BookFocus.idle,
                words: (from: 25, to: 32),
                grammar: (from: 25, to: 32),
                links: (left: true, right: true),
                shelf: true,
                onScale: (s) => scale = s,
                onPaintPages: (t, s) => (tops, spines) = (t, s),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final open = scale.widths[1];
    final seen = <String>{};

    void check(String when) {
      expect(tops, hasLength(_books * _perBook + 1));
      for (var l = 1; l <= tops.length; l++) {
        expect(
          (tops[l - 1].dx - scale.x(l)).abs(),
          lessThanOrEqualTo(0.5),
          reason: '$when: L$l',
        );
      }
      for (var b = 0; b <= _books; b++) {
        expect(
          spines[b].width,
          moreOrLessEquals(_squeezed),
          reason: '$when: spine of A${b + 1}',
        );
        expect(
          spines[b].center.dx,
          moreOrLessEquals(scale.starts[b] + scale.widths[b] / 2),
          reason: '$when: spine of A${b + 1}',
        );
      }
      final closedTop = tops.map((t) => t.dy).reduce(min);
      for (var b = 0; b < _books; b++) {
        final w = scale.widths[b];
        final state = w == _squeezed
            ? 'closed'
            : (w == open ? 'open' : 'opening');
        seen.add(state);
        final ys = [
          for (var i = 0; i < _perBook; i++) tops[b * _perBook + i].dy,
        ];
        // The outer lessons sit half a lesson inside the covers, which
        // stand in line with the closed books.
        for (final y in [ys.first, ys.last]) {
          expect(
            y - closedTop,
            inInclusiveRange(0, 2),
            reason: '$when: A${b + 1} covers in line',
          );
        }
        final rise = ys.reduce((a, b) => a > b ? a : b) - ys.first;
        if (state == 'closed') {
          expect(rise, lessThan(0.5), reason: '$when: A${b + 1} is flat');
          continue;
        }
        for (var i = 1; i < _perBook ~/ 2; i++) {
          expect(ys[i], greaterThan(ys[i - 1]), reason: '$when: A${b + 1}');
          expect(
            ys[_perBook - 1 - i],
            greaterThan(ys[_perBook - i]),
            reason: '$when: A${b + 1}',
          );
        }
        expect(rise, lessThan(w / 4), reason: '$when: A${b + 1} is shallow');
        if (state == 'open') {
          expect(rise, greaterThan(8), reason: '$when: A${b + 1} is curved');
        }
      }
    }

    check('settled');
    // The word end leaves A2 for A3, which opens.
    final origin = tester.getTopLeft(find.byKey(key));
    var x = scale.x(32);
    final gesture = await tester.startGesture(origin + Offset(x, 76));
    for (var f = 0; f < 40; f++) {
      x += 3;
      await gesture.moveTo(origin + Offset(x, 76));
      await tester.pump(const Duration(milliseconds: 16));
      check('frame $f');
    }
    await gesture.up();
    await tester.pumpAndSettle();
    check('released');
    expect(seen, {'closed', 'opening', 'open'});
    await tester.pump(const Duration(seconds: 4));
  });
}
