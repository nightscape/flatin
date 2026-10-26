import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

Future<void> _loadIcons() async {
  final loader = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await loader.load();
}

/// Pumps open chains with thumbs far apart; returns the chain ends, read
/// after each paint, and the widget's top left.
Future<(List<(Offset, Offset)> Function(), Offset)> _pumpOpenChains(
  WidgetTester tester, {
  required bool shelf,
}) async {
  var ends = <(Offset, Offset)>[];
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: romanTheme,
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 366,
            child: BookSliders(
              key: key,
              focus: BookFocus.idle,
              words: (from: 30, to: 45),
              grammar: (from: 2, to: 90),
              links: (left: false, right: false),
              shelf: shelf,
              onPaintChains: (e) => ends = e,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (() => ends, tester.getTopLeft(find.byKey(key)));
}

void main() {
  setUpAll(_loadIcons);

  for (final (left, shelf) in [
    for (final left in [true, false])
      for (final shelf in [false, true]) (left, shelf),
  ]) {
    final side = left ? 'left' : 'right';
    final look = shelf ? ' (shelf)' : '';
    testWidgets('tapping the symbol of the open $side chain closes it$look', (
      tester,
    ) async {
      final (ends, origin) = await _pumpOpenChains(tester, shelf: shelf);
      final (word, grammar) = ends()[left ? 0 : 1];
      expect(
        (word.dx - grammar.dx).abs(),
        greaterThan(44),
        reason: 'thumbs must be apart, so the symbol is away from both',
      );
      final symbol = origin + (word + grammar) / 2;

      // Near the target's edge on the grammar side, away from the word thumb.
      final towardsGrammar = (grammar.dx - word.dx).sign;
      await tester.tapAt(symbol + Offset(18 * towardsGrammar, -18));
      await tester.pumpAndSettle();

      final (closedWord, closedGrammar) = ends()[left ? 0 : 1];
      expect(closedGrammar.dx, moreOrLessEquals(closedWord.dx));
      expect(
        find.textContaining(
          left ? 'Grammatik L30–L90' : 'Grammatik L2–L45',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a mouse over the $side symbol shows the click cursor, a ring '
        'and what a click does$look', (tester) async {
      final (ends, origin) = await _pumpOpenChains(tester, shelf: shelf);
      final (word, grammar) = ends()[left ? 0 : 1];
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final ring = find.byKey(Key('chain.$side.hover'));
      MouseCursor cursor() =>
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;

      await mouse.moveTo(origin + (word + grammar) / 2 + const Offset(15, 15));
      await tester.pumpAndSettle();
      expect(cursor(), SystemMouseCursors.click);
      expect(ring, findsOneWidget);
      expect(find.text('Grenzen verbinden'), findsOneWidget);

      await mouse.moveTo(origin + Offset(word.dx, word.dy - 40));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(cursor(), isNot(SystemMouseCursors.click));
      expect(ring, findsNothing);
    });
  }
}
