import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/app_fonts.dart';
import 'support/kursstand_sliders_harness.dart';

/// Open chains with each word thumb far from its grammar thumb.
Future<SlidersProbe> _openChains(WidgetTester tester) => pumpSliders(
  tester,
  words: LessonRange(25, 32),
  grammar: LessonRange(2, 40),
  from: false,
  to: false,
);

void main() {
  setUpAll(loadAppFonts);

  for (final left in [true, false]) {
    final side = left ? 'left' : 'right';
    testWidgets('tapping the symbol of the open $side chain closes it', (
      tester,
    ) async {
      final probe = await _openChains(tester);
      final (word, symbol, grammar) = probe.chains[left ? 0 : 1];
      expect(
        (word.dx - grammar.dx).abs(),
        greaterThan(44),
        reason: 'thumbs must be apart, so the symbol is away from both',
      );
      // Near the target's edge on the grammar side, away from the word thumb.
      final towardsGrammar = (grammar.dx - word.dx).sign;
      await tester.tapAt(
        probe.origin(tester) + symbol + Offset(18 * towardsGrammar, -18),
      );
      await tester.pumpAndSettle();

      final (closedWord, _, closedGrammar) = probe.chains[left ? 0 : 1];
      expect(closedGrammar.dx, moreOrLessEquals(closedWord.dx));
      expect(
        probe.settings.courseGrammar,
        left ? LessonRange(25, 40) : LessonRange(2, 32),
      );
      expect(probe.settings.grammarFromLinked, left);
      expect(probe.settings.grammarToLinked, !left);
    });

    testWidgets('a mouse over the $side symbol shows the click cursor, a ring '
        'and what a click does', (tester) async {
      final probe = await _openChains(tester);
      final (word, symbol, _) = probe.chains[left ? 0 : 1];
      final origin = probe.origin(tester);
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final ring = find.byKey(const Key('kursstand.chain.hover'));
      MouseCursor cursor() =>
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;

      await mouse.moveTo(origin + symbol + const Offset(15, 15));
      await tester.pumpAndSettle();
      expect(cursor(), SystemMouseCursors.click);
      expect(ring, findsOneWidget);
      expect(find.text('Grenzen verbinden'), findsOneWidget);

      await mouse.moveTo(origin + Offset(word.dx, word.dy - 40));
      await tester.pumpAndSettle();
      expect(cursor(), isNot(SystemMouseCursors.click));
      expect(ring, findsNothing);
    });
  }

  testWidgets('dragging the grammar thumb of a closed chain opens it', (
    tester,
  ) async {
    final probe = await pumpSliders(
      tester,
      words: LessonRange(25, 32),
      grammar: LessonRange(25, 32),
      from: true,
      to: true,
    );
    final origin = probe.origin(tester);
    final y = probe.y(tester, words: false);
    final gesture = await tester.startGesture(
      origin + Offset(probe.scale.x(32), y),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveTo(origin + Offset(probe.scale.x(36), y));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(probe.settings.grammarToLinked, isFalse);
    expect(probe.settings.grammarFromLinked, isTrue);
    expect(probe.settings.courseGrammar.to, greaterThan(32));
    expect(probe.settings.courseWords, LessonRange(25, 32));
  });

  for (final range in [LessonRange(25, 25), LessonRange(25, 27)]) {
    testWidgets('with words and grammar on $range both chains can be '
        'toggled', (tester) async {
      final probe = await pumpSliders(
        tester,
        words: range,
        grammar: range,
        from: true,
        to: true,
      );
      final (_, left, _) = probe.chains[0];
      final (_, right, _) = probe.chains[1];
      expect((right.dx - left.dx).abs(), greaterThanOrEqualTo(44));

      await tester.tapAt(probe.origin(tester) + left);
      await tester.pumpAndSettle();
      expect(probe.settings.grammarFromLinked, isFalse);
      expect(probe.settings.grammarToLinked, isTrue);

      await tester.tapAt(probe.origin(tester) + right);
      await tester.pumpAndSettle();
      expect(probe.settings.grammarFromLinked, isFalse);
      expect(probe.settings.grammarToLinked, isFalse);
    });
  }
}
