// The painted pages of a book stand on the page edges of its scale, so the
// squeezed lessons after the Kursstand are what the learner sees; each
// ribbon hangs at the x of its lesson and each bow is tied there.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/theme.dart';
import 'package:latin_practice/widgets/kursstand_shelf.dart';

import 'support/gen_settings.dart';

/// Records the x of every vertical line, every untranslated path with its
/// colour, and the origin of every rounded rect drawn around it.
class _Recorder implements Canvas {
  final xs = <double>[];
  final paths = <(Color, Rect)>[];
  final knots = <Offset>[];
  final _origins = [Offset.zero];

  @override
  void drawLine(Offset a, Offset b, Paint paint) {
    if (a.dx == b.dx) xs.add(a.dx);
  }

  @override
  void save() => _origins.add(_origins.last);

  @override
  void restore() => _origins.removeLast();

  @override
  void translate(double dx, double dy) =>
      _origins.last = _origins.last + Offset(dx, dy);

  @override
  void drawPath(Path path, Paint paint) {
    if (_origins.last == Offset.zero) {
      paths.add((paint.color, path.getBounds()));
    }
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    if (rrect.center == Offset.zero) knots.add(_origins.last);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

typedef _Shelf = ({
  BookScaleCase scale,
  LessonRange words,
  LessonRange grammar,
  bool tiedFrom,
  bool tiedTo,
});

/// The ribbon of the bound at [lesson] in [colour]: upright in an open book,
/// so centred on the lesson; tilted in a nearly closed one, so only its end
/// is on the lesson.
void _expectRibbon(
  _Recorder canvas,
  BookScale scale,
  int lesson,
  Color colour,
  double end,
  String why,
) {
  final x = scale.x(lesson);
  final book = scale.bookOf(lesson);
  final upright = book == scale.bookStarts.length || 4 * scale.fan(book) >= 1;
  final ribbons = [
    for (final (c, r) in canvas.paths)
      if (c.toARGB32() == colour.toARGB32()) r,
  ];
  expect(
    ribbons.any(
      (r) =>
          r.contains(Offset(x, end - 1)) &&
          // A path keeps its points in single precision.
          (!upright || (r.center.dx - x).abs() < 1e-3),
    ),
    isTrue,
    reason:
        '$why: a ${upright ? 'centred' : 'tilted'} ribbon at L$lesson '
        '(x $x, end $end) among $ribbons',
  );
}

void _check(_Shelf shelf, String why) {
  final c = shelf.scale;
  final scale = BookScale(
    c.starts,
    c.expansion,
    c.left,
    c.width,
    kursstand: c.kursstand,
  );
  final canvas = _Recorder();
  ShelfPainter(
    scale: scale,
    words: shelf.words,
    grammar: shelf.grammar,
    tiedFrom: shelf.tiedFrom,
    tiedTo: shelf.tiedTo,
    names: ShelfNames([
      for (var b = 0; b <= c.starts.length; b++) 'b$b',
    ], const TextStyle()),
  ).paint(canvas, Size(2 * c.left + c.width, shelfHeight));
  for (var b = 0; b < c.starts.length; b++) {
    for (final e in scale.pageEdges(b)) {
      expect(
        canvas.xs.any((x) => (x - e).abs() < 1e-6),
        isTrue,
        reason: '$why, book ${b + 1}: a page line at $e',
      );
    }
  }
  for (final l in [shelf.grammar.from, shelf.grammar.to]) {
    _expectRibbon(
      canvas,
      scale,
      l,
      terracotta,
      shelfGrammarEnd(scale, l),
      '$why, grammar',
    );
  }
  for (final (l, tied) in [
    (shelf.words.from, shelf.tiedFrom),
    (shelf.words.to, shelf.tiedTo),
  ]) {
    _expectRibbon(
      canvas,
      scale,
      l,
      gold,
      shelfGoldEnd(scale, l, tied: tied),
      '$why, words',
    );
  }
  final bows = [
    if (shelf.tiedFrom) shelf.words.from,
    if (shelf.tiedTo) shelf.words.to,
  ];
  expect(
    {for (final k in canvas.knots) k.dx},
    {for (final l in bows) scale.x(l)},
    reason: '$why: a bow at the x of each tied word bound, no other',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the painted page lines, ribbons and bows lie on the scale', () {
    final fixed = <_Shelf>[
      for (final k in [5, 12, 24])
        (
          scale: (
            starts: const [1, 21],
            expansion: const [1.0, 1.0],
            left: 24.0,
            width: 240.0,
            kursstand: k,
          ),
          words: LessonRange(1, k),
          grammar: LessonRange(1, k),
          tiedFrom: true,
          tiedTo: true,
        ),
    ];
    for (final (i, s) in fixed.indexed) {
      _check(s, 'fixed $i: Kursstand ${s.scale.kursstand}');
    }
    final rng = Random(3514);
    for (var i = 0; i < 1000; i++) {
      final settings = drawSettings(rng);
      final s = (
        scale: drawBookScaleCase(rng),
        words: settings.courseWords,
        grammar: settings.courseGrammar,
        tiedFrom: settings.grammarFromLinked,
        tiedTo: settings.grammarToLinked,
      );
      _check(s, 'case $i: $s');
    }
  });
}
