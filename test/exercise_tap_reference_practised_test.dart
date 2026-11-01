import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';

import 'support/exercise_fakes.dart';
import 'support/gen_sentence_learner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a marking never rates a switched-off reference form', () async {
    final corpus = await loadSentenceCorpus();
    final items = await loadAllPracticeItems();
    final generator = generatorFor(ExerciseKind.markieren, exerciseGenerators);
    final unlocked = {
      for (final w in items)
        for (final k in w.formOrder) bundleOf(w, k),
    };
    final asked = <String>[];
    for (final s in corpus.sentences) {
      if (s.construction.reference == null) continue;
      final t = s.tokens[s.construction.reference!] as FormToken;
      final word = itemOfToken(items, t);
      final ctx = ExerciseContext(
        unlocked: unlocked,
        pool: items,
        german: fakeExerciseContext().german,
        sentences: corpus,
        reachedLesson: laterLesson,
        formPracticed: (w, l) => !(w.id == word.id && l.key == t.key),
      );
      for (var seed = 0; seed < 5; seed++) {
        try {
          final e = generator.build(
            word,
            bundleOf(word, t.key),
            ctx,
            Random(seed),
          );
          final target = (e.answer as MarksAnswer).target;
          if (target.formKey == t.key) asked.add('${s.id}: ${t.key}');
        } on CannotBuild {
          break;
        }
      }
    }
    expect(asked, isEmpty);
  });
}
