import 'dart:math';

import 'package:flutter/material.dart';

import '../models/settings.dart' show StemMarking;

/// A target-language form. [split] is the number of letters (grapheme
/// clusters) in the stem; null means the form has no known stem.
///
/// [StemMarking.aus] shows the plain [text] and takes no taps.
///
/// With a split, [StemMarking.zeigen] colours the ending and takes no taps.
/// [StemMarking.selbstMarkieren] lets the learner place the bar with a tap,
/// move it with another tap or a drag, and check it with the confirm button;
/// [onMark] gets whether the confirmed gap is the boundary, and the bar
/// glides there in the same neutral colour for a right and a wrong mark.
///
/// Without a split, both modes mark freely: a tap on a gap marks the letters
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
         mode != StemMarking.selbstMarkieren || split == null || onMark != null,
         'a split form in selbstMarkieren needs onMark',
       );

  final String text;
  final int? split;
  final StemMarking mode;
  final ValueChanged<bool>? onMark;
  final TextStyle? style;

  static const textKey = Key('form-text-text');
  static const separatorKey = Key('form-text-separator');
  static const confirmKey = Key('form-text-confirm');
  static const checkKey = Key('form-text-check');

  /// The side of the confirm button: the Material minimum tap target.
  static const confirmSize = 48.0;

  @override
  State<FormText> createState() => _FormTextState();
}

class _FormTextState extends State<FormText> {
  int? _mark;
  bool _confirmed = false;

  @override
  void didUpdateWidget(FormText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text ||
        old.split != widget.split ||
        old.mode != widget.mode) {
      _mark = null;
      _confirmed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final letters = widget.text.characters;
    final split = widget.split;
    assert(
      split == null || (split > 0 && split < letters.length),
      'split $split outside 1..${letters.length - 1} of "${widget.text}"',
    );
    if (widget.mode == StemMarking.aus ||
        (split == null && letters.length < 2)) {
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
        // At a line break the downstream caret starts the next line; the
        // upstream one ends this line, so a tap there finds the gap too.
        final targets = [
          for (var g = 0; g < gapPositions.length; g++) ...[
            (g, gapAt[g], gapHeight[g]),
            (
              g,
              painter.getOffsetForCaret(
                TextPosition(
                  offset: gapPositions[g].offset,
                  affinity: TextAffinity.upstream,
                ),
                Rect.zero,
              ),
              gapHeight[g],
            ),
          ],
        ];
        final textSize = painter.size;
        final last = painter.computeLineMetrics().last;
        final lastEnd = last.left + last.width + 4;
        final confirmAt = lastEnd + FormText.confirmSize <= constraints.maxWidth
            ? Offset(lastEnd, last.baseline - last.ascent)
            : Offset(0, textSize.height);
        painter.dispose();
        // The caret positions decide, not the glyphs: a combining mark has
        // its own glyph, which would split a letter.
        int gapUnder(Offset at) {
          double off((int, Offset, double) t) => at.dy < t.$2.dy
              ? t.$2.dy - at.dy
              : max(0, at.dy - t.$2.dy - t.$3);
          final line = targets.map(off).reduce(min);
          return 1 +
              targets
                  .where((t) => off(t) == line)
                  .reduce(
                    (a, b) => (a.$2.dx - at.dx).abs() <= (b.$2.dx - at.dx).abs()
                        ? a
                        : b,
                  )
                  .$1;
        }

        return _marked(
          scheme,
          letters,
          gapAt,
          gapHeight,
          textSize,
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
    Size textSize,
    Offset confirmAt,
    double lineHeight,
    int Function(Offset) gapUnder,
  ) {
    final split = widget.split;
    final mark = _mark;
    final shown = split != null && widget.mode == StemMarking.zeigen;
    final checking = split != null && !shown;
    final endingFrom = shown || _confirmed ? split : mark;
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

    final withButton = checking && mark != null;
    final stack = SizedBox(
      width: withButton
          ? max(textSize.width, confirmAt.dx + FormText.confirmSize)
          : textSize.width,
      height: withButton
          ? max(textSize.height, confirmAt.dy + FormText.confirmSize)
          : textSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 0, width: textSize.width, child: text),
          if (shown) bar(gapAt[split - 1], gapHeight[split - 1]),
          if (mark != null && !_confirmed)
            bar(gapAt[mark - 1], gapHeight[mark - 1]),
          if (_confirmed)
            Positioned.fill(
              child: TweenAnimationBuilder<Offset>(
                tween: Tween(begin: gapAt[mark! - 1], end: gapAt[split! - 1]),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, at, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [bar(at, gapHeight[split - 1])],
                ),
              ),
            ),
          if (withButton && !_confirmed)
            Positioned(
              left: confirmAt.dx,
              top: confirmAt.dy,
              child: IconButton(
                key: FormText.confirmKey,
                constraints: const BoxConstraints.tightFor(
                  width: FormText.confirmSize,
                  height: FormText.confirmSize,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(Icons.done, color: scheme.outline),
                onPressed: () {
                  setState(() => _confirmed = true);
                  widget.onMark!(mark == split);
                },
              ),
            ),
          if (_confirmed && mark == split)
            Positioned(
              left: confirmAt.dx,
              top: confirmAt.dy,
              child: Icon(
                Icons.check,
                key: FormText.checkKey,
                size: lineHeight,
                color: scheme.outline,
              ),
            ),
        ],
      ),
    );
    if (shown || _confirmed) return stack;
    void place(Offset at) {
      final gap = gapUnder(at);
      setState(() => _mark = gap == mark ? null : gap);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => place(details.localPosition),
      onHorizontalDragUpdate: checking
          ? (details) => setState(() => _mark = gapUnder(details.localPosition))
          : null,
      child: stack,
    );
  }
}
