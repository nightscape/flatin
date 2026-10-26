import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../models/lesson_range.dart';
import '../models/settings.dart';
import '../theme.dart';

/// The slider theme the geometry assumes, pinned so the math cannot drift.
const _trackHeight = 4.0;
const _overlayRadius = 24.0;
const _thumbRadius = 10.0;
const _sliderHeight = 2 * _overlayRadius;

/// Leaves room for the 44×44 chain target between the thumbs of the two
/// sliders.
const _sliderGap = 16.0;
const _namesHeight = 14.0, _barsHeight = 48.0;
const _wordsY = _namesHeight + _barsHeight + _sliderHeight / 2;
const _grammarY = _wordsY + _sliderHeight + _sliderGap;
const _height = _grammarY + _sliderHeight / 2 + _barsHeight;

const _labelGap = _thumbRadius + 4;
const _symbolTarget = 44.0;

/// The width of a squeezed book and of "Später".
const _squeezed = 22.0;
const _halfOpen = 0.3;
const _morphTime = Duration(milliseconds: 200);
const _idleAfter = Duration(seconds: 3);

/// The book of [lesson] among books starting at [bookStarts], 0-based;
/// `bookStarts.length` is "Später".
int _bookIndex(List<int> bookStarts, int lesson) => lesson == laterLesson
    ? bookStarts.length
    : bookStarts.lastIndexWhere((s) => s <= lesson);

/// Lesson ↔ x on a track where book b is [_squeezed] wide plus its share,
/// by its expansion in 0..1, of what the squeezed books leave free.
/// "Später" is a squeezed segment after the last book.
class BookScale {
  BookScale(this.bookStarts, List<double> expansion, this.left, double width) {
    assert(bookStarts.first == 1, 'the first book starts at lesson 1');
    final total = expansion.fold(0.0, (a, b) => a + b);
    // With every thumb on "Später", the books share the room equally.
    final shares = total == 0 ? [for (final _ in expansion) 1.0] : expansion;
    final sum = total == 0 ? expansion.length.toDouble() : total;
    final free = width - (bookStarts.length + 1) * _squeezed;
    assert(free > 0, 'the track is too short for the books');
    var x = left;
    for (final e in [...shares, 0.0]) {
      starts.add(x);
      widths.add(_squeezed + e / sum * free);
      x += widths.last;
    }
  }

  final List<int> bookStarts;
  final double left;
  final starts = <double>[], widths = <double>[];

  int _lessons(int book) =>
      (book + 1 < bookStarts.length ? bookStarts[book + 1] : laterLesson) -
      bookStarts[book];

  double cell(int lesson) {
    final b = _bookIndex(bookStarts, lesson);
    return lesson == laterLesson ? _squeezed : widths[b] / _lessons(b);
  }

  double x(int lesson) {
    final b = _bookIndex(bookStarts, lesson);
    if (lesson == laterLesson) return starts[b] + _squeezed / 2;
    return starts[b] + (lesson - bookStarts[b] + 0.5) * cell(lesson);
  }

  int lessonAt(double x) {
    var b = 0;
    while (b < bookStarts.length && x >= starts[b] + widths[b]) {
      b++;
    }
    if (b == bookStarts.length) return laterLesson;
    final i = ((x - starts[b]) / widths[b] * _lessons(b)).floor();
    return bookStarts[b] + i.clamp(0, _lessons(b) - 1);
  }
}

/// The word slider over the grammar slider, with their histograms, on one
/// [BookScale]. A chain per bound joins the sliders: a closed chain keeps
/// that grammar bound on the word bound, dragging that grammar thumb opens
/// it, tapping the chain symbol toggles it.
///
/// Books without a thumb are squeezed. Widths change only when a thumb moves
/// into another book: by its drag, or while no thumb is held by a chain
/// toggle, a bar tap or a screen-reader step. Then the books of that thumb
/// and of thumbs moved in the last [_idleAfter] open wide, other books with
/// a thumb half.
class KursstandSliders extends StatefulWidget {
  const KursstandSliders({
    super.key,
    required this.settings,
    required this.bookStarts,
    required this.wordBar,
    required this.grammarBar,
    required this.onWords,
    required this.onGrammar,
    required this.onLinked,
    this.onScale,
    this.onPaintChains,
    this.onPaintLabels,
  });

  final Settings settings;

