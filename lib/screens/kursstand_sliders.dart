import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../models/lesson_range.dart';
import '../models/settings.dart';
import '../theme.dart';
import '../widgets/kursstand_shelf.dart';

const _thumbRadius = 10.0;
const _sliderHeight = shelfRowHeight;
const _labelGap = _thumbRadius + 4;
const _symbolTarget = 44.0;

/// How far from a ribbon's middle a finger still grabs it.
const _ribbonGrab = 14.0;

/// How far from a bow's knot a finger grabs the bow, not a ribbon.
const _bowGrab = 16.0;

const _halfOpen = 0.3;
const _morphTime = Duration(milliseconds: 200);
const _idleAfter = Duration(seconds: 3);

/// The ribbon a finger holds: a word or a grammar ribbon, or with [bow] the
/// bow of its bound, and how far right of its middle the finger grabbed it,
/// so a click does not move it.
typedef _Grip = ({bool words, bool start, bool bow, double offset});

/// The course books on a shelf, on one [BookScale]. A gold bookmark ribbon
/// marks each word bound, a terracotta one each grammar bound; dragging a
/// ribbon moves its bound. A bow ties a linked grammar bound to its word
/// bound: dragging the bow moves both, dragging the gold ribbon alone or the
/// terracotta one unties it, and a ribbon dropped on its partner's lesson
/// ties them.
///
/// Books without a ribbon are closed. Widths change only when a ribbon moves
/// into another book: by its drag, or while no ribbon is held by a
/// screen-reader step. Then the books of that ribbon and of ribbons moved in
/// the last [_idleAfter] open wide, other books with a ribbon half.
class KursstandSliders extends StatefulWidget {
  const KursstandSliders({
    super.key,
    required this.settings,
    required this.bookStarts,
    required this.books,
    required this.onCourse,
    this.onScale,
    this.onPaintLabels,
    this.onPaintPages,
  });

  final Settings settings;

  /// The first lesson of each book, ascending; the last book ends at the
  /// last lesson.
  final List<int> bookStarts;

  /// The name of each book in [bookStarts].
  final List<String> books;

  /// Gets the settings with each new course position and link; a drag
  /// passes them on only when the finger lets go.
  final void Function(Settings) onCourse;

  /// Reports, at each build, the scale the shelf uses, in this widget's
  /// coordinates.
  final void Function(BookScale scale)? onScale;

  /// Reports, at each paint, the start and end value label of the dragged
  /// range in this widget's coordinates; empty while nothing is dragged.
  final void Function(List<Rect> labels)? onPaintLabels;

  /// Reports, at each paint, the page tops of each lesson 1 to "Später" and
  /// the spine of each book, in this widget's coordinates.
  final void Function(List<Offset> tops, List<Rect> spines)? onPaintPages;

  @override
  State<KursstandSliders> createState() => _KursstandSlidersState();
}

