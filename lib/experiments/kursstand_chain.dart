import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../theme.dart';
import 'experiment.dart';

/// The Kursstand sliders: two chains between word and grammar slider, on a
/// lesson scale that squeezes books.
///
/// `--dart-define=VARIANT=n` opens on the n-th variant (1-based),
/// `--dart-define=FIRST_STATE=n` starts the list at the n-th state card,
/// `--dart-define=PHONE_WIDTH=390` narrows the content to a phone.
void main() {
  final variants = kursstandVariants();
  const first = int.fromEnvironment('VARIANT', defaultValue: 1) - 1;
  final names = variants.keys.toList();
  runExperiment('Kursstand: zwei Ketten', {
    for (final n in [...names.skip(first), ...names.take(first)])
      n: variants[n]!,
  });
}

Map<String, Widget> kursstandVariants() => {
  'Buch: Schleife': const _CompleteDemo(shelf: true, bow: true),
  'Buch': const _CompleteDemo(shelf: true),
  'Komplett': const _CompleteDemo(shelf: false),
  'Bücher: Griffe': const BooksDemo(focus: BookFocus.thumbs),
  'Bücher: nur gezogenes': const BooksDemo(focus: BookFocus.dragged),
  'Bücher: schrumpft nach Loslassen': const BooksDemo(
    focus: BookFocus.shrinkAfterRelease,
  ),
  'Bücher: Ruhezeit': const BooksDemo(focus: BookFocus.idle),
  'Bücher: erst nach Loslassen': const BooksDemo(
    focus: BookFocus.draggedOnRelease,
  ),
};

/// The slider theme the geometry assumes; it equals the app's
/// Material-2-style RangeSlider defaults, pinned so the math cannot drift.
const _trackHeight = 4.0;
const _overlayRadius = 24.0;
const _thumbRadius = 10.0;
const _sliderHeight = 2 * _overlayRadius;
const _sliderGap = 16.0;

SliderThemeData _sliderTheme(BuildContext context) =>
    SliderTheme.of(context).copyWith(
      trackHeight: _trackHeight,
      overlayShape: const RoundSliderOverlayShape(
        overlayRadius: _overlayRadius,
      ),
      rangeThumbShape: const RoundRangeSliderThumbShape(
        enabledThumbRadius: _thumbRadius,
      ),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
    );

/// Gives [slider] an overlay of its own size for its value indicator. With
/// the app's overlay, a slider scrolled out of view leaves the indicator's
/// semantics node without a parent, which crashes macOS accessibility.
Widget _ownOverlay(Widget slider) =>
    Overlay.wrap(clipBehavior: Clip.none, child: slider);

/// One tab: an intro line over state cards, narrowed by `PHONE_WIDTH` and
/// started at card `FIRST_STATE`.
Widget _page(String intro, List<Widget> cards) {
  const width = int.fromEnvironment('PHONE_WIDTH');
  const first = int.fromEnvironment('FIRST_STATE', defaultValue: 1) - 1;
  final list = ListView(
    padding: const EdgeInsets.all(12),
    children: [
      Text(intro, style: const TextStyle(color: mutedText, fontSize: 12)),
      ...cards.skip(first),
    ],
  );
  return width == 0
      ? list
      : Center(
          child: SizedBox(width: width.toDouble(), child: list),
        );
}

Widget _card(String title, Widget body) => Card(
  key: Key(title),
  margin: const EdgeInsets.symmetric(vertical: 6),
  child: Padding(
    padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body,
      ],
    ),
  ),
);

Widget _summaryLine(String text, Color color) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Text(
    text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
  ),
);

Widget _summary(String words, String grammar) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Wörter $words',
          style: const TextStyle(color: _wordsText),
        ),
        const TextSpan(text: '  ·  '),
        TextSpan(
          text: 'Grammatik $grammar',
          style: const TextStyle(color: terracottaDark),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  ),
);

class _CompleteDemo extends StatelessWidget {
  const _CompleteDemo({required this.shelf, this.bow = false});

  final bool shelf;
  final bool bow;

  @override
  Widget build(BuildContext context) => _page(
    '${shelf ? 'Lesezeichen ziehen: Gold = Wörter, Terrakotta = Grammatik. ' : ''}'
    'Symbol antippen: Kette öffnen oder schließen. Grammatik-Griff an '
    'geschlossener Kette ziehen: öffnet sie. Buch-Breiten wie „Ruhezeit“.',
    [
      for (final (title, words, grammar, left, right) in [
        ('Beide verbunden', (from: 25, to: 32), (from: 25, to: 32), true, true),
        (
          'Rechts verbunden',
          (from: 25, to: 32),
          (from: 1, to: 32),
          false,
          true,
        ),
        ('Beide offen', (from: 25, to: 32), (from: 1, to: 20), false, false),
        (
          'Wörter bis Später',
          (from: 25, to: _bookLater),
          (from: 1, to: _bookLater),
          false,
          true,
        ),
      ])
        _card(
          title,
          BookSliders(
            focus: BookFocus.idle,
            words: words,
            grammar: grammar,
            links: (left: left, right: right),
            shelf: shelf,
            bow: bow,
          ),
        ),
    ],
  );
}

/// The 44×44 tap target on a chain symbol. A mouse over it gets the click
/// cursor, a ring and a hint below; the hint grows towards [hintRight] so it
/// stays in the card.
class _ChainButton extends StatefulWidget {
  const _ChainButton({
    required this.left,
    required this.linked,
    required this.hintRight,
    required this.onTap,
  });

  final bool left, linked, hintRight;
  final VoidCallback onTap;

  @override
  State<_ChainButton> createState() => _ChainButtonState();
}

