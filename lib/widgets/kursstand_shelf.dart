import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/lesson_range.dart';
import '../theme.dart';

/// The width of a closed book and of "Später".
const _squeezed = 22.0;

/// The space left and right of the books, so ribbons at the ends stay in the
/// card.
const shelfInset = 24.0;

/// The heights the ribbon ends of the word and the grammar bounds hang at
/// without bows; drags and screen-reader steps act on these rows.
const shelfWordsY = 76.0, shelfRowHeight = 48.0;
const shelfGrammarY = shelfWordsY + shelfRowHeight;
const shelfHeight = shelfGrammarY + shelfRowHeight / 2 + 10;

/// The top of the front edge of a closed book.
const shelfPageTop = 46.0;

/// The shelf lies just above the grammar ribbons' tails, so they hang over
/// its edge.
const _shelfY = shelfGrammarY + 6;

/// The covers stand in one line this far behind the shelf edge, so the
/// fanned pages of an open book can come forward.
const _coverLine = _shelfY - 12;

/// The length of a page from the spine at the back to its front edge, at
/// least [_pageShare] of its book's width so a wide book's covers turn no
/// more than about 50°.
const _pageLength = 136.0, _pageShare = 0.65;

/// How much of a depth step shows as a height step, seen from about 13°
/// above (sin 13° ≈ 0.22).
const _viewSquash = 0.22;

/// How deep the top of a closed book's pages shows.
const _closedTop = 5.0;

/// The hard cover boards: their thickness and how far they stand above the
/// pages.
const _board = 2.5, _boardOverhang = 2.5;

const _ribbonHalf = 5.0;

/// How far the swallowtail cuts into a word ribbon's end, and how far a
/// grammar ribbon hangs below its end.
const _goldNotch = 4.0, shelfGrammarTail = 14.0;

const _cover = Color(0xFF4A3426);

/// The book of [lesson] among books starting at [bookStarts], 0-based;
/// `bookStarts.length` is "Später".
int bookIndex(List<int> bookStarts, int lesson) => lesson == laterLesson
    ? bookStarts.length
    : bookStarts.lastIndexWhere((s) => s <= lesson);

/// The widest a book opens per lesson, so a wide window shows books, not a
/// fan of pages.
const shelfMaxCell = 14.0;

/// Lesson ↔ x on a track where book b is [_squeezed] wide plus its share,
/// by its expansion in 0..1, of what the squeezed books leave free, up to
/// [shelfMaxCell] per lesson. Room a full book cannot take goes to the
/// others, then to the closed ones by their lessons; what is left centres
/// the row. "Später" is a squeezed segment after the last book.
class BookScale {
  BookScale(this.bookStarts, List<double> expansion, this.left, double width) {
    assert(bookStarts.first == 1, 'the first book starts at lesson 1');
    assert(expansion.length == bookStarts.length);
    final free = width - (bookStarts.length + 1) * _squeezed;
    assert(free > 0, 'the track is too short for the books');
    final room = [
      for (var b = 0; b < bookStarts.length; b++)
        min(free, lessonsIn(b) * shelfMaxCell - _squeezed),
    ];
    final extra = [for (final _ in expansion) 0.0];
    final open = {for (var b = 0; b < expansion.length; b++) b};
    var rest = free;
    while (rest > 1e-9 && open.isNotEmpty) {
      final weighted = open.where((b) => expansion[b] > 0);
      // Closed books share what the opened ones cannot take by their lessons.
      double share(int b) => weighted.isEmpty
          ? lessonsIn(b).toDouble()
          : (expansion[b] > 0 ? expansion[b] : 0.0);
      final sum = open.map(share).fold(0.0, (a, s) => a + s);
      final full = open
          .where((b) => extra[b] + rest * share(b) / sum >= room[b])
          .toList();
      if (full.isEmpty) {
        for (final b in open) {
          extra[b] += rest * share(b) / sum;
        }
        rest = 0;
      }
      for (final b in full) {
        rest -= room[b] - extra[b];
        extra[b] = room[b];
        open.remove(b);
      }
    }
    var x = left + rest / 2;
    for (final e in [...extra, 0.0]) {
      starts.add(x);
      widths.add(_squeezed + e);
      x += widths.last;
    }
    _room = room;
  }

  final List<int> bookStarts;

  /// The left end of the track.
  final double left;
  final starts = <double>[], widths = <double>[];
  late final List<double> _room;

  int bookOf(int lesson) => bookIndex(bookStarts, lesson);

  int lessonsIn(int book) =>
      (book + 1 < bookStarts.length ? bookStarts[book + 1] : laterLesson) -
      bookStarts[book];