  /// The first lesson of each book, ascending; the last book ends at the
  /// last lesson.
  final List<int> bookStarts;

  /// The histogram bar of a lesson; it fills the height it gets.
  final Widget Function(int lesson) wordBar, grammarBar;
  final void Function(LessonRange) onWords, onGrammar;
  final void Function({bool? from, bool? to}) onLinked;

  /// Reports, at each build, the scale the sliders use, in this widget's
  /// coordinates.
  final void Function(BookScale scale)? onScale;

  /// Reports, at each paint, the word end, the symbol and the grammar end of
  /// the left and the right chain in this widget's coordinates.
  final void Function(List<(Offset, Offset, Offset)> chains)? onPaintChains;

  /// Reports, at each paint, the start and end value label of the dragged
  /// slider in this widget's coordinates; empty while nothing is dragged.
  final void Function(List<Rect> labels)? onPaintLabels;

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

  /// The one drag on the page: which slider, the thumb under the finger,
  /// the finger's position as a fraction of the track, and the thumb's book
  /// at the last width change of the drag. While it runs, the other slider,
  /// the bars and the chain symbols ignore pointers.
  ({bool words, bool start, double unit, int book})? _drag;
  double _trackWidth = 0;

  /// Thumbs are 0 words.from, 1 words.to, 2 grammar.from, 3 grammar.to.
  var _last = 1;

  /// When each thumb other than [_last] was last used; one never used here
  /// is at rest.
  final _leftAt = <int, Duration>{};

  LessonRange get _words => _settings.courseWords;
  LessonRange get _grammar => _settings.courseGrammar;

  static int _thumb(bool words, bool start) =>
      (words ? 0 : 2) + (start ? 0 : 1);

  @override
  void didUpdateWidget(KursstandSliders old) {
    super.didUpdateWidget(old);
    if (_drag == null) _settle(widget.settings);
  }

  @override
  void dispose() {
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
            if (_bookIndex(widget.bookStarts, lessons[t]) == b) _weight(t),
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
      BookScale(widget.bookStarts, _expansion, _overlayRadius, _trackWidth);

  double _unitOf(int lesson) =>
      (_scale.x(lesson) - _overlayRadius) / _trackWidth;

  int _lessonAt(double unit) =>
      _scale.lessonAt(_overlayRadius + unit * _trackWidth);

  /// Changes the widths only when the dragged thumb entered another book.
  void _retarget() {
    final drag = _drag!;
    final book = _bookIndex(
      widget.bookStarts,
      _thumbLessons[_thumb(drag.words, drag.start)],
    );
    if (book == drag.book) return;
    _drag = (words: drag.words, start: drag.start, unit: drag.unit, book: book);
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
      if (_bookIndex(widget.bookStarts, before[t]) !=
          _bookIndex(widget.bookStarts, after[t])) {
        _touch(t);
        moved = true;
      }
    }
    if (moved) _morphTo(_target());
  }

  void _apply(bool words, LessonRange next) {
    final settings = words
        ? _settings.withWordRange(next)
        : _settings.withGrammarRange(next);
    if (_drag == null) {
      _settle(settings);
    } else {
      _settings = settings;
    }
    (words ? widget.onWords : widget.onGrammar)(next);
  }

  /// Puts the dragged thumb on the lesson under the finger; while the books
  /// morph, that lesson changes even though the finger stays.
  void _followFinger() {
    final drag = _drag;
    if (drag == null) return;
    final lesson = _lessonAt(drag.unit);
    final r = drag.words ? _words : _grammar;
    final next = drag.start
        ? LessonRange(min(lesson, r.to), r.to)
        : LessonRange(r.from, max(lesson, r.from));
    if (next != r) _apply(drag.words, next);
    _retarget();
  }

  void _toggle({required bool left}) => setState(() {
    final linked = !(left
        ? _settings.grammarFromLinked
        : _settings.grammarToLinked);
    if (left) {
      _settle(_settings.withGrammarLinked(from: linked));
      widget.onLinked(from: linked);
    } else {
      _settle(_settings.withGrammarLinked(to: linked));
      widget.onLinked(to: linked);
    }
  });

  /// [thumb] is now the last used one; the one used before starts to rest.
  void _touch(int thumb) {
    if (thumb == _last) return;
    _leftAt[_last] = _now;
    _leftAt.remove(thumb);
    _last = thumb;
  }

