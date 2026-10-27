// Property: during any drag on the book scale, every chain end stays on the
// centre of its thumb, in every frame, also while books change width. Thumb centres come from the rendered pixels, the
// chain ends from what the chain painter drew.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

import '../support/preloaded_i18n.dart';

const _cases = int.fromEnvironment('CASES', defaultValue: 40);
const _seed = int.fromEnvironment('SEED', defaultValue: 1);
const _debug = bool.fromEnvironment('DEBUG');
const _width = 366.0, _dpr = 2.0;
const _wordsY = 76.0, _later = 101;

bool _isColor(ByteData rgba, int i, Color c) =>
    (rgba.getUint8(i) - c.r * 255).abs() +
        (rgba.getUint8(i + 1) - c.g * 255).abs() +
        (rgba.getUint8(i + 2) - c.b * 255).abs() <
    60;

/// The ends of the leftmost and rightmost ribbon at height [y]: their outer
/// edges in the rows [y] + o1 and [y] + o2, extended to [y] in a straight
/// line, moved inwards by half a ribbon's width along that row.
(double, double) _ribbonEnds(
  ByteData rgba,
  int stride,
  double y,
  (double, double) rows,
  Color c,
) {
  (double, double) edges(double o) {
    final row = ((y + o) * _dpr).round();
    final hits = [
      for (var x = 0; x < stride; x++)
        if (_isColor(rgba, (row * stride + x) * 4, c)) x,
    ];
    expect(hits, isNotEmpty, reason: 'no ribbon pixels in row $row');
    return (hits.first / _dpr, (hits.last + 1) / _dpr);
  }

  final (o1, o2) = rows;
  final (l1, r1) = edges(o1);
  final (l2, r2) = edges(o2);
  double end(double e1, double e2, double inwards) {
    final slope = (e2 - e1) / (o2 - o1);
    return e1 - slope * o1 + inwards * 5 * sqrt(1 + slope * slope);
  }

  return (end(l1, l2, 1), end(r1, r2, -1));
}

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

Future<void> _loadIcons() async {
  final loader = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await loader.load();
}

late final LocalizationsDelegate<FlutterI18n> _i18n;

void main() {
  setUpAll(() async => _i18n = await preloadedI18n());
  setUpAll(_loadIcons);

  for (final shelf in [false, true]) {
    final grammarY = shelf ? 124.0 : 140.0;
    testWidgets('chain ends stay on their thumbs during random drags'
        '${shelf ? ' (shelf)' : ''}', (tester) async {
      tester.view.physicalSize = const Size(_width * _dpr, 400 * _dpr);
      tester.view.devicePixelRatio = _dpr;
      addTearDown(tester.view.reset);
      final boundaryKey = GlobalKey();
      var strict = 0, loose = 0;

      for (var n = 0; n < _cases; n++) {
        final seed = _seed * 1000 + n;
        final rnd = Random(seed);
        int lesson() => 1 + rnd.nextInt(_later);
        ({int from, int to}) range() {
          final a = lesson(), b = lesson();
          return (from: min(a, b), to: max(a, b));
        }

        final words = range();
        final left = rnd.nextBool(), right = rnd.nextBool();
        final g = range();
        final gFrom = left ? words.from : g.from;
        final gTo = right ? words.to : g.to;
        if (gFrom > gTo) continue;
        final grammar = (from: gFrom, to: gTo);
        final log = <String>[
          'seed $seed: words $words grammar $grammar links $left/$right',
        ];
        var ends = <(Offset, Offset)>[];
        late BookScale scale;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: [_i18n],
            // The outline the slider draws around overlapping thumbs would
            // eat into the thumb pixels the oracle measures.
            theme: romanTheme.copyWith(
              sliderTheme: romanTheme.sliderTheme.copyWith(
                overlappingShapeStrokeColor: Colors.transparent,
              ),
            ),
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: _width,
                    child: BookSliders(
                      key: ValueKey(seed),
                      focus: BookFocus.idle,
                      words: words,
                      grammar: grammar,
                      links: (left: left, right: right),
                      shelf: shelf,
                      onScale: (s) => scale = s,
                      onPaintChains: (e) => ends = e,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Future<void> check() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final (rgba, stride) = (await tester.runAsync(() async {
            final ui.Image image = await boundary.toImage(pixelRatio: _dpr);
            final data = await image.toByteData();
            if (_debug) {
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                '${Platform.environment['FRAME_DIR']}/frame.png',
              ).writeAsBytesSync(png!.buffer.asUint8List());
            }
            return (data!, image.width);
          }))!;
          // Word ribbons end above their chain end, grammar ribbons hang
          // below it; the rows keep clear of the chain's round caps.
          final (wFrom, wTo) = shelf
              ? _ribbonEnds(rgba, stride, _wordsY, (-4, -9), gold)
              : _thumbCentres(rgba, stride, _wordsY, -6, gold);
          final (gFrom, gTo) = shelf
              ? _ribbonEnds(rgba, stride, grammarY, (4, 9), terracotta)
              : _thumbCentres(rgba, stride, grammarY, 6, terracotta);
          final expected = [(wFrom, gFrom), (wTo, gTo)];
          // Where a slider's two thumbs overlap, the shadow of the upper one
          // hides the edge of the lower one, so the pixels say less there.
          // Tilted ribbons in a closed book may cross above their ends.
          double tolerance(double from, double to) {
            final overlap = to - from < (shelf ? 20 : 2 * 10 + 2);
            overlap ? loose++ : strict++;
            return overlap ? 3 : 1;
          }

          final wTol = tolerance(wFrom, wTo), gTol = tolerance(gFrom, gTo);
          for (var i = 0; i < 2; i++) {
            final (a, b) = ends[i];
            final (wx, gx) = expected[i];
            final where =
                '${log.join('\n')}\nchain $i: word end ${a.dx} '
                'thumb $wx, grammar end ${b.dx} thumb $gx';
            expect((a.dx - wx).abs(), lessThanOrEqualTo(wTol), reason: where);
            expect((b.dx - gx).abs(), lessThanOrEqualTo(gTol), reason: where);
          }
        }

        final state = (words: words, grammar: grammar);
        for (var drag = 0; drag < 1 + rnd.nextInt(3); drag++) {
          final onWords = rnd.nextBool(), start = rnd.nextBool();
          final r = onWords ? state.words : state.grammar;
          // Thumbs drift during earlier drags; grabbing a thumb is not under
          // test, so a miss just drags the nearer one.
          final x = scale.x(start ? r.from : r.to);
          final gesture = await tester.startGesture(
            Offset(x, onWords ? _wordsY : grammarY),
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
      await tester.pump(const Duration(seconds: 4));
      debugPrint('frames checked within 1 px: $strict, within 3 px: $loose');
      expect(strict, greaterThan(3 * loose), reason: 'too few strict checks');
    });
  }
}