  /// 0 for a closed book, 1 for one as wide as it can open on this track.
  double fan(int book) => (widths[book] - _squeezed) / _room[book];

  double cell(int lesson) {
    final b = bookOf(lesson);
    return lesson == laterLesson ? _squeezed : widths[b] / lessonsIn(b);
  }

  double x(int lesson) {
    final b = bookOf(lesson);
    if (lesson == laterLesson) return starts[b] + _squeezed / 2;
    return starts[b] + (lesson - bookStarts[b] + 0.5) * cell(lesson);
  }

  int lessonAt(double x) {
    var b = 0;
    while (b < bookStarts.length && x >= starts[b] + widths[b]) {
      b++;
    }
    if (b == bookStarts.length) return laterLesson;
    final i = ((x - starts[b]) / widths[b] * lessonsIn(b)).floor();
    return bookStarts[b] + i.clamp(0, lessonsIn(b) - 1);
  }
}

/// Book [index] of [scale], standing on the shelf with its spine at the
/// back. Its pages turn about the spine: page i stands at angle θ with
/// sin θ = (x − centre) / [_pageLength], so its front edge keeps the x of
/// the scale. The covers turn furthest and stay in line with the closed
/// books; the pages between them reach forward and so, seen from above,
/// stand lower.
class _ShelfBook {
  _ShelfBook(BookScale scale, this.index)
    : later = index == scale.bookStarts.length,
      left = scale.starts[index],
      width = scale.widths[index],
      fan = index == scale.bookStarts.length ? 0 : scale.fan(index);

  final int index;

  /// Whether this is "Später" after the last book.
  final bool later;
  final double left, width;

  final double fan;

  double get centre => left + width / 2;

  /// How far the page at [x] stands in front of the covers, shown as height.
  double _forward(double x) {
    final length = max(_pageLength, width * _pageShare);
    double back(double x) => length * cos(asin((x - centre) / length));
    return _viewSquash * (back(x) - back(left));
  }

  /// The top of the page's front edge at [x].
  Offset top(double x) => Offset(x, shelfPageTop + _forward(x));

  Offset bottom(double x) => Offset(x, _coverLine + _forward(x));

  /// The unit direction of the page tops at [x], left to right.
  Offset slope(double x) {
    final d = top(min(x + 0.5, left + width)) - top(max(x - 0.5, left));
    return d / d.distance;
  }

  double get spineY => shelfPageTop - _closedTop;

  /// Where the top of the page at [x] meets the spine. The spine keeps the
  /// closed book's thickness however far the pages fan out.
  Offset spine(double x) =>
      Offset(centre + (x - centre) * _squeezed / width, spineY);

  /// The head of the spine at the back, between the cover boards.
  Rect get spineHead => Rect.fromLTRB(
    centre - _squeezed / 2,
    spineY - 2 * _boardOverhang,
    centre + _squeezed / 2,
    spineY,
  );
}

/// The knot of a bow at [lesson], halfway down its page and turned with the
/// page tops there.
(Offset, double) shelfBowAt(BookScale scale, int lesson) {
  final book = _ShelfBook(scale, scale.bookOf(lesson));
  final x = scale.x(lesson);
  return (
    Offset.lerp(book.top(x), book.bottom(x), 0.5)!,
    book.slope(x).direction,
  );
}

/// Where a word ribbon ends: in its bow, or else just above the bottom of
/// its book.
double shelfGoldEnd(BookScale scale, int lesson, {required bool tied}) => tied
    ? shelfBowAt(scale, lesson).$1.dy
    : _ShelfBook(scale, scale.bookOf(lesson)).bottom(scale.x(lesson)).dy - 6;

/// Where a grammar ribbon's end sits; its tail hangs over the shelf edge.
double shelfGrammarEnd(BookScale scale, int lesson) =>
    _ShelfBook(scale, scale.bookOf(lesson)).bottom(scale.x(lesson)).dy +
    shelfGrammarY -
    _coverLine;

/// The name of each book and then of "Später", laid out once per colour.
class ShelfNames {
  ShelfNames(this.texts, this.font);

  final List<String> texts;
  final TextStyle font;
  final _painters = <(int, bool), TextPainter>{};

