import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

/// Heights on the shelf: the grammar ribbon below the word ribbon's end,
/// the bow knot, and the word ribbon above the bow.
const _redY = 140.0, _bowY = 82.0, _goldY = 56.0;

class _Shelf {
  _Shelf(this.tester);

  final WidgetTester tester;
  late BookScale scale;

  /// Words L30–L45, grammar L2–L90, nothing tied.
  Future<void> pump() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: romanTheme,
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 366,
              child: BookSliders(
                focus: BookFocus.idle,
                words: (from: 30, to: 45),
                grammar: (from: 2, to: 90),
                links: (left: false, right: false),
                shelf: true,
                bow: true,
                onScale: (s) => scale = s,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drags from [lesson] at height [y] to lesson [to], following the scale
  /// as books open, and releases.
  Future<void> drag(int lesson, double y, int to) async {
    final origin = tester.getTopLeft(find.byKey(const Key('shelf.grip')));
    final from = scale.x(lesson);
    final gesture = await tester.startGesture(origin + Offset(from, y));
    for (var i = 1; i <= 20; i++) {
      await gesture.moveTo(
        origin + Offset(from + (scale.x(to) - from) * i / 20, y),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 5; i++) {
      await tester.pumpAndSettle();
      await gesture.moveTo(origin + Offset(scale.x(to), y));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Presses the mouse 6 px right of [lesson] at height [y], moves it 2 px
  /// and lets go.
  Future<void> click(int lesson, double y) async {
    final origin = tester.getTopLeft(find.byKey(const Key('shelf.grip')));
    final gesture = await tester.startGesture(
      origin + Offset(scale.x(lesson) + 6, y),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(2, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  void expectRanges(String words, String grammar) {
    expect(find.text('Wörter $words'), findsOneWidget);
    expect(find.text('Grammatik $grammar'), findsOneWidget);
  }
}

void main() {
  testWidgets('a ribbon dropped on its partner ties; the bow moves both', (
    tester,
  ) async {
    final shelf = _Shelf(tester);
    await shelf.pump();
    await shelf.drag(2, _redY, 30);
    shelf.expectRanges('L30–L45', 'L30–L90');
    await shelf.drag(30, _bowY, 35);
    shelf.expectRanges('L35–L45', 'L35–L90');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('dropping next to the partner ties nothing', (tester) async {
    final shelf = _Shelf(tester);
    await shelf.pump();
    await shelf.drag(2, _redY, 29);
    await shelf.drag(30, _goldY, 35);
    shelf.expectRanges('L35–L45', 'L29–L90');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('dragging one ribbon out of its bow unties it', (tester) async {
    final shelf = _Shelf(tester);
    await shelf.pump();
    await shelf.drag(2, _redY, 30);
    await shelf.drag(30, _goldY, 37);
    shelf.expectRanges('L37–L45', 'L30–L90');
    await shelf.drag(37, _goldY, 30);
    await shelf.drag(30, _redY, 25);
    shelf.expectRanges('L30–L45', 'L25–L90');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('clicking a ribbon of a bow keeps the bow', (tester) async {
    final shelf = _Shelf(tester);
    await shelf.pump();
    await shelf.drag(2, _redY, 30);
    await shelf.click(30, _goldY);
    await shelf.drag(30, _bowY, 35);
    shelf.expectRanges('L35–L45', 'L35–L90');
    await tester.pump(const Duration(seconds: 4));
  });
}
