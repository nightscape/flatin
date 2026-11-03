import 'dart:math';

import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';

/// Any tick set of [answer]: each option ticked with chance 1/2, at least one.
TickedOptions drawTicks(Random rng, TickAnswer answer) {
  while (true) {
    final ticked = {
      for (var i = 0; i < answer.options.length; i++)
        if (rng.nextBool()) i,
    };
    if (ticked.isNotEmpty) return TickedOptions(ticked);
  }
}

/// Any placement of the pills of [answer]: each pill on any word, so two
/// pills may share one.
MarksResponse drawMarks(Random rng, MarksAnswer answer) => MarksResponse([
  for (final _ in answer.pills) rng.nextInt(answer.words.length),
]);

/// [sentence] shown with 3..8 options, k of them right with 2k <= n, the
/// others with any mistake, in drawn order.
TickAnswer drawTickAnswer(Random rng, Sentence sentence) {
  final n = 3 + rng.nextInt(6);
  final k = 1 + rng.nextInt(n ~/ 2);
  return TickAnswer(
    sentence,
    [
      for (var i = 0; i < n; i++)
        (
          text: 'option $i',
          mistake: i < k
              ? null
              : Mistake.values[rng.nextInt(Mistake.values.length)],
        ),
    ]..shuffle(rng),
  );
}

/// A sentence of 2..8 words with 1..min(4, words) pills on distinct words.
MarksAnswer drawMarksAnswer(Random rng) {
  final words = 2 + rng.nextInt(7);
  final marked = ([
    for (var w = 0; w < words; w++) w,
  ]..shuffle(rng)).take(1 + rng.nextInt(min(4, words)));
  return MarksAnswer(
    'drawn',
    [for (var w = 0; w < words; w++) 'w$w'],
    [for (final (i, w) in marked.indexed) (role: 'role $i', word: w)],
    const FormOption(text: 'w0', formKey: 'nom.sg', lexemeId: 'drawn'),
  );
}
