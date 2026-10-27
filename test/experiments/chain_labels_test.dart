import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

const _width = 366.0, _later = 101, _wordsY = 76.0;

Future<void> _loadIcons() async {
  final loader = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await loader.load();
}

void main() {
  setUpAll(_loadIcons);

  // (name, words, grammar, left linked, right linked, grab words?, grab lesson)
  final cases = [
    (
      'words one lesson apart',
      (from: 20, to: 21),
      (from: 5, to: 30),
      false,
      false,
      true,
      20,
    ),
    (
      'grammar one lesson apart',
      (from: 5, to: 30),
      (from: 20, to: 21),
      false,
      false,
      false,
      21,
    ),
    ('words at L1', (from: 1, to: 2), (from: 1, to: 2), true, true, true, 1),
    (
      'words at the end',
      (from: _later - 1, to: _later),
      (from: 3, to: _later),
      false,
      true,
      true,
      _later,
    ),
    (
      'grammar at L1, thumbs close',
      (from: 5, to: 30),
      (from: 1, to: 4),
      false,
      false,
      false,
      1,
    ),
    (
      'grammar at the end, thumbs close',
      (from: 5, to: 30),
      (from: _later - 3, to: _later),
      false,
      false,
      false,
      _later,
    ),
    (
      'grammar shallow chains',
      (from: 18, to: 19),
      (from: 1, to: _later),
      false,
      false,
      false,
      1,
    ),
    (
      'words shallow chains',
      (from: 1, to: _later),
      (from: 18, to: 19),
      false,
      false,
      true,
      _later,
    ),
  ];
  for (final (name, words, grammar, left, right, onWords, lesson) in cases) {
    for (final shelf in [false, true]) {
      final grammarY = shelf ? 124.0 : 140.0;
      testWidgets('value labels: $name${shelf ? ' (shelf)' : ''}', (
        tester,
      ) async {
        var labels = <Rect>[];
        var chains = <(Offset, Offset)>[];
        late BookScale scale;
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: romanTheme,
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: _width,
                  child: BookSliders(
                    key: key,
                    focus: BookFocus.idle,
                    words: words,
                    grammar: grammar,
                    links: (left: left, right: right),
                    shelf: shelf,
                    onScale: (s) => scale = s,
                    onPaintChains: (e) => chains = e,
                    onPaintLabels: (r) => labels = r,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(labels, isEmpty);

        final origin = tester.getTopLeft(find.byKey(key));
        final y = onWords ? _wordsY : grammarY;
        final gesture = await tester.startGesture(
          origin + Offset(scale.x(lesson), y),
        );
        // Past the drag slop outwards and back, so the slider picks the
        // grabbed thumb and the drag ends on its lesson.
        final r = onWords ? words : grammar;
        final outwards = lesson == r.from ? -20.0 : 20.0;
        await gesture.moveBy(Offset(outwards, 0));
        await tester.pump();
        await gesture.moveBy(Offset(-outwards, 0));
        await tester.pumpAndSettle();

        expect(labels, hasLength(2));
        String stop(int l) => l == _later ? 'Später' : 'L$l';
        expect(
          find.textContaining(
            '${onWords ? 'Wörter' : 'Grammatik'} ${stop(r.from)}–${stop(r.to)}',
            findRichText: true,
          ),
          findsOneWidget,
          reason: 'the drag must not move the thumbs',
        );
        final [start, end] = labels;
        expect(start.overlaps(end), isFalse, reason: '$start $end');
        for (final r in labels) {
          expect(
            r.left >= 0 && r.right <= _width && r.top >= 0,
            isTrue,
            reason: '$r leaves the card',
          );
        }
        for (final l in [r.from, r.to]) {
          final thumb = Rect.fromCircle(
            center: Offset(scale.x(l), y),
            radius: 10,
          );
          for (final label in labels) {
            expect(
              label.overlaps(thumb),
              isFalse,
              reason: '$label covers $thumb',
            );
          }
        }
        for (final (a, b) in chains) {
          final symbol = Rect.fromCenter(
            center: (a + b) / 2,
            width: 44,
            height: 44,
          );
          for (final r in labels) {
            expect(r.overlaps(symbol), isFalse, reason: '$r covers $symbol');
            // The chain is at most 9 px wide.
            for (var t = 0.0; t <= 1; t += 0.01) {
              final p = Offset.lerp(a, b, t)!;
              expect(
                r.inflate(4.5).contains(p),
                isFalse,
                reason: '$r covers the chain at $p',
              );
            }
          }
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(labels, isEmpty);
        await tester.pump(const Duration(seconds: 4));
      });
    }
  }

  // (where, card, grab words?, grab lesson, drag to lesson, expected range)
  for (final focus in BookFocus.values) {
    for (final (where, card, onWords, grab, to, expected) in [
      (
        'a compressed book',
        'Grammatik in Agite 1',
        false,
        20,
        2,
        'Grammatik L1–L2',
      ),
      ('an open book', 'Nur aktuelles Buch', true, 32, 26, 'Wörter L25–L26'),
    ]) {
      // Only these rules keep a half-open book half open while dragging in it.
      final staysCompressed =
          focus == BookFocus.idle || focus == BookFocus.draggedOnRelease;
      if (where == 'a compressed book' && !staysCompressed) continue;
      testWidgets('book labels ${focus.name}: one lesson apart in $where', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(780, 2400);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final scales = <String, BookScale>{};
        final labels = <String, List<Rect>>{};
        await tester.pumpWidget(
          MaterialApp(
            theme: romanTheme,
            home: Scaffold(
              body: BooksDemo(
                focus: focus,
                onScale: (c, s) => scales[c] = s,
                onPaintLabels: (c, l) => labels[c] = l,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cardRect = tester.getRect(find.byKey(Key(card)));
        final slider = tester.getRect(
          find
              .descendant(
                of: find.byKey(Key(card)),
                matching: find.byType(RangeSlider),
              )
              .at(onWords ? 0 : 1),
        );
        double x(int lesson) => cardRect.left + scales[card]!.x(lesson);
        final paintTop =
            tester
                .getRect(
                  find
                      .descendant(
                        of: find.byKey(Key(card)),
                        matching: find.byType(RangeSlider),
                      )
                      .first,
                )
                .top -
            52;

        // Inwards in small steps, so the drag stays inside the book.
        final gesture = await tester.startGesture(
          Offset(x(grab), slider.center.dy),
        );
        var fx = x(grab);
        while (fx > x(to)) {
          fx = max(fx - 2, x(to));
          await gesture.moveTo(Offset(fx, slider.center.dy));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(Key(card)),
            matching: find.textContaining(expected, findRichText: true),
          ),
          findsOneWidget,
        );

        if (!onWords) {
          expect(scales[card]!.widths[0], lessThan(scales[card]!.widths[1]));
        }
        final [start, end] = labels[card]!;
        expect(start.overlaps(end), isFalse, reason: '$start $end');
        final scale = scales[card]!;
        final (from, upTo) = onWords ? (25, 26) : (1, 2);
        for (final r in [start, end]) {
          expect(
            r.left >= 0 && r.right <= cardRect.width,
            isTrue,
            reason: '$r leaves the card',
          );
          expect(
            r.center.dy,
            moreOrLessEquals(slider.center.dy - paintTop, epsilon: 0.5),
            reason: 'label not at thumb height',
          );
          for (final l in [from, upTo]) {
            final thumb = Rect.fromCircle(
              center: Offset(scale.x(l), r.center.dy),
              radius: 10,
            );
            expect(r.overlaps(thumb), isFalse, reason: '$r covers $thumb');
          }
        }
        if (onWords) {
          // Open book, nothing flips: each label sits just outside its thumb.
          expect(
            start.right,
            moreOrLessEquals(scale.x(from) - 14, epsilon: 0.5),
          );
          expect(end.left, moreOrLessEquals(scale.x(upTo) + 14, epsilon: 0.5));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(labels[card], isEmpty);
        await tester.pump(const Duration(seconds: 4));
      });
    }
  }
}