class _ChainButtonState extends State<_ChainButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final side = widget.left ? 'left' : 'right';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label: FlutterI18n.translate(
          context,
          'settings.kursstand.${widget.left ? 'chainFrom' : 'chainTo'}'
          '${widget.linked ? 'Linked' : 'Open'}',
        ),
        hint: FlutterI18n.translate(
          context,
          'settings.kursstand.${widget.linked ? 'chainUnlink' : 'chainLink'}',
        ),
        child: GestureDetector(
          key: Key('chain.$side'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_hovered) ...[
                Center(
                  child: Container(
                    key: Key('chain.$side.hover'),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ink.withAlpha(30),
                      border: Border.all(color: ink, width: 2),
                    ),
                  ),
                ),
                Positioned(
                  top: 46,
                  left: widget.hintRight ? 0 : null,
                  right: widget.hintRight ? null : 0,
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.linked ? 'Grenzen trennen' : 'Grenzen verbinden',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _wordsText = Color(0xFF8A6D1A);

const _labelGap = _thumbRadius + 4;

/// How far from a ribbon's middle a finger still grabs it.
const _ribbonGrab = 14.0;

/// How far from a bow's knot a finger grabs the bow, not a ribbon.
const _bowGrab = 16.0;
const _symbolTarget = 44.0;

/// One slider's value labels, read by [_LabelPainter] at paint time.
class _Labels {
  const _Labels({
    required this.thumbs,
    required this.texts,
    required this.y,
    this.chains,
    this.partnerY = 0,
  });

  /// The start and end thumb x on a slider of the given width.
  final (double, double) Function(double width) thumbs;
  final (String, String) texts;
  final double y;

  /// The x, at [partnerY], of the chain from the start and from the end
  /// thumb; null where the slider has no chains.
  final (double, double) Function(double width)? chains;
  final double partnerY;
}

/// The rects of a slider's start and end value label: each beside its
/// thumb on the outer side. Where the card ends, a label goes inwards, past
/// the other thumb if it would cover it, and the other label makes way. Each
/// then clears the chains.
List<Rect> _labelRects(_Labels labels, (Size, Size) sizes, double width) {
  final (from, to) = labels.thumbs(width);
  final (startSize, endSize) = sizes;
  Rect rightOf(double x, Size size) => Offset(x + _labelGap, 0) & size;
  Rect leftOf(double x, Size size) =>
      Offset(x - _labelGap - size.width, 0) & size;
  var start = leftOf(from, startSize);
  var end = rightOf(to, endSize);
  if (start.left < 0) {
    start = rightOf(from, startSize);
    if (start.right > to - _thumbRadius) start = rightOf(to, startSize);
  }
  if (end.right > width) {
    end = leftOf(to, endSize);
    if (end.left < from + _thumbRadius) end = leftOf(from, endSize);
  }
  if (start.overlaps(end)) {
    if (start.left > from) {
      end = end.translate(start.right + 2 - end.left, 0);
    } else {
      start = start.translate(end.left - 2 - start.right, 0);
    }
  }
  final partners = labels.chains?.call(width);
  final chains = partners == null
      ? const <(double, double)>[]
      : [(from, partners.$1), (to, partners.$2)];
  return [
    for (final label in [start, end])
      _clearChains(label, chains, labels.y, labels.partnerY),
  ];
}

/// Centres [label] on the thumb height [y], then moves it away from the
/// other slider until it clears each chain, given as its x at [y] and at
/// [partnerY], and the chain's symbol target, but not out of the slider.
Rect _clearChains(
  Rect label,
  List<(double, double)> chains,
  double y,
  double partnerY,
) {
  // A chain is up to 9 px wide; keep its half width plus a gap.
  const clearance = 6.0;
  var shift = 0.0;
  for (final (x, partnerX) in chains) {
    final inner = label.center.dx < x ? label.right : label.left;
    final reach = max(0.0, (inner - x).abs() - clearance);
    final run = (partnerX - x).abs();
    final towardsLabel = (partnerX - x) * (label.center.dx - x) > 0;
    // The chain falls monotonically away from its thumb, so it is closest
    // to the label at the label's inner edge.
    final fall = towardsLabel && run > reach
        ? (partnerY - y).abs() * reach / run
        : double.infinity;
    shift = max(shift, label.height / 2 + clearance - fall);
    final symbol = (x + partnerX) / 2;
    if ((label.center.dx - symbol).abs() <
        label.width / 2 + _symbolTarget / 2) {
      shift = max(
        shift,
        label.height / 2 + _symbolTarget / 2 - (partnerY - y).abs() / 2,
      );
    }
  }
  final room = _sliderHeight / 2 - label.height / 2;
  final away = partnerY > y ? -1 : 1;
  return label.translate(
    0,
    y - label.height / 2 + away * min(shift, room) - label.top,
  );
}

/// The values of the dragged slider beside its thumbs, so close thumbs do
/// not stack their labels.
class _LabelPainter extends CustomPainter {
  _LabelPainter({required this.labels, required this.font, this.onPaint});

  /// The dragged slider's labels; null while nothing is dragged.
  final _Labels? labels;
  final TextStyle font;
  final void Function(List<Rect>)? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final l = labels;
    if (l == null) {
      onPaint?.call(const []);
      return;
    }
    TextPainter text(String t) => TextPainter(
      text: TextSpan(
        text: t,
        style: font.copyWith(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final painters = [text(l.texts.$1), text(l.texts.$2)];
    Size padded(TextPainter t) => Size(t.width + 10, t.height + 2);
    final rects = _labelRects(l, (
      padded(painters[0]),
      padded(painters[1]),
    ), size.width);
    final fill = Paint()..color = ink;
    for (var i = 0; i < 2; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rects[i], const Radius.circular(4)),
        fill,
      );
      painters[i].paint(
        canvas,
        rects[i].center - Offset(painters[i].width / 2, painters[i].height / 2),
      );
    }
    onPaint?.call(rects);
  }

  @override
  bool shouldRepaint(_LabelPainter old) => true;
}

/// Paints each chain from thumb centre to thumb centre beneath the sliders,
/// so the thumbs cover the ends and the chain meets the circle edges exactly.
class _ChainPainter extends CustomPainter {
  _ChainPainter({required this.chains, this.onPaint});

  /// Per chain: the word and the grammar thumb centre, and whether it is
  /// closed.
  final List<(Offset, Offset, bool)> chains;
  final void Function(List<(Offset, Offset)>)? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final ends = <(Offset, Offset)>[];
    for (final (a, b, linked) in chains) {
      _bridge(canvas, a, b, linked);
      _symbol(canvas, Offset.lerp(a, b, 0.5)!, linked);
      ends.add((a, b));
    }
    onPaint?.call(ends);
  }

  void _symbol(Canvas canvas, Offset mid, bool linked) {
    final color = linked ? ink : mutedText;
    canvas
      ..drawCircle(mid, 11, Paint()..color = marble)
      ..drawCircle(
        mid,
        11,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    final icon = linked ? Icons.link : Icons.link_off;
    final text = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 15,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, mid - Offset(text.width / 2, text.height / 2));
  }

  void _bridge(Canvas canvas, Offset a, Offset b, bool linked) {
    if (linked) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..shader = ui.Gradient.linear(a, b, [gold, terracotta])
          ..strokeWidth = 9,
      );
      return;
    }
    final d = b - a;
    final length = d.distance;
    canvas
      ..save()
      ..translate(a.dx, a.dy)
      ..rotate(d.direction);
    const stub = _thumbRadius + 7;
    final nub = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset.zero, const Offset(stub, 0), nub..color = gold)
      ..drawLine(
        Offset(length - stub, 0),
        Offset(length, 0),
        nub..color = terracotta,
      );
    final dots = Paint()..color = mutedText.withAlpha(140);
    for (var x = stub + 6; x < length - stub - 3; x += 6) {
      canvas.drawCircle(Offset(x, 0), 1.2, dots);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChainPainter old) => true;
}