class _KursstandSlidersState extends State<KursstandSliders>
    with SingleTickerProviderStateMixin {
  late var _settings = widget.settings;
  late var _from = _target();
  late var _to = _from;
  late final _morph = AnimationController(vsync: this, duration: _morphTime)
    ..addListener(() => setState(_followFinger));

  /// The first finger on the shelf and its last x; other fingers are
  /// ignored, so one gesture runs at a time.
  int? _pointer;
  double _fingerX = 0;

  _Grip? _grip;

  /// Whether the grabbed start lies on its end, so the first move decides
  /// which of the two the finger holds.
  var _either = false;

  /// While a grabbed ribbon moves: the finger's position as a fraction of
  /// the track, and the ribbon's book at the last width change of the drag.
  ({double unit, int book})? _drag;

  /// Whether the current drag changed [_settings] since it began.
  var _dragChanged = false;
  double _trackWidth = 0;

  ShelfNames? _names;

  ShelfNames _shelfNames(TextStyle font) {
    final texts = [...widget.books, _tr('later')];
    if (_names?.shows(texts, font) != true) {
      _names?.dispose();
      _names = ShelfNames(texts, font);
    }
    return _names!;
  }

  /// Thumbs are 0 words.from, 1 words.to, 2 grammar.from, 3 grammar.to.
  var _last = 1;

  /// When each thumb other than [_last] was last used; one never used here
  /// is at rest.
  final _leftAt = <int, Duration>{};

  LessonRange get _words => _settings.courseWords;
  LessonRange get _grammar => _settings.courseGrammar;

  static int _thumb(bool words, bool start) =>
      (words ? 0 : 2) + (start ? 0 : 1);

  bool _tied(bool start) =>
      start ? _settings.grammarFromLinked : _settings.grammarToLinked;

  Settings _withTie(bool start, bool tied) => _settings.withGrammarLinked(
    from: start ? tied : null,
    to: start ? null : tied,
  );

  @override
  void didUpdateWidget(KursstandSliders old) {
    super.didUpdateWidget(old);
    if (_grip == null) _settle(widget.settings);
  }

  @override
  void dispose() {
    _names?.dispose();
    _morph.dispose();
    super.dispose();
  }

  String _tr(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(
        context,
        'settings.kursstand.$key',
        translationParams: params,
      );

  String _stop(int lesson) => lesson == laterLesson ? _tr('later') : 'L$lesson';

  List<int> get _thumbLessons => [
    _words.from,
    _words.to,
    _grammar.from,
    _grammar.to,
  ];

  Duration get _now => SchedulerBinding.instance.currentSystemFrameTimeStamp;

  double _weight(int thumb) {
    final left = _leftAt[thumb];
    return thumb == _last || (left != null && _now - left < _idleAfter)
        ? 1
        : _halfOpen;
  }

  List<double> _target() {
    final lessons = _thumbLessons;
    return [
      for (var b = 0; b < widget.bookStarts.length; b++)
        [
          for (var t = 0; t < 4; t++)
            if (bookIndex(widget.bookStarts, lessons[t]) == b) _weight(t),
        ].fold(0.0, max),
    ];
  }

  List<double> get _expansion {
    final t = Curves.easeInOut.transform(_morph.value);
    return [
      for (var b = 0; b < _to.length; b++) _from[b] + (_to[b] - _from[b]) * t,
    ];
  }

  BookScale get _scale =>
      BookScale(widget.bookStarts, _expansion, shelfInset, _trackWidth);

  /// Changes the widths only when the dragged ribbon entered another book.
  void _retarget() {
    final (drag, grip) = (_drag!, _grip!);
    final book = bookIndex(
      widget.bookStarts,
      _thumbLessons[_thumb(grip.words, grip.start)],
    );
    if (book == drag.book) return;
    _drag = (unit: drag.unit, book: book);
    _morphTo(_target());
  }

  void _morphTo(List<double> target) {
    if (listEquals(target, _to)) return;
    _from = _expansion;
    _to = target;
    _morph.forward(from: 0);
  }

  /// [next] came without a drag: a thumb it moves into another book counts
  /// as used there, so that book's width follows.
  void _settle(Settings next) {
    final before = _thumbLessons;
    _settings = next;
    final after = _thumbLessons;
    var moved = false;
    for (var t = 0; t < 4; t++) {
      if (bookIndex(widget.bookStarts, before[t]) !=
          bookIndex(widget.bookStarts, after[t])) {
        _touch(t);
        moved = true;
      }
    }
    if (moved) _morphTo(_target());
  }

  void _apply(Settings next) {
    if (_drag == null) {
      _settle(next);
      widget.onCourse(next);
    } else {
      _settings = next;
      _dragChanged = true;
    }
  }

  /// Puts the dragged ribbon on the lesson under the finger; while the books
  /// morph, that lesson changes even though the finger stays.
  void _followFinger() {
    final drag = _drag;
    if (drag == null) return;
    var grip = _grip!;
    final lesson = _scale.lessonAt(shelfInset + drag.unit * _trackWidth);
    final r = grip.words ? _words : _grammar;
    if (_either && lesson > r.to) {
      grip = _grip = (
        words: grip.words,
        start: false,
        bow: grip.bow && _tied(false),
        offset: grip.offset,
      );
      _touch(_thumb(grip.words, false));
    }
    if (lesson != r.from) _either = false;
    final next = grip.start
        ? LessonRange(min(lesson, r.to), r.to)
        : LessonRange(r.from, max(lesson, r.from));
    if (next != r) {
      if (grip.words) {
        final untied = grip.bow ? _settings : _withTie(grip.start, false);
        _apply(untied.withWordRange(next));
      } else {
        _apply(_settings.withGrammarRange(next));
      }
    }
    _retarget();
  }

  /// [thumb] is now the last used one; the one used before starts to rest.
  void _touch(int thumb) {
    if (thumb == _last) return;
    _leftAt[_last] = _now;
    _leftAt.remove(thumb);
    _last = thumb;
  }

  /// What a finger at [p] grabs: the knot of a bow, or else the nearest
  /// ribbon, gold in front of terracotta.
  _Grip? _gripAt(Offset p) {
    final scale = _scale;
    for (final start in [true, false]) {
      final (knot, _) = shelfBowAt(scale, start ? _words.from : _words.to);
      if (_tied(start) && (p - knot).distance <= _bowGrab) {
        return (words: true, start: start, bow: true, offset: p.dx - knot.dx);
      }
    }
    _Grip? best;
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
          ? shelfGoldEnd(scale, lesson, tied: _tied(start))
          : shelfGrammarEnd(scale, lesson) + shelfGrammarTail;
      final dx = p.dx - scale.x(lesson);
      if (p.dy >= shelfPageTop - 10 && p.dy <= end + 6 && dx.abs() < bestDx) {
        best = (words: words, start: start, bow: false, offset: dx);
        bestDx = dx.abs();
      }
    }
    return best;
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _fingerX = e.localPosition.dx;
  }

  void _gripStart(DragStartDetails d) {
    if (_pointer == null || _grip != null) return;
    final grip = _gripAt(d.localPosition);
    if (grip == null) return;
    _grip = grip;
    final r = grip.words ? _words : _grammar;
    _either = grip.start && r.from == r.to;
    _dragTo();
  }

  void _moved(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    _fingerX = e.localPosition.dx;
    if (_grip != null) _dragTo();
  }

  void _dragTo() => setState(() {
    final grip = _grip!;
    final thumb = _thumb(grip.words, grip.start);
    _drag = (
      unit: ((_fingerX - grip.offset - shelfInset) / _trackWidth).clamp(0, 1),
      book: _drag?.book ?? bookIndex(widget.bookStarts, _thumbLessons[thumb]),
    );
    _touch(thumb);
    _followFinger();
  });

  /// Letting go of a ribbon on its partner's lesson ties them.
  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final grip = _grip;
    if (grip == null) return;
    setState(() {
      final start = grip.start;
      final (w, g) = start
          ? (_words.from, _grammar.from)
          : (_words.to, _grammar.to);
      if (w == g && !_tied(start)) _apply(_withTie(start, true));
      _grip = null;
      _drag = null;
    });
    if (_dragChanged) {
      _dragChanged = false;
      widget.onCourse(_settings);
    }
  }

  /// The dragged range's labels at its ribbons on the current book scale.
  _Labels? _labels() {
    final grip = _grip;
    if (grip == null || _drag == null) return null;
    final scale = _scale;
    final (r, other) = grip.words ? (_words, _grammar) : (_grammar, _words);
    return _Labels(
      thumbs: (scale.x(r.from), scale.x(r.to)),
      texts: (_stop(r.from), _stop(r.to)),
      y: grip.words ? shelfWordsY : shelfGrammarY,
      chains: (scale.x(other.from), scale.x(other.to)),
      partnerY: grip.words ? shelfGrammarY : shelfWordsY,
    );
  }

  /// A screen-reader button that ties or unties a bound; fingers reach the
  /// ribbons through it.
  Widget _tieButton(BookScale scale, {required bool start}) {
    final tied = _tied(start);
    final x =
        (scale.x(start ? _words.from : _words.to) +
            scale.x(start ? _grammar.from : _grammar.to)) /
        2;
    return Positioned(
      left: x - _symbolTarget / 2,
      top: (shelfWordsY + shelfGrammarY) / 2 - _symbolTarget / 2,
      width: _symbolTarget,
      height: _symbolTarget,
      child: Semantics(
        key: Key('kursstand.tie.${start ? 'left' : 'right'}'),
        button: true,
        label: _tr(
          '${start ? 'chainFrom' : 'chainTo'}${tied ? 'Linked' : 'Open'}',
        ),
        hint: _tr(tied ? 'chainUnlink' : 'chainLink'),
        onTap: () => setState(() => _apply(_withTie(start, !tied))),
        child: const SizedBox.expand(),
      ),
    );
  }

  /// One thumb's screen-reader node, which steps by one lesson.
  Widget _thumbSemantics(bool words, bool start) {
    final r = words ? _words : _grammar;
    final lesson = start ? r.from : r.to;
    final up = lesson < (start ? r.to : laterLesson);
    final down = lesson > (start ? 1 : r.from);
    void step(int by) => setState(() {
      final next = start
          ? LessonRange(lesson + by, r.to)
          : LessonRange(r.from, lesson + by);
      _apply(
        words
            ? _settings.withWordRange(next)
            : _settings.withGrammarRange(next),
      );
    });
    return Expanded(
      child: Semantics(
        slider: true,
        label:
            '${_tr(words ? 'words' : 'grammar')}, '
            '${_tr(start ? 'boundFrom' : 'boundTo')}',
        value: _stop(lesson),
        increasedValue: up ? _stop(lesson + 1) : null,
        decreasedValue: down ? _stop(lesson - 1) : null,
        onIncrease: up ? () => step(1) : null,
        onDecrease: down ? () => step(-1) : null,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _row(bool words) => Positioned(
    key: Key('kursstand.${words ? 'words' : 'grammar'}.slider'),
    top: (words ? shelfWordsY : shelfGrammarY) - shelfRowHeight / 2,
    left: 0,
    right: 0,
    height: shelfRowHeight,
    child: Row(
      children: [_thumbSemantics(words, true), _thumbSemantics(words, false)],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _trackWidth = constraints.maxWidth - 2 * shelfInset;
      final scale = _scale;
      widget.onScale?.call(scale);
      final font = DefaultTextStyle.of(context).style;
      return CustomPaint(
        painter: ShelfPainter(
          scale: scale,
          words: _words,
          grammar: _grammar,
          tiedFrom: _settings.grammarFromLinked,
          tiedTo: _settings.grammarToLinked,
          names: _shelfNames(font),
          onPaint: widget.onPaintPages,
        ),
        foregroundPainter: _LabelPainter(
          labels: _labels(),
          font: font,
          onPaint: widget.onPaintLabels,
        ),
        child: SizedBox(
          height: shelfHeight,
          child: Stack(
            children: [
              _row(true),
              _row(false),
              _tieButton(scale, start: true),
              _tieButton(scale, start: false),
              Positioned.fill(
                child: Listener(
                  onPointerDown: _down,
                  onPointerMove: _moved,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: GestureDetector(
                    key: const Key('kursstand.shelf'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    dragStartBehavior: DragStartBehavior.down,
                    onHorizontalDragStart: _gripStart,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One slider's value labels, read by [_LabelPainter] at paint time.
class _Labels {
  const _Labels({
    required this.thumbs,
    required this.texts,
    required this.y,
    required this.chains,
    required this.partnerY,
  });

  /// The start and end thumb x.
  final (double, double) thumbs;
  final (String, String) texts;
  final double y;

  /// The x, at [partnerY], of the chain from the start and from the end
  /// thumb.
  final (double, double) chains;
  final double partnerY;
}

/// The rects of a slider's start and end value label: each beside its
/// thumb on the outer side. Where the card ends, a label goes inwards, past
/// the other thumb if it would cover it, and the other label makes way. Each
/// then clears the chains.
List<Rect> _labelRects(_Labels labels, (Size, Size) sizes, double width) {
  final (from, to) = labels.thumbs;
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
  final chains = [(from, labels.chains.$1), (to, labels.chains.$2)];
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
