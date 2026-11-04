import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/widgets/kursstand_shelf.dart';

import 'support/gen_shelf_label.dart';

// The front of a book: from the top of its pages to the cover line.
const _front = shelfGrammarY - 6 - shelfPageTop;

void main() {
  testWidgets('a book label never lays out wider than the front of a book, '
      'and a label that fits keeps its natural width', (tester) async {
    const font = TextStyle();
    TextPainter natural(String s) => TextPainter(
      text: TextSpan(
        text: s,
        style: font.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final fixed = ['', 'Lectio', 'x' * 200];
    final rng = Random(407);
    final labels = [
      ...fixed,
      for (var i = 0; i < 300; i++) drawShelfLabel(rng),
    ];
    for (final open in [false, true]) {
      final names = ShelfNames(labels, font);
      for (final (i, label) in labels.indexed) {
        final painter = names.painter(i, open: open);
        final width = painter.width;
        expect(width, lessThanOrEqualTo(_front), reason: '"$label"');
        expect(
          painter.height,
          natural('x').height,
          reason: '"$label" one line',
        );
        final full = natural(label).width;
        if (full <= _front) {
          expect(width, full, reason: '"$label" fits');
        } else {
          expect(painter.didExceedMaxLines, isTrue, reason: '"$label" cut');
        }
      }
      names.dispose();
    }
  });
}
