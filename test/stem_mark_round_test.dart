import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/grammar_start_screen.dart';
import 'package:latin_practice/screens/round_end_screen.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:latin_practice/widgets/form_text.dart';

import 'support/course_providers.dart';
import 'support/key_echo_app.dart';
import 'support/latin_course.dart' show latinLastLesson;
import 'support/round_driver.dart';
import 'support/word_classification_harness.dart';

typedef _Run = ({
  List<String> tasks,
  List<String> end,
  Map<String, String> cards,
});

/// Plays one round in selbst markieren with the answers [right]; with [marks]
/// it first marks and confirms every split form of each task at a drawn gap.
Future<(_Run, int)> _play(
  WidgetTester tester,
  int seed,
  LessonRange words,
  List<bool> right,
  Random? marks,
) async {
  seedSettings(
    Settings(
      lastLesson: latinLastLesson,
      courseWords: words,
      stemMarking: StemMarking.selbstMarkieren,
    ),
  );
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    wrapInKeyEchoAppWith(
      const GrammarStartScreen(),
      overrides: [exerciseRandomProvider.overrideWithValue(Random(seed))],
    ),
  );
  await letItLoad(tester);
  await tap(tester, 'round.start.go');
  await letItLoad(tester);
  final tasks = <String>[];
  for (var n = 0; find.byType(RoundEndScreen).evaluate().isEmpty; n++) {
    final e = shown(tester);
    tasks.add('${e.kind.name} ${e.wordCardId} ${e.questionParams}');
    if (marks != null) {
      for (final el in find.byType(FormText).evaluate().toList()) {
        final form = el.widget as FormText;
        if (form.split == null) continue;
        final box = tester.getRect(find.byWidget(form));
        await tester.tapAt(
          Offset(box.left + box.width * marks.nextDouble(), box.center.dy),
        );
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byWidget(form),
            matching: find.byKey(FormText.confirmKey),
          ),
        );
        await tester.pump();
      }
    }
    await answer(tester, e, right: right[n % right.length]);
    await letItLoad(tester);
  }
  final end = [
    for (final t in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(RoundEndScreen),
        matching: find.byType(Text),
      ),
    ))
      t.data ?? t.textSpan!.toPlainText(),
  ];
  final stored = (await tester.runAsync(FsrsStorage.loadCards))!;
  return (
    (
      tasks: tasks,
      end: end,
      cards: {
        for (final MapEntry(key: id, value: c) in stored.entries)
          if (!StemCardId.isStemCard(id))
            id:
                '${c.card.state} ${c.card.step} ${c.card.stability} '
                '${c.card.difficulty} ${c.lastReview != null}',
      },
    ),
    stored.keys.where(StemCardId.isStemCard).length,
  );
}

void main() {
  testWidgets('confirmed stem marks change no task, grade, coin, reward or '
      'other card of a round', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var stemCards = 0;
    final rng = Random(4182);
    for (var i = 0; i < 3; i++) {
      final seed = rng.nextInt(1000);
      final words = LessonRange(1, [1, 5, 12][rng.nextInt(3)]);
      final right = [for (var k = 0; k < 7; k++) rng.nextInt(3) > 0];
      final reason = 'seed $seed words $words right $right';
      final (plain, noStems) = await _play(tester, seed, words, right, null);
      expect(noStems, 0, reason: reason);
      final (marked, stems) = await _play(
        tester,
        seed,
        words,
        right,
        Random(rng.nextInt(1000)),
      );
      stemCards += stems;
      expect(marked.tasks, plain.tasks, reason: reason);
      expect(marked.end, plain.end, reason: reason);
      expect(marked.cards, plain.cards, reason: reason);
    }
    expect(stemCards, greaterThan(0), reason: 'no drawn round marked a stem');
  });
}