/// Which books get their full width on the shared lesson scale. A book
/// without a thumb is always squeezed.
enum BookFocus {
  /// Every book that holds a thumb.
  thumbs,

  /// Only the book of the thumb being dragged, or else of the one dragged
  /// last; other books with thumbs are half open.
  dragged,

  /// The book of the upper word thumb, and of a thumb while it is dragged;
  /// other books with thumbs squeeze again on release.
  shrinkAfterRelease,

  /// Books whose thumbs moved in the last [_idleAfter], and the book of the
  /// thumb moved last; other books with thumbs are half open. Widths change
  /// only when the dragged thumb crosses into another book, so they hold
  /// still while a lesson is picked inside one.
  idle,

  /// Like [dragged], but widths change only on release, so the lesson under
  /// a still finger never moves.
  draggedOnRelease,
}

const _books = 5, _perBook = 20;
const _bookLater = _books * _perBook + 1;

/// The width of a squeezed book and of "Später".
const _squeezed = 22.0;
const _halfOpen = 0.3;
const _morphTime = Duration(milliseconds: 200);
const _idleAfter = Duration(seconds: 3);

/// The book of [lesson], 0-based; [_books] is "Später".
int _bookOf(int lesson) => (lesson - 1) ~/ _perBook;

String _bookStop(int lesson) => lesson == _bookLater ? 'Später' : 'L$lesson';

typedef BookRange = ({int from, int to});

/// Lesson ↔ x on a track where book b is [_squeezed] wide plus its share,
/// by [expansion]\[b\] in 0..1, of what the squeezed books leave free.
class BookScale {
  BookScale(List<double> expansion, this.left, double width) {
    final total = expansion.fold(0.0, (a, b) => a + b);
    final free = width - (_books + 1) * _squeezed;
    assert(total > 0 && free > 0, 'no book is open or the track is too short');
    var x = left;
    for (final e in [...expansion, 0.0]) {
      starts.add(x);
      widths.add(_squeezed + e / total * free);
      x += widths.last;
    }
  }

  final double left;
  final starts = <double>[], widths = <double>[];

  double cell(int lesson) =>
      lesson == _bookLater ? _squeezed : widths[_bookOf(lesson)] / _perBook;

  double x(int lesson) {
    if (lesson == _bookLater) return starts[_books] + _squeezed / 2;
    final b = _bookOf(lesson);
    return starts[b] + ((lesson - 1) % _perBook + 0.5) * cell(lesson);
  }

  int lessonAt(double x) {
    var b = 0;
    while (b < _books && x >= starts[b] + widths[b]) {
      b++;
    }
    if (b == _books) return _bookLater;
    final i = ((x - starts[b]) / widths[b] * _perBook).floor();
    return b * _perBook + i.clamp(0, _perBook - 1) + 1;
  }
}

class BooksDemo extends StatelessWidget {
  const BooksDemo({
    super.key,
    required this.focus,
    this.onScale,
    this.onPaintLabels,
  });

  final BookFocus focus;

  /// Reports, at each build of a card, the scale its sliders use; x is in
  /// the card's coordinates.
  final void Function(String card, BookScale scale)? onScale;

  /// Reports, at each paint of a card, the value labels of its dragged
  /// slider in the card's coordinates; empty while nothing is dragged.
  final void Function(String card, List<Rect> labels)? onPaintLabels;