  TextPainter painter(int index, {required bool open}) =>
      _painters.putIfAbsent((index, open), () {
        final text = TextPainter(
          text: TextSpan(
            text: texts[index],
            style: font.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: open ? ink : mutedText,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        assert(
          text.width <= _coverLine - shelfPageTop,
          '"${texts[index]}" is too long for the front of a book',
        );
        return text;
      });

  int get length => texts.length;

  bool shows(List<String> texts, TextStyle font) =>
      listEquals(texts, this.texts) && font == this.font;

  void dispose() {
    for (final p in _painters.values) {
      p.dispose();
    }
  }
}

/// The books in one row on a shelf, on [scale], with a gold bookmark ribbon
/// at each word bound and a terracotta one at each grammar bound. A bow ties
/// the two ribbons of a linked bound.
class ShelfPainter extends CustomPainter {
  ShelfPainter({
    required this.scale,
    required this.words,
    required this.grammar,
    required this.tiedFrom,
    required this.tiedTo,
    required this.names,
    this.onPaint,
  }) : assert(names.length == scale.bookStarts.length + 1);

  final BookScale scale;
  final LessonRange words, grammar;
  final bool tiedFrom, tiedTo;

  final ShelfNames names;

  /// Reports the top of the pages of each lesson 1 to "Später" and the spine
  /// of each book.
  final void Function(List<Offset> tops, List<Rect> spines)? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final books = [
      for (var b = 0; b <= scale.bookStarts.length; b++) _ShelfBook(scale, b),
    ];
    canvas
      ..drawRect(
        Rect.fromLTRB(0, _coverLine - 10, size.width, _shelfY),
        Paint()..color = Color.lerp(sand, outlineColor, 0.35)!,
      )
      ..drawRect(
        Rect.fromLTRB(0, _shelfY, size.width, _shelfY + 4),
        Paint()..color = outlineColor,
      )
      ..drawLine(
        const Offset(0, _shelfY),
        Offset(size.width, _shelfY),
        Paint()
          ..color = _cover
          ..strokeWidth = 1.5,
      );
    for (final book in books) {
      _book(canvas, book);
    }
    for (final book in books) {
      _name(canvas, book);
    }
    for (final (l, c, y) in [
      (grammar.from, terracotta, shelfGrammarEnd(scale, grammar.from)),
      (grammar.to, terracotta, shelfGrammarEnd(scale, grammar.to)),
      (words.from, gold, shelfGoldEnd(scale, words.from, tied: tiedFrom)),
      (words.to, gold, shelfGoldEnd(scale, words.to, tied: tiedTo)),
    ]) {
      _ribbon(canvas, books[scale.bookOf(l)], scale.x(l), y, c);
    }
    if (tiedFrom) _bow(canvas, shelfBowAt(scale, words.from));
    if (tiedTo) _bow(canvas, shelfBowAt(scale, words.to));
    onPaint?.call(
      [
        for (var l = 1; l <= laterLesson; l++)
          books[scale.bookOf(l)].top(scale.x(l)),
      ],
      [for (final book in books) book.spineHead],
    );
  }

  void _book(Canvas canvas, _ShelfBook book) {
    final pages = book.later ? 8 : scale.lessonsIn(book.index);
    final edges = [
      for (var k = 0; k <= pages; k++) book.left + k * book.width / pages,
    ];
    final cell = book.width / pages;
    final perCell = cell > 6 ? 4 : 1;
    final lines = [
      for (var k = 0; k <= pages * perCell; k++) book.left + k * cell / perCell,
    ];
    final line = Paint()
      ..color = outlineColor.withAlpha(150)
      ..strokeWidth = 0.6;
    // The tops of the pages, seen from above, run back to the spine.
    canvas.drawPath(
      Path()..addPolygon([
        for (final x in edges) book.top(x),
        for (final x in edges.reversed) book.spine(x),
      ], true),
      Paint()..color = Color.lerp(parchment, Colors.white, 0.5)!,
    );
    for (final x in lines) {
      canvas.drawLine(book.top(x), book.spine(x), line);
    }
    for (var k = 0; k < pages; k++) {
      final (a, b) = (edges[k], edges[k + 1]);
      canvas.drawPath(
        Path()..addPolygon([
          book.top(a),
          book.top(b),
          book.bottom(b),
          book.bottom(a),
        ], true),
        Paint()
          ..color = book.later
              ? sand
              : (k.isEven ? parchment : Color.lerp(parchment, sand, 0.6)!),
      );
    }
    for (final x in lines) {
      canvas.drawLine(book.top(x), book.bottom(x), line);
    }
    final front = Paint()..color = book.later ? outlineColor : _cover;
    final edge = Paint()
      ..color = Color.lerp(book.later ? outlineColor : _cover, sand, 0.35)!;
    const up = Offset(0, _boardOverhang);
    for (final (outer, inner) in [
      (book.left, book.left + _board),
      (book.left + book.width, book.left + book.width - _board),
    ]) {
      final corner = book.top(outer) - up, back = book.spine(outer) - up;
      final d = back - corner;
      var n = Offset(-d.dy, d.dx) / d.distance * _board;
      if (n.dx * (inner - outer) +
              n.dy * (book.top(book.centre).dy - corner.dy) <
          0) {
        n = -n;
      }
      canvas
        ..drawPath(
          Path()..addPolygon([corner, back, back + n, corner + n], true),
          edge,
        )
        ..drawPath(
          Path()..addPolygon([
            corner,
            book.top(inner) - up,
            book.bottom(inner),
            book.bottom(outer),
          ], true),
          front,
        );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(book.spineHead, const Radius.circular(2)),
      front,
    );
  }

  /// A bow tied from both ribbons: each makes one loop and the opposite
  /// tail.
  void _bow(Canvas canvas, (Offset, double) pose) {
    final (centre, angle) = pose;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(angle);
    Paint fill(Color c) => Paint()..color = c;
    Paint rim(Color c) => Paint()
      ..color = Color.lerp(c, ink, 0.45)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (side, c) in [(-1.0, terracotta), (1.0, gold)]) {
      final tail = Path()
        ..addPolygon([
          Offset(-2.5 * side, 2),
          Offset(2.5 * side, 2),
          Offset(9 * side, 16),
          Offset(6 * side, 15),
          Offset(3 * side, 17),
        ], true);
      canvas
        ..drawPath(tail, fill(c))
        ..drawPath(tail, rim(c));
    }
    for (final (side, c) in [(-1.0, gold), (1.0, terracotta)]) {
      final loop = Path()
        ..moveTo(3 * side, -2)
        ..cubicTo(10 * side, -13, 19 * side, -10, 18 * side, -1)
        ..cubicTo(17 * side, 6, 9 * side, 6, 3 * side, 2)
        ..close();
      canvas
        ..drawPath(loop, fill(c))
        ..drawPath(loop, rim(c));
    }
    final knot = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 8, height: 9),
      const Radius.circular(2.5),
    );
    canvas
      ..drawRRect(knot, fill(gold))
      ..drawRRect(knot, rim(gold))
      ..restore();
  }

  /// The book's name on the front of its pages, read from bottom to top.
  void _name(Canvas canvas, _ShelfBook book) {
    final text = names.painter(book.index, open: book.fan > 0.5);
    final mid = Offset.lerp(
      book.top(book.centre),
      book.bottom(book.centre),
      0.5,
    )!;
    canvas
      ..save()
      ..translate(mid.dx, mid.dy)
      ..rotate(-pi / 2);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  /// A ribbon from the spine along the top of the page at [x], folded over
  /// its front edge and hanging straight down to its end ([x], [y]). The
  /// fold follows the page tops, so the ribbon turns with its pages. In a
  /// closed book it sticks out of the page edge, tilted.
  void _ribbon(Canvas canvas, _ShelfBook book, double x, double y, Color c) {
    final end = Offset(x, y);
    final inwards = x < book.centre ? 1.0 : -1.0;
    final slot = Offset(
      (x + 12 * inwards).clamp(book.left + 3, book.left + book.width - 3),
      y - 30,
    );
    final along = book.slope(x) * _ribbonHalf;
    // Only a nearly closed book tilts its ribbon; "Später" never does.
    final upright = book.later ? 1.0 : min(1.0, 4 * book.fan);
    final back = Offset.lerp(slot, book.spine(x), upright)!;
    final kink = Offset.lerp(slot, book.top(x), upright)!;
    final shade = Color.lerp(c, ink, 0.35)!;
    if ((kink - back).distance > 0.5) {
      const narrow = Offset(_ribbonHalf * 0.6, 0);
      canvas.drawPath(
        Path()..addPolygon([
          kink - along,
          kink + along,
          back + narrow,
          back - narrow,
        ], true),
        Paint()..color = shade,
      );
    }
    final d = (end - kink) / (end - kink).distance;
    final n = Offset(-d.dy, d.dx) * _ribbonHalf;
    final e = Offset.lerp(n, -along, upright)!;
    final tip = c == gold ? end + d * _goldNotch : end + d * shelfGrammarTail;
    final fold = d * 3 * upright;
    canvas
      ..drawPath(
        Path()..addPolygon([
          kink - e - fold,
          kink + e - fold,
          kink - e + fold,
        ], true),
        Paint()..color = shade,
      )
      ..drawPath(
        Path()..addPolygon([
          kink - e + fold,
          kink + e - fold,
          tip + e,
          tip - d * _goldNotch,
          tip - e,
        ], true),
        Paint()..color = c,
      );
    if (upright < 1) {
      canvas.drawLine(
        kink - n * 1.3,
        kink + n * 1.3,
        Paint()
          ..color = _cover.withValues(alpha: 1 - upright)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(ShelfPainter old) => true;
}
