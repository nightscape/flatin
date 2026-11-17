import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/settings.dart' show StemMarking;
import 'package:latin_practice/widgets/form_text.dart';

import 'support/gen_form_text.dart';

// Generators: drawFormTextCase (test/support/gen_form_text.dart): text of
// 0-12 letters over Latin/Greek/Cyrillic with macrons x split x mode, seeded
// loop with fixed cases first. Brightness and the taps are drawn in-test.

final _fixed = <FormTextCase>[
  (text: 'rosā', split: 3, mode: StemMarking.selbstMarkieren),
  (text: 'āmus', split: 2, mode: StemMarking.selbstMarkieren),
  (text: 'rosa', split: null, mode: StemMarking.selbstMarkieren),
  (text: 'ab', split: 1, mode: StemMarking.selbstMarkieren),
  (text: '', split: null, mode: StemMarking.zeigen),
  (text: 'a', split: null, mode: StemMarking.zeigen),
  (text: 'ωβα', split: 2, mode: StemMarking.zeigen),
  (text: 'rosarum', split: null, mode: StemMarking.zeigen),
  (text: 'puellārum', split: 6, mode: StemMarking.aus),
  (text: 'puellārum', split: null, mode: StemMarking.aus),
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
            onMark: marks.add,
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

/// The text after the coloured boundary, or null when nothing is coloured.
String? _colouredEnding(WidgetTester tester) {
  final root = _paragraph(tester).text as TextSpan;
  final inner = root.children?.single;
  if (inner is! TextSpan || inner.children!.length == 1) return null;
  final ending = inner.children!.last as TextSpan;
  final scheme = Theme.of(
    tester.element(find.byKey(FormText.textKey)),
  ).colorScheme;
  expect(ending.style?.color, scheme.tertiary);
  return ending.text;
}

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

double _textY(WidgetTester tester) =>
    tester.getCenter(find.byKey(FormText.textKey)).dy;

void main() {
  testWidgets('a form without taps shows the plain text, or with a split in '
      'zeigen the ending in a second colour in light and dark, and a tap '
      'changes nothing', (tester) async {
    final rng = Random(4180);
    for (final c in _cases().where((c) => tapsOf(c) == FormTextTaps.none)) {
      for (final b in Brightness.values) {
        final marks = await _pump(tester, c, b);
        final reason = '$c $b';
        final shows = c.mode == StemMarking.zeigen && c.split != null;
        void expectShown() {
          expect(_plain(tester), c.text, reason: reason);
          expect(
            find.byKey(FormText.separatorKey),
            shows ? findsOneWidget : findsNothing,
            reason: reason,
          );
          expect(
            _colouredEnding(tester),
            shows ? c.text.characters.skip(c.split!).string : null,
            reason: reason,
          );
          if (!shows) return;
          expect(
            _separatorX(tester),
            closeTo(_gapXs(tester, c.text)[c.split! - 1], 1.01),
            reason: reason,
          );
        }

        expectShown();
        if (c.text.isEmpty) continue;
        final box = tester.getRect(find.byKey(FormText.textKey));
        await tester.tapAt(
          box.topLeft +
              Offset(
                rng.nextDouble() * box.width,
                rng.nextDouble() * box.height,
              ),
        );
        await tester.pumpAndSettle();
        expectShown();
        expect(marks, isEmpty, reason: reason);
        expect(find.byKey(FormText.confirmKey), findsNothing, reason: reason);
      }
    }
  });

  testWidgets('free marking: the mark sits at the last tapped gap, a tap on '
      'the marked gap removes it, nothing is checked', (tester) async {
    final rng = Random(417);
    for (final c in _cases().where((c) => tapsOf(c) == FormTextTaps.free)) {
      final b = Brightness.values[rng.nextInt(2)];
      final marks = await _pump(tester, c, b);
      final reason = '$c $b';
      final letters = c.text.characters;
      expect(_plain(tester), c.text, reason: reason);
      expect(find.byKey(FormText.separatorKey), findsNothing, reason: reason);
      final y = _textY(tester);
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
          expect(_colouredEnding(tester), isNull, reason: step);
        } else {
          expect(find.byKey(FormText.separatorKey), findsOneWidget);
          expect(_separatorX(tester), closeTo(xs[mark - 1], 1.01));
          expect(_colouredEnding(tester), letters.skip(mark).string);
        }
        expect(find.byKey(FormText.confirmKey), findsNothing, reason: step);
      }
      expect(marks, isEmpty, reason: reason);
    }
  });

  testWidgets('selbst markieren on a split form: taps and drags place and '
      'move one bar unchecked; the confirm reports right iff the bar is on '
      'the boundary and glides it there; then nothing changes', (tester) async {
    final rng = Random(4160);
    for (final c in _cases().where((c) => tapsOf(c) == FormTextTaps.checked)) {
      final b = Brightness.values[rng.nextInt(2)];
      final marks = await _pump(tester, c, b);
      final reason = '$c $b';
      final letters = c.text.characters;
      final xs = _gapXs(tester, c.text);
      final y = _textY(tester);
      int? mark;
      for (final (i, g) in drawGapTaps(rng, letters.length).indexed) {
        final from = mark;
        final drag =
            from != null && (xs[g - 1] - xs[from - 1]).abs() > 24 && i.isOdd;
        if (drag) {
          await tester.dragFrom(
            Offset(xs[from - 1], y),
            Offset(xs[g - 1] - xs[from - 1], 0),
          );
          mark = g;
        } else {
          await tester.tapAt(Offset(xs[g - 1], y));
          mark = mark == g ? null : g;
        }
        await tester.pump();
        final step = '$reason ${drag ? 'drag' : 'tap'} $g';
        expect(marks, isEmpty, reason: '$step: nothing checked before confirm');
        expect(_plain(tester), c.text, reason: step);
        if (mark == null) {
          expect(find.byKey(FormText.separatorKey), findsNothing, reason: step);
          expect(find.byKey(FormText.confirmKey), findsNothing, reason: step);
        } else {
          expect(_separatorX(tester), closeTo(xs[mark - 1], 1.01));
          expect(_colouredEnding(tester), letters.skip(mark).string);
          final confirm = tester.getSize(find.byKey(FormText.confirmKey));
          expect(confirm.width, greaterThanOrEqualTo(48), reason: step);
          expect(confirm.height, greaterThanOrEqualTo(48), reason: step);
        }
      }
      if (mark == null) {
        await tester.tapAt(Offset(xs[0], y));
        await tester.pump();
        mark = 1;
      }
      await tester.tap(find.byKey(FormText.confirmKey));
      expect(marks, [mark == c.split], reason: reason);
      await tester.pump();
      expect(_separatorX(tester), closeTo(xs[mark - 1], 1.01), reason: reason);
      await tester.pumpAndSettle();
      void expectSettled() {
        expect(find.byKey(FormText.separatorKey), findsOneWidget);
        expect(
          _separatorX(tester),
          closeTo(xs[c.split! - 1], 1.01),
          reason: '$reason the bar rests on the boundary',
        );
        expect(_colouredEnding(tester), letters.skip(c.split!).string);
        expect(find.byKey(FormText.confirmKey), findsNothing, reason: reason);
        expect(
          find.byKey(FormText.checkKey),
          mark == c.split ? findsOneWidget : findsNothing,
          reason: reason,
        );
        expect(_plain(tester), c.text, reason: reason);
      }

      expectSettled();
      await tester.tapAt(Offset(xs[letters.length - 2], y));
      await tester.pumpAndSettle();
      expect(marks.length, 1, reason: '$reason one mark per form');
      expectSettled();
    }
  });

  testWidgets('untapped, a form takes exactly the layout size of the plain '
      'text at every text scale and width', (tester) async {
    final rng = Random(4173);
    final cases = <FormTextCase>[
      for (final mode in StemMarking.values) ...[
        (text: 'puellarum', split: null, mode: mode),
        (text: 'puellarum', split: 4, mode: mode),
        (text: 'ab', split: 1, mode: mode),
        (text: 'apportāminī', split: 4, mode: mode),
      ],
      for (var i = 0; i < 60; i++) drawFormTextCase(rng),
      for (var i = 0; i < 30; i++)
        (
          text: drawLongForm(rng),
          split: rng.nextBool() ? null : 3,
          mode: StemMarking.values[rng.nextInt(StemMarking.values.length)],
        ),
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
          onMark: (_) {},
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
      'centre of any gap marks that gap on either line in each mode that '
      'takes taps, and the confirm and the check stay inside the width', (
    tester,
  ) async {
    final rng = Random(4175);
    var broken = 0;
    for (var i = 0; i < 40; i++) {
      final text = i == 0 ? 'apportāminī' : drawLongForm(rng);
      final scale = formTextScales[rng.nextInt(formTextScales.length)];
      final width = formTextWidths[rng.nextInt(formTextWidths.length)];
      final style = drawFormTextStyle(rng);
      final letters = text.characters;
      final boundary = 1 + rng.nextInt(letters.length - 1);
      Future<RenderParagraph> pumpAs(FormTextCase c) async {
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
                    key: ValueKey(c),
                    text: c.text,
                    split: c.split,
                    mode: c.mode,
                    onMark: (_) {},
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
      for (final c in <FormTextCase>[
        (text: text, split: null, mode: StemMarking.zeigen),
        (text: text, split: null, mode: StemMarking.selbstMarkieren),
        (text: text, split: boundary, mode: StemMarking.selbstMarkieren),
      ]) {
        final p = await pumpAs(c);
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
            reason: '$reason $c gap $k',
          );
          if (c.split != null) {
            final confirm = tester.getRect(find.byKey(FormText.confirmKey));
            expect(confirm.left, greaterThanOrEqualTo(0), reason: reason);
            expect(
              confirm.right,
              lessThanOrEqualTo(width + 0.5),
              reason: reason,
            );
          }
          await tester.tapAt(centre);
          await tester.pump();
          expect(find.byKey(FormText.separatorKey), findsNothing);
        }
      }

      await tester.tapAt(centreOf(_paragraph(tester), boundary));
      await tester.pump();
      await tester.tap(find.byKey(FormText.confirmKey));
      await tester.pumpAndSettle();
      final check = tester.getRect(find.byKey(FormText.checkKey));
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
      yield 'rēд';
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

    testWidgets('in each mode that takes taps, every x of the word places '
        'the bar on its nearest gap, every y of it places', (tester) async {
      narrow(tester);
      final rng = Random(4174);
      for (final text in forms()) {
        final c = <FormTextCase>[
          (text: text, split: null, mode: StemMarking.zeigen),
          (text: text, split: null, mode: StemMarking.selbstMarkieren),
          (
            text: text,
            split: 1 + rng.nextInt(text.characters.length - 1),
            mode: StemMarking.selbstMarkieren,
          ),
        ][rng.nextInt(3)];
        await _pump(tester, c, Brightness.light);
        final xs = _gapXs(tester, text);
        final box = tester.getRect(find.byType(FormText));
        final y = box.center.dy;
        Future<void> tapAndExpect(Offset at, int? gap) async {
          await tester.tapAt(at);
          await tester.pump();
          final bars = find.byKey(FormText.separatorKey);
          expect(bars, findsOneWidget, reason: '$c at $at marks nothing');
          if (gap != null) {
            expect(
              tester.getCenter(bars).dx,
              closeTo(xs[gap - 1], 1.01),
              reason: '$c at $at',
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

    testWidgets('selbst markieren: every x of the word, confirmed, is right '
        'iff its nearest gap is the boundary', (tester) async {
      narrow(tester);
      final rng = Random(4172);
      final cases = <(String, int)>[('puellarum', 4)];
      for (final text in forms().skip(1).take(11)) {
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
          await tester.pump();
          await tester.tap(find.byKey(FormText.confirmKey));
          expect(marks, [
            nearest(xs, x) == split,
          ], reason: '"$text" split $split at $x');
        }
      }
    });
  });
}
