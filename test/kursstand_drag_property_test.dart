// Property: during any drag on the shelf, in every frame, the dragged bound
// sits on the lesson under the finger as far as its range allows, also
// while books change width, and a tied bound has its grammar on its words.
// A ribbon let go on its partner's lesson is tied.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/kursstand_shelf_driver.dart';
import 'support/kursstand_sliders_harness.dart';

const _cases = int.fromEnvironment('CASES', defaultValue: 40);
const _seed = int.fromEnvironment('SEED', defaultValue: 1);

LessonRange _range(Random rng) {
  final a = 1 + rng.nextInt(laterLesson), b = 1 + rng.nextInt(laterLesson);
  return LessonRange(min(a, b), max(a, b));
}

void main() {
  testWidgets('the dragged bound follows the finger in every frame', (
    tester,
  ) async {
    var checks = 0;
    for (var c = 0; c < _cases; c++) {
      final rng = Random(_seed + c);
      final probe = await pumpSliders(
        tester,
        words: _range(rng),
        grammar: _range(rng),
        from: rng.nextBool(),
        to: rng.nextBool(),
      );
      final origin = probe.origin(tester).dx;
      for (var d = 1 + rng.nextInt(3); d > 0; d--) {
        final words = rng.nextBool(), start = rng.nextBool();
        final grip = shelfGrip(tester, words: words, start: start);
        final r0 = words
            ? probe.settings.courseWords
            : probe.settings.courseGrammar;
        // Two ribbons of one kind on one lesson: the finger takes the start.
        if (r0.from == r0.to) continue;
        final why = 'seed ${_seed + c}, drag $d, words $words, start $start';
        final gesture = await tester.startGesture(grip);
        var x = grip.dx + (rng.nextBool() ? 20 : -20);
        await gesture.moveTo(Offset(x, grip.dy));
        for (var step = 5 + rng.nextInt(25); step > 0; step--) {
          x += switch (rng.nextInt(3)) {
            0 => rng.nextDouble() * 4 - 2,
            1 => rng.nextDouble() * 30 - 15,
            _ => rng.nextDouble() * 120 - 60,
          };
          await gesture.moveTo(Offset(x, grip.dy));
          await tester.pump(Duration(milliseconds: rng.nextInt(40)));
          final scale = probe.scale;
          final finger = scale.lessonAt(
            (x - origin).clamp(scale.left, scale.left + 1e9),
          );
          final now = probe.shown(tester);
          final r = words ? now.courseWords : now.courseGrammar;
          expect(
            start ? r.from : r.to,
            start ? min(finger, r.to) : max(finger, r.from),
            reason: why,
          );
          for (final (linked, w, g) in [
            (
              now.grammarFromLinked,
              now.courseWords.from,
              now.courseGrammar.from,
            ),
            (now.grammarToLinked, now.courseWords.to, now.courseGrammar.to),
          ]) {
            if (linked) expect(g, w, reason: why);
          }
          checks++;
        }
        await gesture.up();
        await tester.pumpAndSettle();
        final end = probe.settings;
        final (w, g) = start
            ? (end.courseWords.from, end.courseGrammar.from)
            : (end.courseWords.to, end.courseGrammar.to);
        if (w == g) {
          expect(
            start ? end.grammarFromLinked : end.grammarToLinked,
            isTrue,
            reason: '$why: let go on the partner',
          );
        }
      }
      await tester.pump(const Duration(seconds: 4));
    }
    expect(checks, greaterThan(_cases * 10));
  });
}