  @override
  Widget build(BuildContext context) => _page(
    switch (focus) {
      BookFocus.thumbs => 'Breit: jedes Buch mit einem Griff.',
      BookFocus.dragged =>
        'Breit: nur das Buch des gezogenen (zuletzt gezogenen) Griffs; '
            'andere Bücher mit Griff halb.',
      BookFocus.shrinkAfterRelease =>
        'Breit: Buch des oberen Wort-Griffs, und ein Buch, solange darin '
            'gezogen wird. Nach Loslassen wieder schmal.',
      BookFocus.idle =>
        'Breit: Bücher, deren Griff sich in den letzten 3 s bewegt hat, und '
            'das zuletzt benutzte. Andere Bücher mit Griff halb. Die Breiten '
            'ändern sich nur, wenn der gezogene Griff das Buch wechselt.',
      BookFocus.draggedOnRelease =>
        'Wie „nur gezogenes“, aber die Breiten ändern sich erst nach dem '
            'Loslassen.',
    },
    [
      for (final (title, words, grammar) in [
        ('Nur aktuelles Buch', (from: 25, to: 32), (from: 21, to: 32)),
        ('Über zwei Bücher', (from: 15, to: 30), (from: 10, to: 30)),
        ('Grammatik ab L1', (from: 25, to: 32), (from: 1, to: 32)),
        ('Grammatik in Agite 1', (from: 25, to: 32), (from: 1, to: 20)),
      ])
        _card(
          title,
          BookSliders(
            focus: focus,
            words: words,
            grammar: grammar,
            onScale: onScale == null ? null : (s) => onScale!(title, s),
            onPaintLabels: onPaintLabels == null
                ? null
                : (l) => onPaintLabels!(title, l),
          ),
        ),
    ],
  );
}

/// The word slider over the grammar slider on a [BookScale]. With [links],
/// a chain per bound joins them: a closed chain makes that grammar bound
/// equal the word bound, dragging that grammar thumb opens it, tapping the
/// chain symbol toggles it. With [shelf], the books stand on a shelf and
/// bookmarks hanging from their pages are the thumbs.
class BookSliders extends StatefulWidget {
  const BookSliders({
    super.key,
    required this.focus,
    required this.words,
    required this.grammar,
    this.links,
    this.shelf = false,
    this.bow = false,
    this.onScale,
    this.onPaintLabels,
    this.onPaintChains,
    this.onPaintPages,
  });

  final BookFocus focus;
  final BookRange words, grammar;
  final ({bool left, bool right})? links;
  final bool shelf;

  /// See [_ChainPainter.bow]. Dropping a thumb on the lesson of its
  /// partner ties them.
  final bool bow;

  /// Reports, at each build, the scale the sliders use, in this widget's
  /// coordinates.
  final void Function(BookScale scale)? onScale;

  /// Reports, at each paint, the start and end value label of the dragged
  /// slider in this widget's coordinates; empty while nothing is dragged.
  final void Function(List<Rect> labels)? onPaintLabels;

  /// Reports, at each paint, the word and grammar end of the left and the
  /// right chain in this widget's coordinates.
  final void Function(List<(Offset, Offset)> ends)? onPaintChains;

  /// Reports, at each paint on the [shelf], the top of the pages of each
  /// lesson 1 to "Später" and the spine of each book, in this widget's
  /// coordinates.
  final void Function(List<Offset> tops, List<Rect> spines)? onPaintPages;

  @override
  State<BookSliders> createState() => _BookSlidersState();
}

