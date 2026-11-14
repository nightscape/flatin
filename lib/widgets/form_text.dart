import 'package:flutter/material.dart';

enum StemMarking { aus, zeigen, selbstMarkieren, frei }

/// A target-language form. [split] is the number of letters (grapheme
/// clusters) in the stem; null, or a split that leaves no ending, shows the
/// plain [text] and asks nothing.
///
/// In [StemMarking.selbstMarkieren] the learner taps the gap between stem and
/// ending once; [onMark] gets whether the tap hit the boundary. The reply is
/// the same neutral colour for a right and a wrong tap.
///
/// In [StemMarking.frei] [split] is ignored: a tap on a gap marks the letters
/// after it, a tap on another gap moves the mark, a tap on the marked gap
/// removes it. Nothing is checked or reported.
///
/// A gap owns every x nearer to it than to any other gap, so the gaps tile
/// the word's own layout box. Untapped, the box is exactly that of the plain
/// text.
class FormText extends StatefulWidget {
  const FormText({
    super.key,
    required this.text,
    required this.split,
    required this.mode,
    this.onMark,
    this.style,
  }) : assert(
         mode != StemMarking.selbstMarkieren || onMark != null,
         'mode selbstMarkieren needs onMark',
       );

  final String text;
  final int? split;
  final StemMarking mode;
  final ValueChanged<bool>? onMark;
  final TextStyle? style;

  static const textKey = Key('form-text-text');
  static const separatorKey = Key('form-text-separator');
  static const confirmKey = Key('form-text-confirm');

  @override
  State<FormText> createState() => _FormTextState();
}

class _FormTextState extends State<FormText> {
  int? _tapped;
  int? _mark;

  @override
  void didUpdateWidget(FormText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.split != widget.split) {
      _tapped = null;
      _mark = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final letters = widget.text.characters;
    final split = widget.split;
    assert(
      split == null || (split > 0 && split <= letters.length),
      'split $split outside 1..${letters.length} of "${widget.text}"',
    );
    final free = widget.mode == StemMarking.frei;
    final hasSplit = split != null && split < letters.length;
    if (widget.mode == StemMarking.aus ||
        (free ? letters.length < 2 : !hasSplit)) {
      return Text(widget.text, key: FormText.textKey, style: widget.style);
    }
    final scheme = Theme.of(context).colorScheme;
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        TextPainter laidOut() => TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: constraints.maxWidth);
        final painter = laidOut();
        final gapPositions = [
          for (var k = 1; k < letters.length; k++)
            TextPosition(offset: letters.take(k).string.length),
        ];
        final gapAt = [
          for (final g in gapPositions) painter.getOffsetForCaret(g, Rect.zero),
        ];
        final gapHeight = [
          for (final g in gapPositions)
            painter.getFullHeightForCaret(g, Rect.zero),
        ];
        final textWidth = painter.width;
        final textHeight = painter.height;
        final last = painter.computeLineMetrics().last;
        final lastEnd = last.left + last.width + 4;
        final confirmAt = lastEnd + last.height <= constraints.maxWidth
            ? Offset(lastEnd, last.baseline - last.ascent)
            : Offset(0, textHeight);
        painter.dispose();
        int gapUnder(Offset at) {
          final p = laidOut();
          final offset = p.getPositionForOffset(at).offset;
          p.dispose();
          return widget.text
              .substring(0, offset)
              .characters
              .length
              .clamp(1, letters.length - 1);
        }

        return _marked(
          scheme,
          letters,
          gapAt,
          gapHeight,
          textWidth,
          textHeight,
          confirmAt,
          last.height,
          gapUnder,
        );
      },
    );
  }

  Widget _marked(
    ColorScheme scheme,
    Characters letters,
    List<Offset> gapAt,
    List<double> gapHeight,
    double textWidth,
    double textHeight,
    Offset confirmAt,
    double confirmSize,
    int Function(Offset) gapUnder,
  ) {
    final split = widget.split;
    final free = widget.mode == StemMarking.frei;
    final tapped = _tapped;
    final endingFrom = switch (widget.mode) {
      StemMarking.zeigen => split,
      StemMarking.selbstMarkieren => tapped == null ? null : split,
      StemMarking.frei => _mark,
      StemMarking.aus => throw StateError('aus is plain text'),
    };
    final text = Text.rich(
      key: FormText.textKey,
      TextSpan(
        children: [
          TextSpan(text: letters.take(endingFrom ?? letters.length).string),
          if (endingFrom != null)
            TextSpan(
              text: letters.skip(endingFrom).string,
              style: TextStyle(color: scheme.tertiary),
            ),
        ],
      ),
      style: widget.style,
    );

    Widget bar(Offset at, double height) => Positioned(
      left: at.dx - 1,
      top: at.dy,
      child: Container(
        key: FormText.separatorKey,
        width: 2,
        height: height,
        color: scheme.outline,
      ),
    );

    final stack = SizedBox(
      width: textWidth,
      height: textHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 0, width: textWidth, child: text),
          if (widget.mode == StemMarking.zeigen)
            bar(gapAt[split! - 1], gapHeight[split - 1]),
          if (free && _mark != null)
            bar(gapAt[_mark! - 1], gapHeight[_mark! - 1]),
          if (widget.mode == StemMarking.selbstMarkieren && tapped != null)
            Positioned.fill(
              child: TweenAnimationBuilder<Offset>(
                tween: Tween(begin: gapAt[tapped - 1], end: gapAt[split! - 1]),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, at, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [bar(at, gapHeight[split - 1])],
                ),
              ),
            ),
          if (widget.mode == StemMarking.selbstMarkieren && tapped == split)
            Positioned(
              left: confirmAt.dx,
              top: confirmAt.dy,
              child: Icon(
                Icons.check,
                key: FormText.confirmKey,
                size: confirmSize,
                color: scheme.outline,
              ),
            ),
        ],
      ),
    );
    if (widget.mode == StemMarking.zeigen ||
        (widget.mode == StemMarking.selbstMarkieren && tapped != null)) {
      return stack;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final nearest = gapUnder(details.localPosition);
        if (free) {
          setState(() => _mark = nearest == _mark ? null : nearest);
        } else {
          setState(() => _tapped = nearest);
          widget.onMark!(nearest == split);
        }
      },
      child: stack,
    );
  }
}
