// Property: during any drag on the book scale, every chain end stays on the
// centre of its thumb and every chain bends at its symbol's tap target, in
// every frame, also while books change width. Thumb centres come from the
// rendered pixels, the chain ends and bends from what the chain painter drew.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/theme.dart';

import 'support/app_fonts.dart';
import 'support/kursstand_sliders_harness.dart';

const _cases = int.fromEnvironment('CASES', defaultValue: 40);
const _seed = int.fromEnvironment('SEED', defaultValue: 1);
const _width = 366.0, _dpr = 2.0;

bool _isColor(ByteData rgba, int i, Color c) =>
    (rgba.getUint8(i) - c.r * 255).abs() +
        (rgba.getUint8(i + 1) - c.g * 255).abs() +
        (rgba.getUint8(i + 2) - c.b * 255).abs() <
    60;

/// The centres of the leftmost and rightmost thumb, from the thumb-coloured
/// pixels in the row [dy] off the track centre. The row must miss the track
/// and the chain stubs, which leave the circles towards the other slider.
(double, double) _thumbCentres(
  ByteData rgba,
  int stride,
  double y,
  double dy,
  Color c,
) {
  final row = ((y + dy) * _dpr).round();
  final hits = [
    for (var x = 0; x < stride; x++)
      if (_isColor(rgba, (row * stride + x) * 4, c)) x,
  ];
  expect(hits, isNotEmpty, reason: 'no thumb pixels in row $row');
  final half = sqrt(10 * 10 - dy * dy);
  final left = hits.first / _dpr, right = (hits.last + 1) / _dpr;
  return (left + half, right - half);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('chain ends stay on their thumbs during random drags', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(_width * _dpr, 600 * _dpr);
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    var strict = 0, loose = 0;

    for (var n = 0; n < _cases; n++) {
      final seed = _seed * 1000 + n;
      final rnd = Random(seed);
      int lesson() => 1 + rnd.nextInt(laterLesson);
      LessonRange range() {
        final a = lesson(), b = lesson();
        return LessonRange(min(a, b), max(a, b));
      }

      final words = range(), grammar = range();
      final left = rnd.nextBool(), right = rnd.nextBool();
      final log = <String>[
        'seed $seed: words $words grammar $grammar links $left/$right',
      ];
      final probe = await pumpSliders(
        tester,
        words: words,
        grammar: grammar,
        from: left,
        to: right,
        // The outline the slider draws around overlapping thumbs would eat
        // into the thumb pixels the oracle measures.
        theme: romanTheme.copyWith(
          sliderTheme: romanTheme.sliderTheme.copyWith(
            overlappingShapeStrokeColor: Colors.transparent,
          ),
        ),
        boundary: boundaryKey,
        width: _width,
      );
      final origin = probe.origin(tester);
      final wordsY = probe.y(tester, words: true);
      final grammarY = probe.y(tester, words: false);

      Future<void> check() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final (rgba, stride) = (await tester.runAsync(() async {
          final ui.Image image = await boundary.toImage(pixelRatio: _dpr);
          final data = await image.toByteData();
          return (data!, image.width);
        }))!;
        final (wFrom, wTo) = _thumbCentres(rgba, stride, wordsY, -6, gold);
        final (gFrom, gTo) = _thumbCentres(
          rgba,
          stride,
          grammarY,
          6,
          terracotta,
        );
        final expected = [(wFrom, gFrom), (wTo, gTo)];
        // Where a slider's two thumbs overlap, the shadow of the upper one
        // hides the edge of the lower one, so the pixels say less there.
        double tolerance(double from, double to) {
          final overlap = to - from < 2 * 10 + 2;
          overlap ? loose++ : strict++;
          return overlap ? 3 : 1;
        }

        final wTol = tolerance(wFrom, wTo), gTol = tolerance(gFrom, gTo);
        for (var i = 0; i < 2; i++) {
          final (a, symbol, b) = probe.chains[i];
          final (wx, gx) = expected[i];
          final target = tester.getCenter(
            find.byKey(Key('kursstand.chain.${i == 0 ? 'left' : 'right'}')),
          );
          final where =
              '${log.join('\n')}\nchain $i: word end ${a.dx} '
              'thumb $wx, grammar end ${b.dx} thumb $gx, bend $symbol '
              'target ${target - origin}';
          expect((a.dx - wx).abs(), lessThanOrEqualTo(wTol), reason: where);
          expect((b.dx - gx).abs(), lessThanOrEqualTo(gTol), reason: where);
          expect(
            (target - origin - symbol).distance,
            lessThanOrEqualTo(0.5),
            reason: where,
          );
        }
      }

      for (var drag = 0; drag < 1 + rnd.nextInt(3); drag++) {
        final onWords = rnd.nextBool(), start = rnd.nextBool();
        final r = onWords
            ? probe.settings.courseWords
            : probe.settings.courseGrammar;
        // Thumbs drift during earlier drags; grabbing a thumb is not under
        // test, so a miss just drags the nearer one.
        final x = probe.scale.x(start ? r.from : r.to);
        final gesture = await tester.startGesture(
          origin + Offset(x, onWords ? wordsY : grammarY),
        );
        log.add(
          'down ${onWords ? 'words' : 'grammar'} ${start ? 'from' : 'to'} x=$x',
        );
        final steps = 5 + rnd.nextInt(40);
        for (var s = 0; s < steps; s++) {
          for (var m = rnd.nextInt(4); m > 0; m--) {
            final dx = switch (rnd.nextInt(3)) {
              0 => rnd.nextDouble() * 2 - 1,
              1 => (rnd.nextDouble() * 4 - 2) * 7.8,
              _ => (rnd.nextDouble() * 30 - 15) * 7.8,
            };
            await gesture.moveBy(Offset(dx, 0));
            log.add('move $dx');
          }
          final ms = rnd.nextInt(41);
          await tester.pump(Duration(milliseconds: ms));
          log.add('pump $ms');
          await check();
        }
        await gesture.up();
        log.add('up');
        for (var f = 0; f < 10; f++) {
          await tester.pump(const Duration(milliseconds: 16));
          await check();
        }
      }
    }
    debugPrint('frames checked within 1 px: $strict, within 3 px: $loose');
    // Few stops per book bring a slider's thumbs together often.
    expect(strict, greaterThan(1.5 * loose), reason: 'too few strict checks');
  });
}
