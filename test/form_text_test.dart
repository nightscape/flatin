import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/widgets/form_text.dart';

import 'support/gen_form_text.dart';

// Generators: drawFormTextCase (new, test/support/gen_form_text.dart): text of
// 0-12 letters over Latin/Greek/Cyrillic with macrons x split x mode, seeded
// loop with fixed cases first. Brightness and the tap gap are drawn in-test.

final _fixed = <FormTextCase>[
  (text: 'rosā', split: 3, mode: StemMarking.selbstMarkieren),
  (text: 'āmus', split: 2, mode: StemMarking.selbstMarkieren),
  (text: 'rosa', split: 4, mode: StemMarking.selbstMarkieren),
  (text: 'rosa', split: null, mode: StemMarking.selbstMarkieren),
  (text: 'ab', split: 1, mode: StemMarking.selbstMarkieren),
  (text: '', split: null, mode: StemMarking.zeigen),
  (text: 'ωβα', split: 2, mode: StemMarking.zeigen),
  (text: 'puellārum', split: 6, mode: StemMarking.aus),
];

List<FormTextCase> _cases() {
  final rng = Random(416);
  return [..._fixed, for (var i = 0; i < 150; i++) drawFormTextCase(rng)];
}

Future<List<bool>> _pump(
  WidgetTester tester,
  FormTextCase c,
  Brightness brightness,
) async {
  final marks = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: FormText(
            text: c.text,
            split: c.split,
            mode: c.mode,
            onMark: c.mode == StemMarking.selbstMarkieren ? marks.add : null,
          ),
        ),
      ),
    ),
  );
  return marks;
}

RenderParagraph _paragraph(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byKey(FormText.textKey),
    matching: find.byType(RichText),
  ),
);

String _plain(WidgetTester tester) =>
    _paragraph(tester).text.toPlainText(includePlaceholders: false);

TextSpan _lastSpan(WidgetTester tester) {
  final root = _paragraph(tester).text as TextSpan;
  return (root.children!.single as TextSpan).children!.last as TextSpan;
}

Color? _endingColor(WidgetTester tester) => _lastSpan(tester).style?.color;

List<double> _gapXs(WidgetTester tester, String text) {
  final p = _paragraph(tester);
  final letters = text.characters;
  return [
    for (var k = 1; k < letters.length; k++)
      p
          .localToGlobal(
            p.getOffsetForCaret(
              TextPosition(offset: letters.take(k).string.length),
              Rect.zero,
            ),
          )
          .dx,
  ];
}

double _separatorX(WidgetTester tester) =>
    tester.getCenter(find.byKey(FormText.separatorKey)).dx;

bool _hasSplit(FormTextCase c) =>
    c.split != null && c.split! < c.text.characters.length;

