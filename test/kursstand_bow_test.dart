import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/kursstand_shelf_driver.dart';
import 'support/kursstand_sliders_harness.dart';

/// Words L25–L35, grammar L2–L38, nothing tied.
Future<SlidersProbe> _apart(WidgetTester tester) => pumpSliders(
  tester,
  words: LessonRange(25, 35),
  grammar: LessonRange(2, 38),
  from: false,
  to: false,
);

/// Drags the gold ribbon of the word start at the top of its page, above
/// any bow, onto [to].
Future<void> _dragGold(WidgetTester tester, int to) async {
  final from = shelfPainter(tester).words.from;
  final gesture = await tester.startGesture(shelfAt(tester, from, 56));
  for (var i = 1; i <= 20; i++) {
    final x =
        shelfX(tester, from) +
        (shelfX(tester, to) - shelfX(tester, from)) * i / 20;
    await gesture.moveTo(Offset(x, shelfAt(tester, from, 56).dy));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
  await gesture.moveTo(shelfAt(tester, to, 56));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a ribbon dropped on its partner ties; the bow moves both', (
    tester,
  ) async {
    final probe = await _apart(tester);
    await dragBound(tester, words: false, start: true, to: 25);
    expect(probe.settings.grammarFromLinked, isTrue);
    expect(probe.settings.courseGrammar, LessonRange(25, 38));

    await dragBound(tester, words: true, start: true, to: 28);
    expect(probe.settings.courseWords, LessonRange(28, 35));
    expect(probe.settings.courseGrammar, LessonRange(28, 38));
    expect(probe.settings.grammarFromLinked, isTrue);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('dropping next to the partner ties nothing', (tester) async {
    final probe = await _apart(tester);
    await dragBound(tester, words: false, start: true, to: 24);
    await dragBound(tester, words: true, start: true, to: 28);
    expect(probe.settings.courseWords, LessonRange(28, 35));
    expect(probe.settings.courseGrammar, LessonRange(24, 38));
    expect(probe.settings.grammarFromLinked, isFalse);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('dragging one ribbon out of its bow unties it; dropping it '
      'back ties again', (tester) async {
    final probe = await _apart(tester);
    await dragBound(tester, words: false, start: true, to: 25);

    await _dragGold(tester, 30);
    expect(probe.settings.courseWords, LessonRange(30, 35));
    expect(probe.settings.courseGrammar, LessonRange(25, 38));
    expect(probe.settings.grammarFromLinked, isFalse);

    await _dragGold(tester, 25);
    expect(probe.settings.grammarFromLinked, isTrue);

    await dragBound(tester, words: false, start: true, to: 22);
    expect(probe.settings.courseWords, LessonRange(25, 35));
    expect(probe.settings.courseGrammar, LessonRange(22, 38));
    expect(probe.settings.grammarFromLinked, isFalse);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a mouse click beside the middle of a tied ribbon keeps the '
      'bow', (tester) async {
    final probe = await _apart(tester);
    await dragBound(tester, words: false, start: true, to: 25);
    final before = probe.settings;

    final mouse = await tester.startGesture(
      shelfAt(tester, 25, 56) + const Offset(6, 0),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(2, 0));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();

    expect(probe.settings.toJson(), before.toJson());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('dragging the grammar ribbon of a bow unties only that bound', (
    tester,
  ) async {
    final probe = await pumpSliders(
      tester,
      words: LessonRange(25, 32),
      grammar: LessonRange(25, 32),
      from: true,
      to: true,
    );
    await dragBound(tester, words: false, start: false, to: 36);

    expect(probe.settings.grammarToLinked, isFalse);
    expect(probe.settings.grammarFromLinked, isTrue);
    expect(probe.settings.courseGrammar, LessonRange(25, 36));
    expect(probe.settings.courseWords, LessonRange(25, 32));
    await tester.pump(const Duration(seconds: 4));
  });
}
