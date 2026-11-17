import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/settings.dart' show StemMarking;
import 'package:latin_practice/widgets/form_text.dart';

import 'support/gen_form_text.dart';

typedef TwoLineCase = ({
  String text,
  double width,
  double scale,
  TextStyle style,
});

/// Long forms under a width limit and a text scale, kept only when they
/// break over two or more lines.
Iterable<TwoLineCase> twoLineTaps(Random rng, int count) sync* {
  yield (
    text: 'apportāvissēmus',
    width: 320,
    scale: 2.0,
    style: const TextStyle(fontSize: 20),
  );
  yield (
    text: 'ārrmlēūōasaalā',
    width: 320,
    scale: 1.0,
    style: const TextStyle(fontSize: 30),
  );
  for (var i = 0; i < count; i++) {
    yield (
      text: drawLongForm(rng),
      width: formTextWidths[rng.nextInt(formTextWidths.length)],
      scale: formTextScales[rng.nextInt(formTextScales.length)],
      style: drawFormTextStyle(rng),
    );
  }
}

RenderParagraph _paragraph(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byKey(FormText.textKey),
    matching: find.byType(RichText),
  ),
);

int? _mark(WidgetTester tester) {
  final root = _paragraph(tester).text as TextSpan;
  final parts = (root.children!.single as TextSpan).children!;
  return parts.length == 2
      ? (parts.first as TextSpan).text!.characters.length
      : null;
}

void main() {
  testWidgets('in every marking that takes taps, a tap on a broken form '
      'marks the interior gap nearest to the text position under the finger', (
    tester,
  ) async {
    final rng = Random(4176);
    var broken = 0;
    final wrong = <String>[];
    for (final c in twoLineTaps(rng, 60)) {
      final letters = c.text.characters;
      final checkedSplit = 1 + rng.nextInt(letters.length - 1);
      for (final (mode, split) in [
        (StemMarking.zeigen, null),
        (StemMarking.selbstMarkieren, null),
        (StemMarking.selbstMarkieren, checkedSplit),
      ]) {
        Future<RenderParagraph> pump() async {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(c.scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: c.width),
                    child: FormText(
                      key: UniqueKey(),
                      text: c.text,
                      split: split,
                      mode: mode,
                      onMark: (_) {},
                      style: c.style,
                    ),
                  ),
                ),
              ),
            ),
          );
          return _paragraph(tester);
        }

        var p = await pump();
        final end = TextPosition(offset: c.text.length);
        final endAt = p.getOffsetForCaret(end, Rect.zero);
        final lineHeight = p.getFullHeightForCaret(end);
        if (endAt.dy == 0) continue;
        if (mode == StemMarking.zeigen) broken++;
        final taps = <Offset>[];
        var at = 0;
        for (final l in letters) {
          final box = p
              .getBoxesForSelection(
                TextSelection(baseOffset: at, extentOffset: at + l.length),
              )
              .first;
          final y = (box.top + box.bottom) / 2;
          taps.add(Offset(box.left + (box.right - box.left) * 0.25, y));
          taps.add(Offset(box.left + (box.right - box.left) * 0.75, y));
          at += l.length;
        }
        if (endAt.dx + 2 * lineHeight < p.size.width) {
          taps.add(Offset(p.size.width - 1, endAt.dy + lineHeight / 2));
        }
        for (final local in taps) {
          final offset = p.getPositionForOffset(local).offset;
          final expected = c.text
              .substring(0, offset)
              .characters
              .length
              .clamp(1, letters.length - 1);
          p = await pump();
          await tester.tapAt(p.localToGlobal(local));
          await tester.pump();
          final got = _mark(tester);
          if (got != expected) {
            wrong.add(
              '$mode split $split "${c.text}" x${c.scale} in ${c.width}px tap $local: '
              'gap $got, text position gives gap $expected',
            );
          }
        }
      }
    }
    expect(broken, greaterThan(0), reason: 'no drawn form broke');
    expect(wrong, isEmpty, reason: wrong.take(12).join('\n'));
  });
}