class _BookSlidersState extends State<BookSliders>
    with SingleTickerProviderStateMixin {
  late var _words = widget.words;
  late var _grammar = widget.grammar;
  late var _links = widget.links;
  late var _from = _target();
  late var _to = _from;
  late final _morph = AnimationController(vsync: this, duration: _morphTime)
    ..addListener(() => setState(_followFinger));

  /// The thumb under the finger: which slider, which end, and the finger's
  /// position as a fraction of the track.
  ({bool words, bool start, double unit})? _drag;
  double _trackWidth = 0;

  /// Thumbs are 0 words.from, 1 words.to, 2 grammar.from, 3 grammar.to.
  var _last = 1;
  final _stale = {0, 2, 3};
  final _staleTimers = <int, Timer>{};

  /// The book of the dragged thumb at the last width change of the drag.
  int? _dragBook;

  int? get _dragged =>
      _drag == null ? null : (_drag!.words ? 0 : 2) + (_drag!.start ? 0 : 1);

  @override
  void dispose() {
    _morph.dispose();
    for (final t in _staleTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  List<int> get _thumbLessons => [
    _words.from,
    _words.to,
    _grammar.from,
    _grammar.to,
  ];

  double _weight(int thumb) => switch (widget.focus) {
    BookFocus.thumbs => 1,
    BookFocus.dragged ||
    BookFocus.draggedOnRelease => thumb == (_dragged ?? _last) ? 1 : _halfOpen,
    BookFocus.shrinkAfterRelease => thumb == _dragged || thumb == 1 ? 1 : 0,
    BookFocus.idle => thumb == _last || !_stale.contains(thumb) ? 1 : _halfOpen,
  };

  List<double> _target() {
    final lessons = _thumbLessons;
    return [
      for (var b = 0; b < _books; b++)
        [
          for (var t = 0; t < 4; t++)
            if (_bookOf(lessons[t]) == b) _weight(t),
        ].fold(0.0, max),
    ];
  }

  List<double> get _expansion {
    final t = Curves.easeInOut.transform(_morph.value);
    return [
      for (var b = 0; b < _books; b++) _from[b] + (_to[b] - _from[b]) * t,
    ];
  }

  BookScale get _scale => BookScale(_expansion, _overlayRadius, _trackWidth);

  double _unitOf(int lesson) =>
      (_scale.x(lesson) - _overlayRadius) / _trackWidth;

  int _lessonAt(double unit) =>
      _scale.lessonAt(_overlayRadius + unit * _trackWidth);

  void _retarget() {
    switch (widget.focus) {
      case BookFocus.draggedOnRelease when _drag != null:
        return;
      case BookFocus.idle:
        final book = _drag == null ? null : _bookOf(_thumbLessons[_dragged!]);
        if (book == null || book == _dragBook) return;
        _dragBook = book;
      default:
    }
    final target = _target();
    if (listEquals(target, _to)) return;
    _from = _expansion;
    _to = target;
    _morph.forward(from: 0);
  }

  /// Puts the dragged thumb on the lesson under the finger; while the books
  /// morph, that lesson changes even though the finger stays.
  void _followFinger() {
    final drag = _drag;
    if (drag == null) return;
    final lesson = _lessonAt(drag.unit);
    final r = drag.words ? _words : _grammar;
    final next = drag.start
        ? (from: min(lesson, r.to), to: r.to)
        : (from: r.from, to: max(lesson, r.from));
    final links = _links;
    if (drag.words) {
      _words = next;
      if (links != null) _grammar = _follow(_grammar);
    } else {
      if (links != null) {
        _links = (
          left: links.left && next.from == r.from,
          right: links.right && next.to == r.to,
        );
      }
      _grammar = next;
    }
    _retarget();
  }

  /// The grammar range after a linked bound copies the words; an open bound
  /// stays, pushed only as far as the range needs to stay non-empty.
  BookRange _follow(BookRange g) {
    final (:left, :right) = _links!;
    final from = left ? _words.from : g.from;
    final to = right ? _words.to : g.to;
    return left
        ? (from: from, to: max(from, to))
        : (from: min(from, to), to: to);
  }

  void _toggle({required bool left}) => setState(() {
    final (left: l, right: r) = _links!;
    _links = left ? (left: !l, right: r) : (left: l, right: !r);
    _grammar = _follow(_grammar);
    _retarget();
  });

  /// [thumb] moved: it is the last used one and fresh; the one used before
  /// goes stale after [_idleAfter].
  void _touch(int thumb) {
    if (thumb != _last) {
      final previous = _last;
      _staleTimers[previous]?.cancel();
      _staleTimers[previous] = Timer(
        _idleAfter,
        () => setState(() {
          _stale.add(previous);
          _retarget();
        }),
      );
    }
    _staleTimers.remove(thumb)?.cancel();
    _stale.remove(thumb);
    _last = thumb;
  }

  void _onChanged(bool words, RangeValues v) {
    final r = words ? _words : _grammar;
    final start = (v.start - _unitOf(r.from)).abs() > 1e-9;
    _dragTo(words, start, start ? v.start : v.end);
  }

  void _dragTo(bool words, bool start, double unit) => setState(() {
    final grabbed = _drag == null;
    _drag = (words: words, start: start, unit: unit);
    if (grabbed) _dragBook = _bookOf(_thumbLessons[_dragged!]);
    _touch(_dragged!);
    _followFinger();
  });

  /// With [BookSliders.bow], a released thumb on its partner's lesson ties
  /// them.
  /// [start] tells which bound the finger let go of; it is null after a
  /// slider tap that moved nothing.
  void _release(bool? start) => setState(() {
    final links = _links;
    if (widget.bow && links != null && start != null) {
      _links = start
          ? (
              left: links.left || _words.from == _grammar.from,
              right: links.right,
            )
          : (left: links.left, right: links.right || _words.to == _grammar.to);
    }
    _drag = null;
    _retarget();
  });

  /// The ribbon or bow under the finger on the shelf, and how far right of
  /// its middle the finger grabbed it, so a click does not move it.
  ({bool words, bool start, bool bow, double offset})? _grip;

  /// What a finger at [p] grabs: a bow moves both ribbons of its bound, a
  /// single ribbon unties its bound. Gold hangs in front of terracotta.
  ({bool words, bool start, bool bow, double offset})? _gripAt(Offset p) {
    final links = _links!;
    for (final start in [true, false]) {
      final (knot, _) = _bowAt(_scale, start ? _words.from : _words.to);
      if ((start ? links.left : links.right) &&
          (p - knot).distance <= _bowGrab) {
        return (words: true, start: start, bow: true, offset: p.dx - knot.dx);
      }
    }
    ({bool words, bool start, bool bow, double offset})? best;
    var bestDx = _ribbonGrab;
    for (final (words, start) in [
      (true, true),
      (true, false),
      (false, true),
      (false, false),
    ]) {
      final r = words ? _words : _grammar;
      final lesson = start ? r.from : r.to;
      final end = words
          ? _goldEnd(_scale, lesson, tied: start ? _links!.left : _links!.right)
          : _grammarEnd(_scale, lesson) + _grammarTail;
      final dx = (p.dx - _scale.x(lesson)).abs();
      if (p.dy >= _pageTop - 10 && p.dy <= end + 6 && dx < bestDx) {
        best = (
          words: words,
          start: start,
          bow: false,
          offset: p.dx - _scale.x(lesson),
        );
        bestDx = dx;
      }
    }
    return best;
  }

  void _gripStart(DragStartDetails d) {
    final grip = _gripAt(d.localPosition);
    _grip = grip;
    if (grip == null || !grip.words || grip.bow) return;
    final links = _links!;
    setState(
      () => _links = grip.start
          ? (left: false, right: links.right)
          : (left: links.left, right: false),
    );
  }

  void _gripMove(DragUpdateDetails d) {
    final grip = _grip;
    if (grip == null) return;
    _dragTo(
      grip.words,
      grip.start,
      ((d.localPosition.dx - grip.offset - _overlayRadius) / _trackWidth).clamp(
        0,
        1,
      ),
    );
  }

  void _gripEnd() {
    final grip = _grip;
    if (grip == null) return;
    _grip = null;
    _release(grip.start);
  }

  /// The dragged slider's labels at its thumbs on the current book scale.
  _Labels? _labels() {
    final drag = _drag;
    if (drag == null) return null;
    final (r, other) = drag.words ? (_words, _grammar) : (_grammar, _words);
    return _Labels(
      thumbs: (_) => (_scale.x(r.from), _scale.x(r.to)),
      texts: (_bookStop(r.from), _bookStop(r.to)),
      y: drag.words ? _wordsY : _grammarY,
      chains: _links == null
          ? null
          : (_) => (_scale.x(other.from), _scale.x(other.to)),
      partnerY: drag.words ? _grammarY : _wordsY,
    );
  }

  double get _gap => _links == null || widget.shelf ? 0 : _sliderGap;
  double get _grammarY => _wordsY + _sliderHeight + _gap;

  /// The tap target centred on the chain symbol, halfway between the word
  /// and the grammar thumb.
  Widget _chainButton({required bool left}) {
    final linked = left ? _links!.left : _links!.right;
    final mid = Offset(
      (_scale.x(left ? _words.from : _words.to) +
              _scale.x(left ? _grammar.from : _grammar.to)) /
          2,
      (_wordsY + _grammarY) / 2,
    );
    return Positioned(
      left: mid.dx - _symbolTarget / 2,
      top: mid.dy - _symbolTarget / 2,
      width: _symbolTarget,
      height: _symbolTarget,
      child: _ChainButton(
        left: left,
        linked: linked,
        hintRight: mid.dx < _overlayRadius + _trackWidth / 2,
        onTap: () => _toggle(left: left),
      ),
    );
  }

  Widget _slider(bool words) {
    final r = words ? _words : _grammar;
    final color = words ? gold : terracotta;
    return _ownOverlay(
      RangeSlider(
        activeColor: widget.shelf ? Colors.transparent : color,
        inactiveColor: widget.shelf ? Colors.transparent : color.withAlpha(60),
        overlayColor: widget.shelf
            ? const WidgetStatePropertyAll(Colors.transparent)
            : null,
        values: RangeValues(_unitOf(r.from), _unitOf(r.to)),
        labels: RangeLabels(_bookStop(r.from), _bookStop(r.to)),
        onChanged: (v) => _onChanged(words, v),
        onChangeEnd: (_) => _release(_drag?.start),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.bow)
        _summaryLine(
          'Wörter ${_bookStop(_words.from)}–${_bookStop(_words.to)}',
          _wordsText,
        ),
      SliderTheme(
        data: _sliderTheme(context).copyWith(
          showValueIndicator: ShowValueIndicator.never,
          // A squeezed book has ~3 px per lesson; the default 8 px gap would
          // keep two thumbs at least three lessons apart there.
          minThumbSeparation: 0,
          rangeThumbShape: widget.shelf ? const _HiddenThumb() : null,
          overlappingShapeStrokeColor: widget.shelf ? Colors.transparent : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _trackWidth = constraints.maxWidth - 2 * _overlayRadius;
            final scale = _scale;
            widget.onScale?.call(scale);
            final links = _links;
            final font = DefaultTextStyle.of(context).style;
            return CustomPaint(
              painter: widget.shelf
                  ? _ShelfPainter(
                      scale: scale,
                      words: _words,
                      grammar: _grammar,
                      bows: widget.bow ? links : null,
                      font: font,
                      onPaint: widget.onPaintPages,
                    )
                  : _BooksPainter(
                      scale: scale,
                      words: _words,
                      grammar: _grammar,
                      gap: _gap,
                      font: font,
                    ),
              foregroundPainter: _LabelPainter(
                labels: _labels(),
                font: DefaultTextStyle.of(context).style,
                onPaint: widget.onPaintLabels,
              ),
              child: Stack(
                children: [
                  if (links != null && !widget.bow)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ChainPainter(
                          chains: [
                            for (final (w, g, linked) in [
                              (_words.from, _grammar.from, links.left),
                              (_words.to, _grammar.to, links.right),
                            ])
                              (
                                Offset(scale.x(w), _wordsY),
                                Offset(scale.x(g), _grammarY),
                                linked,
                              ),
                          ],
                          onPaint: widget.onPaintChains,
                        ),
                      ),
                    ),
                  IgnorePointer(
                    ignoring: widget.bow,
                    child: Column(
                      children: [
                        const SizedBox(height: _labelHeight + _barsHeight),
                        _slider(true),
                        SizedBox(height: _gap),
                        _slider(false),
                        SizedBox(height: widget.shelf ? 10 : _barsHeight),
                      ],
                    ),
                  ),
                  if (links != null && !widget.bow) ...[
                    _chainButton(left: true),
                    _chainButton(left: false),
                  ],
                  if (widget.bow)
                    Positioned.fill(
                      child: GestureDetector(
                        key: const Key('shelf.grip'),
                        dragStartBehavior: DragStartBehavior.down,
                        onHorizontalDragStart: _gripStart,
                        onHorizontalDragUpdate: _gripMove,
                        onHorizontalDragEnd: (_) => _gripEnd(),
                        onHorizontalDragCancel: _gripEnd,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      if (widget.bow)
        _summaryLine(
          'Grammatik ${_bookStop(_grammar.from)}–${_bookStop(_grammar.to)}',
          terracottaDark,
        )
      else
        _summary(
          '${_bookStop(_words.from)}–${_bookStop(_words.to)}',
          '${_bookStop(_grammar.from)}–${_bookStop(_grammar.to)}',
        ),
    ],
  );
}

const _labelHeight = 16.0, _barsHeight = 36.0;
const _wordsY = _labelHeight + _barsHeight + _sliderHeight / 2;

/// The knot of a bow at [lesson], halfway down its page and turned with
/// the page tops there.
(Offset, double) _bowAt(BookScale scale, int lesson) {
  final book = _ShelfBook(scale, _bookOf(lesson));
  final x = scale.x(lesson);
  return (
    Offset.lerp(book.top(x), book.bottom(x), 0.5)!,
    book.slope(x).direction,
  );
}

/// Where a word ribbon ends when bows tie: in its bow, or else just above
/// the bottom of its book.
double _goldEnd(BookScale scale, int lesson, {required bool tied}) => tied
    ? _bowAt(scale, lesson).$1.dy
    : _ShelfBook(scale, _bookOf(lesson)).bottom(scale.x(lesson)).dy - 6;

/// Where a grammar ribbon's chain end sits when bows tie: its tail then
/// hangs over the shelf edge as far below its page as without bows.
double _grammarEnd(BookScale scale, int lesson) =>
    _ShelfBook(scale, _bookOf(lesson)).bottom(scale.x(lesson)).dy +
    _wordsY +
    _sliderHeight -
    _coverLine;

/// Book names, book borders and both histograms, all on [scale] so every
/// bar sits under its thumb position.
class _BooksPainter extends CustomPainter {
  _BooksPainter({
    required this.scale,
    required this.words,
    required this.grammar,
    required this.gap,
    required this.font,
  });

  final BookScale scale;
  final BookRange words, grammar;

  /// The space between the word and the grammar slider.
  final double gap;
  final TextStyle font;

  static int _wordCount(int l) => l == _bookLater ? 0 : 4 + l * 7 % 9;
  static int _topicCount(int l) =>
      l == _bookLater ? 3 : (l % 3 == 0 ? 1 + l % 2 : 0);

  @override
  void paint(Canvas canvas, Size size) {
    const wordsBase = _labelHeight + _barsHeight;
    final grammarTop = wordsBase + 2 * _sliderHeight + gap;
    final squeezedFill = Paint()..color = sand.withAlpha(140);
    final border = Paint()
      ..color = outlineColor
      ..strokeWidth = 1;
    for (var b = 0; b <= _books; b++) {
      final x0 = scale.starts[b], w = scale.widths[b];
      final narrow = w < 40;
      if (narrow) {
        canvas.drawRect(Rect.fromLTWH(x0, 0, w, size.height), squeezedFill);
      }
      if (b > 0) {
        canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), border);
      }
      final name = b == _books
          ? (narrow ? '…' : 'Später')
          : (narrow ? 'A${b + 1}' : 'Agite ${b + 1}');
      final text = TextPainter(
        text: TextSpan(
          text: name,
          style: font.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: narrow ? mutedText : ink,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: w);
      text.paint(canvas, Offset(x0 + (w - text.width) / 2, 1));
    }
    for (var l = 1; l <= _bookLater; l++) {
      final x = scale.x(l);
      final half = max(min(scale.cell(l) - 1, 10.0), 0.6) / 2;
      final inWords = words.from <= l && l <= words.to;
      final inGrammar = grammar.from <= l && l <= grammar.to;
      final wordsH = (_barsHeight - 4) * _wordCount(l) / 12;
      final topicsH = (_barsHeight - 4) * _topicCount(l) / 3;
      canvas
        ..drawRect(
          Rect.fromLTRB(x - half, wordsBase - wordsH, x + half, wordsBase),
          Paint()..color = inWords ? gold : outlineColor,
        )
        ..drawRect(
          Rect.fromLTRB(x - half, grammarTop, x + half, grammarTop + topicsH),
          Paint()..color = inGrammar ? terracotta : outlineColor,
        );
    }
  }

  @override
  bool shouldRepaint(_BooksPainter old) => true;
}

/// A thumb the shelf's ribbons stand for.
class _HiddenThumb extends RangeSliderThumbShape {
  const _HiddenThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_thumbRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool isOnTop = false,
    TextDirection textDirection = TextDirection.ltr,
    required SliderThemeData sliderTheme,
    Thumb thumb = Thumb.start,
    bool isPressed = false,
  }) {}
}

/// The top of the front edge of a closed book.
const _pageTop = 46.0;

/// The shelf lies just above the grammar ribbons' tails, so they hang over
/// its edge.
const _shelfY = _wordsY + _sliderHeight + 6;

/// The covers stand in one line this far behind the shelf edge, so the
/// fanned pages of an open book can come forward.
const _coverLine = _shelfY - 12;

/// The length of a page from the spine at the back to its front edge.
const _pageLength = 136.0;

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
/// grammar ribbon hangs below its chain end.
const _goldNotch = 4.0, _grammarTail = 14.0;

const _cover = Color(0xFF4A3426);

/// Book [index] of [scale], standing on the shelf with its spine at the
/// back. Its pages turn about the spine: page i stands at angle θ with
/// sin θ = (x − centre) / [_pageLength], so its front edge keeps the x of
/// the scale. The covers turn furthest and stay in line with the closed
/// books; the pages between them reach forward and so, seen from above,
/// stand lower.
class _ShelfBook {
  _ShelfBook(BookScale scale, this.index)
    : left = scale.starts[index],
      width = scale.widths[index],
      fan = index == _books
          ? 0
          : (scale.widths[index] - _squeezed) /
                (scale.widths.fold(0.0, (a, w) => a + w) -
                    (_books + 1) * _squeezed);

  final int index;
  final double left, width;

  /// 0 for a closed book, 1 for one that has all the free width.
  final double fan;

  double get centre => left + width / 2;

  /// How far the page at [x] stands in front of the covers, shown as height.
  double _forward(double x) {
    final length = max(_pageLength, width / 2);
    double back(double x) => length * cos(asin((x - centre) / length));
    return _viewSquash * (back(x) - back(left));
  }

  /// The top of the page's front edge at [x].
  Offset top(double x) => Offset(x, _pageTop + _forward(x));

  Offset bottom(double x) => Offset(x, _coverLine + _forward(x));

  /// The unit direction of the page tops at [x], left to right.
  Offset slope(double x) {
    final d = top(min(x + 0.5, left + width)) - top(max(x - 0.5, left));
    return d / d.distance;
  }

  double get spineY => _pageTop - _closedTop;

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

/// The books in one row on a shelf, on [scale], and a bookmark ribbon at
/// each thumb whose end is the thumb.
class _ShelfPainter extends CustomPainter {
  _ShelfPainter({
    required this.scale,
    required this.words,
    required this.grammar,
    required this.font,
    this.bows,
    this.onPaint,
  });

  final BookScale scale;
  final BookRange words, grammar;

  /// Which bounds a bow ties. With it, the word ribbons hang down the whole
  /// book.
  final ({bool left, bool right})? bows;
  final TextStyle font;
  final void Function(List<Offset> tops, List<Rect> spines)? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final books = [for (var b = 0; b <= _books; b++) _ShelfBook(scale, b)];
    canvas
      ..drawRect(
        Rect.fromLTRB(0, _coverLine - 10, size.width, _shelfY),
        Paint()..color = Color.lerp(sand, outlineColor, 0.35)!,
      )
      ..drawRect(
        Rect.fromLTRB(0, _shelfY, size.width, _shelfY + 4),
        Paint()..color = outlineColor,
      );
    for (final book in books) {
      _book(canvas, book);
    }
    canvas.drawLine(
      const Offset(0, _shelfY),
      Offset(size.width, _shelfY),
      Paint()
        ..color = _cover
        ..strokeWidth = 1.5,
    );
    for (final book in books) {
      if (bows == null) {
        _title(canvas, book);
      } else {
        _name(canvas, book);
      }
    }
    for (final (l, c, y) in [
      (
        grammar.from,
        terracotta,
        bows == null
            ? _wordsY + _sliderHeight
            : _grammarEnd(scale, grammar.from),
      ),
      (
        grammar.to,
        terracotta,
        bows == null ? _wordsY + _sliderHeight : _grammarEnd(scale, grammar.to),
      ),
      for (final (l, tied) in [
        (words.from, bows?.left),
        (words.to, bows?.right),
      ])
        (l, gold, tied == null ? _wordsY : _goldEnd(scale, l, tied: tied)),
    ]) {
      _ribbon(canvas, books[_bookOf(l)], scale.x(l), y, c);
    }
    if (bows?.left ?? false) _bow(canvas, _bowAt(scale, words.from));
    if (bows?.right ?? false) _bow(canvas, _bowAt(scale, words.to));
    onPaint?.call(
      [for (var l = 1; l <= _bookLater; l++) books[_bookOf(l)].top(scale.x(l))],
      [for (final book in books) book.spineHead],
    );
  }

  void _book(Canvas canvas, _ShelfBook book) {
    final later = book.index == _books;
    final pages = later ? 8 : _perBook;
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
          ..color = later
              ? sand
              : (k.isEven ? parchment : Color.lerp(parchment, sand, 0.6)!),
      );
    }
    for (final x in lines) {
      canvas.drawLine(book.top(x), book.bottom(x), line);
    }
    final front = Paint()..color = later ? outlineColor : _cover;
    final edge = Paint()
      ..color = Color.lerp(later ? outlineColor : _cover, sand, 0.35)!;
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
    const m = Offset.zero;
    Paint fill(Color c) => Paint()..color = c;
    Paint rim(Color c) => Paint()
      ..color = Color.lerp(c, ink, 0.45)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (side, c) in [(-1.0, terracotta), (1.0, gold)]) {
      final tail = Path()
        ..addPolygon([
          m + Offset(-2.5 * side, 2),
          m + Offset(2.5 * side, 2),
          m + Offset(9 * side, 16),
          m + Offset(6 * side, 15),
          m + Offset(3 * side, 17),
        ], true);
      canvas
        ..drawPath(tail, fill(c))
        ..drawPath(tail, rim(c));
    }
    for (final (side, c) in [(-1.0, gold), (1.0, terracotta)]) {
      final loop = Path()
        ..moveTo(m.dx + 3 * side, m.dy - 2)
        ..cubicTo(
          m.dx + 10 * side,
          m.dy - 13,
          m.dx + 19 * side,
          m.dy - 10,
          m.dx + 18 * side,
          m.dy - 1,
        )
        ..cubicTo(
          m.dx + 17 * side,
          m.dy + 6,
          m.dx + 9 * side,
          m.dy + 6,
          m.dx + 3 * side,
          m.dy + 2,
        )
        ..close();
      canvas
        ..drawPath(loop, fill(c))
        ..drawPath(loop, rim(c));
    }
    final knot = RRect.fromRectAndRadius(
      Rect.fromCenter(center: m, width: 8, height: 9),
      const Radius.circular(2.5),
    );
    canvas
      ..drawRRect(knot, fill(gold))
      ..drawRRect(knot, rim(gold));
    canvas.restore();
  }

  void _title(Canvas canvas, _ShelfBook book) {
    final text = TextPainter(
      text: TextSpan(
        text: book.index == _books ? '…' : 'A${book.index + 1}',
        style: font.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: book.fan > 0.5 ? ink : mutedText,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(book.centre - text.width / 2, _shelfY + 10));
  }

  /// The book's name on the front of its pages, read from bottom to top.
  void _name(Canvas canvas, _ShelfBook book) {
    final text = TextPainter(
      text: TextSpan(
        text: book.index == _books ? 'Später' : 'Agite ${book.index + 1}',
        style: font.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: book.fan > 0.5 ? ink : mutedText,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
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
  /// its front edge and hanging straight down to its chain end ([x], [y]).
  /// The fold follows the page tops, so the ribbon turns with its pages.
  /// In a closed book it sticks out of the page edge, tilted.
  void _ribbon(Canvas canvas, _ShelfBook book, double x, double y, Color c) {
    final end = Offset(x, y);
    final inwards = x < book.centre ? 1.0 : -1.0;
    final slot = Offset(
      (x + 12 * inwards).clamp(book.left + 3, book.left + book.width - 3),
      y - 30,
    );
    final along = book.slope(x) * _ribbonHalf;
    // Only a nearly closed book tilts its ribbon.
    final upright = book.index == _books ? 1.0 : min(1.0, 4 * book.fan);
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
    final tip = c == gold ? end + d * _goldNotch : end + d * _grammarTail;
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
  bool shouldRepaint(_ShelfPainter old) => true;
}