void main() {
  testWidgets('aus and zeigen show the text; zeigen splits only with an '
      'ending, in a second colour in light and dark', (tester) async {
    for (final c in _cases().where(
      (c) => c.mode != StemMarking.selbstMarkieren,
    )) {
      for (final b in Brightness.values) {
        await _pump(tester, c, b);
        final reason = '$c $b';
        expect(_plain(tester), c.text, reason: reason);
        final separator = find.byKey(FormText.separatorKey);
        if (c.mode == StemMarking.zeigen && _hasSplit(c)) {
          expect(separator, findsOneWidget, reason: reason);
          final scheme = Theme.of(
            tester.element(find.byKey(FormText.textKey)),
          ).colorScheme;
          expect(_endingColor(tester), scheme.tertiary, reason: reason);
          expect(
            _separatorX(tester),
            closeTo(_gapXs(tester, c.text)[c.split! - 1], 1.01),
            reason: reason,
          );
        } else {
          expect(separator, findsNothing, reason: reason);
        }
      }
    }
  });

  testWidgets('selbst markieren: the nearest gap to a tap is marked, right '
      'iff it is the boundary; nothing is asked without an ending', (
    tester,
  ) async {
    final rng = Random(4160);
    for (final c in _cases().where(
      (c) => c.mode == StemMarking.selbstMarkieren,
    )) {
      final b = Brightness.values[rng.nextInt(2)];
      final marks = await _pump(tester, c, b);
      final reason = '$c $b';
      expect(_plain(tester), c.text, reason: reason);
      expect(find.byKey(FormText.separatorKey), findsNothing, reason: reason);
      final n = c.text.characters.length;
      if (!_hasSplit(c)) {
        await tester.tapAt(tester.getCenter(find.byKey(FormText.textKey)));
        await tester.pumpAndSettle();
        expect(marks, isEmpty, reason: reason);
        expect(find.byKey(FormText.separatorKey), findsNothing, reason: reason);
        continue;
      }
      final xs = _gapXs(tester, c.text);
      final g = 1 + rng.nextInt(n - 1);
      final neighbours = [
        for (final (i, x) in xs.indexed)
          if (i != g - 1) (x - xs[g - 1]).abs(),
      ];
      final box = tester.getRect(find.byType(FormText));
      final reach = [
        if (neighbours.isNotEmpty) neighbours.reduce(min) / 2 - 1,
        xs[g - 1] - box.left - 0.5,
        box.right - xs[g - 1] - 0.5,
      ].reduce(min);
      final y = box.center.dy;
      await tester.tapAt(
        Offset(
          xs[g - 1] + (rng.nextDouble() * 2 - 1) * reach,
          y + (rng.nextDouble() * 2 - 1) * (box.height / 2 - 0.5),
        ),
      );
      expect(marks, [g == c.split], reason: reason);
      await tester.pumpAndSettle();
      expect(find.byKey(FormText.separatorKey), findsOneWidget, reason: reason);
      expect(
        _separatorX(tester),
        closeTo(_gapXs(tester, c.text)[c.split! - 1], 1.01),
        reason: '$reason separator rests on the boundary',
      );
      expect(
        find.byKey(FormText.confirmKey),
        g == c.split ? findsOneWidget : findsNothing,
        reason: reason,
      );
      expect(_plain(tester), c.text, reason: reason);
      await tester.tapAt(Offset(xs[0], y));
      expect(marks.length, 1, reason: '$reason one mark per form');
    }
  });

  testWidgets('a wrong tap starts on the tapped gap and glides to the '
      'boundary', (tester) async {
    final c = (text: 'rosarum', split: 3, mode: StemMarking.selbstMarkieren);
    await _pump(tester, c, Brightness.light);
    final xs = _gapXs(tester, c.text);
    await tester.tapAt(
      Offset(xs[5], tester.getCenter(find.byKey(FormText.textKey)).dy),
    );
    await tester.pump();
    expect(_separatorX(tester), closeTo(xs[5], 1.01));
    await tester.pumpAndSettle();
    expect(_separatorX(tester), closeTo(xs[2], 1.01));
  });

  testWidgets('frei: the mark sits at the last tapped gap, a tap on the '
      'marked gap removes it, untapped is the plain text', (tester) async {
    final rng = Random(417);
    final cases = <FormTextCase>[
      (text: 'rosarum', split: null, mode: StemMarking.frei),
      (text: 'ab', split: null, mode: StemMarking.frei),
      (text: 'a', split: null, mode: StemMarking.frei),
      (text: '', split: null, mode: StemMarking.frei),
      (text: 'puellārum', split: 4, mode: StemMarking.frei),
      for (var i = 0; i < 80; i++)
        (text: drawFormTextCase(rng).text, split: null, mode: StemMarking.frei),
    ];
    for (final c in cases) {
      final b = Brightness.values[rng.nextInt(2)];
      await _pump(tester, c, b);
      final reason = '$c $b';
      final letters = c.text.characters;
      expect(_plain(tester), c.text, reason: reason);
      expect(find.byKey(FormText.separatorKey), findsNothing, reason: reason);
      final y = tester.getCenter(find.byKey(FormText.textKey)).dy;
      if (letters.length < 2) {
        await tester.tapAt(tester.getCenter(find.byKey(FormText.textKey)));
        await tester.pump();
        expect(find.byKey(FormText.separatorKey), findsNothing, reason: reason);
        continue;
      }
      final scheme = Theme.of(
        tester.element(find.byKey(FormText.textKey)),
      ).colorScheme;
      final xs = _gapXs(tester, c.text);
      int? mark;
      for (final g in drawGapTaps(rng, letters.length)) {
        await tester.tapAt(Offset(xs[g - 1], y));
        await tester.pump();
        mark = mark == g ? null : g;
        final step = '$reason tap $g';
        expect(_plain(tester), c.text, reason: step);
        if (mark == null) {
          expect(find.byKey(FormText.separatorKey), findsNothing, reason: step);
          expect(_endingColor(tester), isNull, reason: step);
        } else {
          expect(find.byKey(FormText.separatorKey), findsOneWidget);
          expect(_separatorX(tester), closeTo(xs[mark - 1], 1.01));
          expect(_endingColor(tester), scheme.tertiary, reason: step);
          expect(_lastSpan(tester).text, letters.skip(mark).string);
        }
      }
    }
  });

  testWidgets('untapped, a form takes exactly the layout size of the plain '
      'text at every text scale and width', (tester) async {
    final rng = Random(4173);
    final cases = <FormTextCase>[
      (text: 'puellarum', split: 4, mode: StemMarking.frei),
      (text: 'puellarum', split: 4, mode: StemMarking.zeigen),
      (text: 'puellarum', split: 4, mode: StemMarking.selbstMarkieren),
      (text: 'ab', split: 1, mode: StemMarking.frei),
      (text: 'apportāminī', split: 4, mode: StemMarking.frei),
      for (var i = 0; i < 60; i++) drawFormTextCase(rng),
      for (var i = 0; i < 30; i++)
        (text: drawLongForm(rng), split: 3, mode: StemMarking.frei),
    ];
    Future<Size> sizeOf(Widget w, double scale, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width),
                child: w,
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(w.runtimeType).first);
    }

    for (final c in cases) {
      final style = drawFormTextStyle(rng);
      final scale = formTextScales[rng.nextInt(formTextScales.length)];
      final width = formTextWidths[rng.nextInt(formTextWidths.length)];
      final form = await sizeOf(
        FormText(
          text: c.text,
          split: c.split,
          mode: c.mode,
          onMark: c.mode == StemMarking.selbstMarkieren ? (_) {} : null,
          style: style,
        ),
        scale,
        width,
      );
      final plain = await sizeOf(Text(c.text, style: style), scale, width);
      expect(form, plain, reason: '$c $style x$scale in ${width}px');
    }
  });

  testWidgets('on a long word at every width and text scale, tapping the '
      'centre of any gap marks that gap on either line, and the check of a '
      'right tap stays inside the width', (tester) async {
    final rng = Random(4175);
    var broken = 0;
    for (var i = 0; i < 40; i++) {
      final text = i == 0 ? 'apportāminī' : drawLongForm(rng);
      final scale = formTextScales[rng.nextInt(formTextScales.length)];
      final width = formTextWidths[rng.nextInt(formTextWidths.length)];
      final style = drawFormTextStyle(rng);
      final letters = text.characters;
      final boundary = 1 + rng.nextInt(letters.length - 1);
      Future<RenderParagraph> pumpAs(StemMarking mode) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: FormText(
                    text: text,
                    split: boundary,
                    mode: mode,
                    onMark: mode == StemMarking.selbstMarkieren ? (_) {} : null,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
        );
        return _paragraph(tester);
      }

      Offset centreOf(RenderParagraph p, int k) {
        final pos = TextPosition(offset: letters.take(k).string.length);
        return p.localToGlobal(p.getOffsetForCaret(pos, Rect.zero)) +
            Offset(0, p.getFullHeightForCaret(pos) / 2);
      }

      final reason = '"$text" x$scale in ${width}px';
      var p = await pumpAs(StemMarking.frei);
      if (p.size.height >
          p.getFullHeightForCaret(const TextPosition(offset: 0))) {
        broken++;
      }
      for (var k = 1; k < letters.length; k++) {
        final centre = centreOf(p, k);
        await tester.tapAt(centre);
        await tester.pump();
        final bar = tester.getCenter(find.byKey(FormText.separatorKey));
        expect(
          (bar - centre).distance,
          lessThan(1.01),
          reason: '$reason gap $k',
        );
        await tester.tapAt(centre);
        await tester.pump();
        expect(find.byKey(FormText.separatorKey), findsNothing);
      }

      p = await pumpAs(StemMarking.selbstMarkieren);
      await tester.tapAt(centreOf(p, boundary));
      await tester.pumpAndSettle();
      final check = tester.getRect(find.byKey(FormText.confirmKey));
      expect(check.left, greaterThanOrEqualTo(0), reason: reason);
      expect(check.right, lessThanOrEqualTo(width + 0.5), reason: reason);
      expect(
        tester.getRect(find.byKey(FormText.textKey)).right,
        lessThanOrEqualTo(width + 0.5),
        reason: reason,
      );
    }
    expect(
      broken,
      greaterThan(0),
      reason: 'no drawn form broke over two lines',
    );
  });

  group('on a 320 px screen the gaps tile the word', () {
    Iterable<String> forms() sync* {
      yield 'puellarum';
      yield 'ab';
      final rng = Random(4171);
      for (var i = 0; i < 25; i++) {
        final text = drawFormTextCase(rng).text;
        if (text.characters.length >= 2) yield text;
      }
    }

    int nearest(List<double> xs, double x) {
      var best = 0;
      for (var k = 1; k < xs.length; k++) {
        if ((xs[k] - x).abs() < (xs[best] - x).abs()) best = k;
      }
      return best + 1;
    }

    bool tie(List<double> xs, double x) {
      final d = [for (final g in xs) (g - x).abs()]..sort();
      return d.length > 1 && d[1] - d[0] < 0.05;
    }

    void narrow(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('frei: every x of the word marks its nearest gap, every y of '
        'it marks', (tester) async {
      narrow(tester);
      for (final text in forms()) {
        await _pump(tester, (
          text: text,
          split: null,
          mode: StemMarking.frei,
        ), Brightness.light);
        final xs = _gapXs(tester, text);
        final box = tester.getRect(find.byType(FormText));
        final y = box.center.dy;
        Future<void> tapAndExpect(Offset at, int? gap) async {
          await tester.tapAt(at);
          await tester.pump();
          final bars = find.byKey(FormText.separatorKey);
          expect(bars, findsOneWidget, reason: '"$text" at $at marks nothing');
          if (gap != null) {
            expect(
              tester.getCenter(bars).dx,
              closeTo(xs[gap - 1], 1.01),
              reason: '"$text" at $at',
            );
          }
          await tester.tapAt(Offset(tester.getCenter(bars).dx, y));
          await tester.pump();
          expect(find.byKey(FormText.separatorKey), findsNothing);
        }

        for (var x = box.left + 0.3; x < box.right; x += 1.7) {
          await tapAndExpect(Offset(x, y), tie(xs, x) ? null : nearest(xs, x));
        }
        final mid = box.center.dx;
        for (final edgeY in [box.top + 0.5, box.bottom - 0.5]) {
          await tapAndExpect(
            Offset(mid, edgeY),
            tie(xs, mid) ? null : nearest(xs, mid),
          );
        }
      }
    });

    testWidgets('selbst markieren: every x of the word is right iff its '
        'nearest gap is the boundary', (tester) async {
      narrow(tester);
      final rng = Random(4172);
      final cases = <(String, int)>[('puellarum', 4)];
      for (final text in forms().skip(1).take(10)) {
        cases.add((text, 1 + rng.nextInt(text.characters.length - 1)));
      }
      for (final (text, split) in cases) {
        final c = (text: text, split: split, mode: StemMarking.selbstMarkieren);
        await _pump(tester, c, Brightness.light);
        final xs = _gapXs(tester, text);
        final box = tester.getRect(find.byType(FormText));
        for (var x = box.left + 0.3; x < box.right; x += 3.1) {
          if (tie(xs, x)) continue;
          await tester.pumpWidget(const SizedBox());
          final marks = await _pump(tester, c, Brightness.light);
          await tester.tapAt(Offset(x, box.center.dy));
          expect(marks, [
            nearest(xs, x) == split,
          ], reason: '"$text" split $split at $x');
        }
      }
    });
  });
}