  /// The first change that moves a value names the dragged thumb: the
  /// slider reports the other value as it got it. Later changes keep that
  /// thumb, since thumbs may coincide by then. A change from the other
  /// slider while a drag runs is ignored.
  void _onChanged(bool words, RangeValues v) {
    final r = words ? _words : _grammar;
    final grabbed = _drag;
    if (grabbed != null && grabbed.words != words) return;
    final start =
        grabbed?.start ??
        ((v.start - _unitOf(r.from)).abs() > 1e-9
            ? true
            : (v.end - _unitOf(r.to)).abs() > 1e-9
            ? false
            : null);
    if (start == null) return;
    setState(() {
      final thumb = _thumb(words, start);
      _drag = (
        words: words,
        start: start,
        unit: start ? v.start : v.end,
        book:
            grabbed?.book ??
            _bookIndex(widget.bookStarts, _thumbLessons[thumb]),
      );
      _touch(thumb);
      _followFinger();
    });
  }

  /// The left and the right chain symbol: halfway between their thumbs, but
  /// at least a tap target apart and inside the card.
  (Offset, Offset) _symbols(BookScale scale) {
    var left = (scale.x(_words.from) + scale.x(_grammar.from)) / 2;
    var right = (scale.x(_words.to) + scale.x(_grammar.to)) / 2;
    if (right - left < _symbolTarget) {
      final centre = (left + right) / 2;
      left = centre - _symbolTarget / 2;
      right = centre + _symbolTarget / 2;
    }
    final width = _trackWidth + 2 * _overlayRadius;
    final shift =
        max(0.0, _symbolTarget / 2 - left) +
        min(0.0, width - _symbolTarget / 2 - right);
    const y = (_wordsY + _grammarY) / 2;
    return (Offset(left + shift, y), Offset(right + shift, y));
  }

  /// The dragged slider's labels at its thumbs on the current book scale.
  _Labels? _labels() {
    final drag = _drag;
    if (drag == null) return null;
    final words = drag.words;
    final r = words ? _words : _grammar;
    final (from, to) = (_scale.x(r.from), _scale.x(r.to));
    final (left, right) = _symbols(_scale);
    return _Labels(
      thumbs: (from, to),
      texts: (_stop(r.from), _stop(r.to)),
      y: words ? _wordsY : _grammarY,
      // Near its thumb a chain runs straight towards its symbol halfway to
      // the other slider.
      chains: (2 * left.dx - from, 2 * right.dx - to),
      partnerY: words ? _grammarY : _wordsY,
    );
  }

  /// The tap target centred on the chain symbol.
  Widget _chainButton({required bool left}) {
    final (l, r) = _symbols(_scale);
    final mid = left ? l.dx : r.dx;
    final linked = left
        ? _settings.grammarFromLinked
        : _settings.grammarToLinked;
    return Positioned(
      left: mid - _symbolTarget / 2,
      top: (_wordsY + _grammarY) / 2 - _symbolTarget / 2,
      width: _symbolTarget,
      height: _symbolTarget,
      child: IgnorePointer(
        ignoring: _drag != null,
        child: _ChainButton(
          key: Key('kursstand.chain.${left ? 'left' : 'right'}'),
          label: _tr(
            '${left ? 'chainFrom' : 'chainTo'}${linked ? 'Linked' : 'Open'}',
          ),
          hint: _tr(linked ? 'chainUnlink' : 'chainLink'),
          hintRight: mid < _overlayRadius + _trackWidth / 2,
          onTap: () => _toggle(left: left),
        ),
      ),
    );
  }

  /// One thumb's screen-reader node, which steps by one lesson.
  Widget _thumbSemantics(bool words, bool start) {
    final r = words ? _words : _grammar;
    final lesson = start ? r.from : r.to;
    final up = lesson < (start ? r.to : laterLesson);
    final down = lesson > (start ? 1 : r.from);
    void step(int by) => setState(
      () => _apply(
        words,
        start
            ? LessonRange(lesson + by, r.to)
            : LessonRange(r.from, lesson + by),
      ),
    );
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

  Widget _slider(bool words) {
    final r = words ? _words : _grammar;
    final color = words ? gold : terracotta;
    return Stack(
      children: [
        Row(
          children: [
            _thumbSemantics(words, true),
            _thumbSemantics(words, false),
          ],
        ),
        // A slider's value bubble lives in the nearest Overlay; in the app's
        // it leaves a parentless semantics node, which crashes macOS
        // accessibility.
        ExcludeSemantics(
          child: IgnorePointer(
            ignoring: _drag != null && _drag!.words != words,
            child: Overlay.wrap(
              clipBehavior: Clip.none,
              child: RangeSlider(
                key: Key('kursstand.${words ? 'words' : 'grammar'}.slider'),
                activeColor: color,
                inactiveColor: color.withAlpha(60),
                values: RangeValues(_unitOf(r.from), _unitOf(r.to)),
                onChanged: (v) => _onChanged(words, v),
                onChangeEnd: (_) => setState(() {
                  if (_drag?.words == words) _drag = null;
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _bars(double y, bool words) {
    final scale = _scale;
    return [
      for (var l = 1; l <= laterLesson; l++)
        Positioned(
          left: scale.x(l) - _barWidth(scale.cell(l)) / 2,
          width: _barWidth(scale.cell(l)),
          top: y,
          height: _barsHeight,
          child: IgnorePointer(
            ignoring: _drag != null,
            child: Align(
              alignment: words ? Alignment.bottomCenter : Alignment.topCenter,
              child: (words ? widget.wordBar : widget.grammarBar)(l),
            ),
          ),
        ),
    ];
  }

  static double _barWidth(double cell) => cell > 4 ? cell - 2 : cell;

  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderTheme.of(context).copyWith(
      trackHeight: _trackHeight,
      overlayShape: const RoundSliderOverlayShape(
        overlayRadius: _overlayRadius,
      ),
      rangeThumbShape: const RoundRangeSliderThumbShape(
        enabledThumbRadius: _thumbRadius,
      ),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      showValueIndicator: ShowValueIndicator.never,
      // A squeezed book has a few px per lesson; the default 8 px gap would
      // keep two thumbs lessons apart there.
      minThumbSeparation: 0,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth - 2 * _overlayRadius;
        final scale = _scale;
        widget.onScale?.call(scale);
        final font = DefaultTextStyle.of(context).style;
        return CustomPaint(
          painter: _BooksPainter(
            scale: scale,
            names: [
              for (var b = 1; b <= widget.bookStarts.length; b++)
                (_tr('book', {'book': '$b'}), _tr('bookShort', {'book': '$b'})),
              (_tr('later'), '…'),
            ],
            font: font,
          ),
          foregroundPainter: _LabelPainter(
            labels: _labels(),
            font: font,
            onPaint: widget.onPaintLabels,
          ),
          child: SizedBox(
            height: _height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChainPainter(
                      chains: [
                        for (final (w, symbol, g, linked) in [
                          (
                            _words.from,
                            _symbols(scale).$1,
                            _grammar.from,
                            _settings.grammarFromLinked,
                          ),
                          (
                            _words.to,
                            _symbols(scale).$2,
                            _grammar.to,
                            _settings.grammarToLinked,
                          ),
                        ])
                          (
                            Offset(scale.x(w), _wordsY),
                            symbol,
                            Offset(scale.x(g), _grammarY),
                            linked,
                          ),
                      ],
                      onPaint: widget.onPaintChains,
                    ),
                  ),
                ),
                ..._bars(_namesHeight, true),
                ..._bars(_grammarY + _sliderHeight / 2, false),
                Positioned(
                  top: _wordsY - _sliderHeight / 2,
                  left: 0,
                  right: 0,
                  height: _sliderHeight,
                  child: _slider(true),
                ),
                Positioned(
                  top: _grammarY - _sliderHeight / 2,
                  left: 0,
                  right: 0,
                  height: _sliderHeight,
                  child: _slider(false),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TickPainter(
                        scale: scale,
                        words: _words,
                        grammar: _grammar,
                      ),
                    ),
                  ),
                ),
                _chainButton(left: true),
                _chainButton(left: false),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// The 44×44 tap target on a chain symbol. A mouse over it gets the click
/// cursor, a ring and a hint below; the hint grows towards [hintRight] so it
/// stays in the card. A Tooltip would need the app's overlay, whose
/// semantics node the macOS bridge cannot place.
class _ChainButton extends StatefulWidget {
  const _ChainButton({
    super.key,
    required this.label,
    required this.hint,
    required this.hintRight,
    required this.onTap,
  });

  final String label, hint;
  final bool hintRight;
  final VoidCallback onTap;

  @override
  State<_ChainButton> createState() => _ChainButtonState();
}

class _ChainButtonState extends State<_ChainButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Semantics(
      button: true,
      label: widget.label,
      hint: widget.hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_hovered) ...[
              Center(
                child: Container(
                  key: const Key('kursstand.chain.hover'),
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
                top: _symbolTarget + 2,
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
                      widget.hint,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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

/// Paints each chain from thumb centre through its symbol to thumb centre
/// beneath the sliders, so the thumbs cover the ends and the chain meets the
/// circle edges exactly. Where the symbols are pushed apart, the chain bends
/// at its symbol.
class _ChainPainter extends CustomPainter {
  _ChainPainter({required this.chains, this.onPaint});

  /// Per chain: the word thumb centre, the symbol, the grammar thumb centre,
  /// and whether it is closed.
  final List<(Offset, Offset, Offset, bool)> chains;
  final void Function(List<(Offset, Offset, Offset)>)? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (a, s, b, linked) in chains) {
      _bridge(canvas, a, s, b, linked);
    }
    for (final (_, s, _, linked) in chains) {
      _symbol(canvas, s, linked);
    }
    onPaint?.call([for (final (a, s, b, _) in chains) (a, s, b)]);
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

  void _bridge(Canvas canvas, Offset a, Offset s, Offset b, bool linked) {
    if (linked) {
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(s.dx, s.dy)
          ..lineTo(b.dx, b.dy),
        Paint()
          ..shader = ui.Gradient.linear(a, b, [gold, terracotta])
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 9,
      );
      return;
    }
    const stub = _thumbRadius + 7;
    final nub = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final dots = Paint()..color = mutedText.withAlpha(140);
    for (final (end, color) in [(a, gold), (b, terracotta)]) {
      final d = s - end;
      final along = d / d.distance;
      canvas.drawLine(end, end + along * stub, nub..color = color);
      for (var x = stub + 6; x < d.distance; x += 6) {
        canvas.drawCircle(end + along * x, 1.2, dots);
      }
    }
  }

  @override
  bool shouldRepaint(_ChainPainter old) => true;
}

/// A tick per lesson on both tracks, where the lessons are wide enough to
/// tell apart and no thumb covers the tick.
class _TickPainter extends CustomPainter {
  _TickPainter({
    required this.scale,
    required this.words,
    required this.grammar,
  });

  final BookScale scale;
  final LessonRange words, grammar;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (range, y, color) in [
      (words, _wordsY, gold),
      (grammar, _grammarY, terracotta),
    ]) {
      final active = Paint()..color = Colors.white.withAlpha(150);
      final inactive = Paint()..color = color.withAlpha(150);
      for (var l = 1; l <= laterLesson; l++) {
        final x = scale.x(l);
        if (scale.cell(l) < 4 ||
            (x - scale.x(range.from)).abs() <= _thumbRadius ||
            (x - scale.x(range.to)).abs() <= _thumbRadius) {
          continue;
        }
        canvas.drawCircle(
          Offset(x, y),
          1,
          range.contains(l) ? active : inactive,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) => true;
}

/// Book names and borders on [scale]; squeezed books get a sand fill and
/// their short name.
class _BooksPainter extends CustomPainter {
  _BooksPainter({required this.scale, required this.names, required this.font});

  final BookScale scale;

  /// Per book and then "Später": the full and the short name.
  final List<(String, String)> names;
  final TextStyle font;

  @override
  void paint(Canvas canvas, Size size) {
    final squeezedFill = Paint()..color = sand.withAlpha(140);
    final border = Paint()
      ..color = outlineColor
      ..strokeWidth = 1;
    for (var b = 0; b < names.length; b++) {
      final x0 = scale.starts[b], w = scale.widths[b];
      final narrow = w < 40;
      if (narrow) {
        canvas.drawRect(Rect.fromLTWH(x0, 0, w, size.height), squeezedFill);
      }
      if (b > 0) {
        canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), border);
      }
      final (full, short) = names[b];
      final text = TextPainter(
        text: TextSpan(
          text: narrow ? short : full,
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
  }

  @override
  bool shouldRepaint(_BooksPainter old) => true;
}
