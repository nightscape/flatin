import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_cube.dart' show View;
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';

import 'support/course_providers.dart';

/// A recognition kind that asks a sentence, so a fresh card tries it first.
const _sentenceKind = SpecGenerator(
  KindSpec(
    kind: ExerciseKind.bestimmen,
    questionKey: 'q',
    select: OneSentence(),
    params: {},
    answer: Choose(View.latin, from: TheSelection(), count: 2),
  ),
);

/// A building kind that fits every pair, tried after [_sentenceKind].
class _Fallback implements ExerciseGenerator {
  const _Fallback();

  @override
  ExerciseKind get kind => ExerciseKind.formBilden;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final form = FormOption(
      text: 'x',
      formKey: word.formOrder.first,
      lexemeId: word.id,
    );
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'q',
      answer: TypedAnswer(form, ['x']),
    );
  }
}

ProviderContainer _container(List<ExerciseGenerator> registry, int seed) {
  final c = ProviderContainer(
    retry: noRetry,
    overrides: [
      dataLanguageProvider.overrideWith((ref) => 'de'),
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      exerciseRegistryProvider.overrideWithValue(registry),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('at lesson 25 with only the words of the sentences on, every noun '
      'task asks a sentence that holds its own cell', () async {
    final corpus = await loadSentenceCorpus();
    final inSentences = {
      for (final s in corpus.sentences)
        if (s.lesson <= 25)
          for (final t in s.tokens.whereType<FormToken>()) t.lemma,
    };
    seedSettings(
      Settings(
        courseWords: LessonRange(1, 25),
        deselectedWords: {
          for (final w in await loadAllPracticeItems())
            if (!inSentences.contains(w.lemma)) w.lemma,
        },
      ),
    );
    final c = _container([_sentenceKind, const _Fallback()], 0);
    final tasks = (await c.read(
      roundProvider(const MixedRound(FileFocus('nouns'))).future,
    )).queue;
    expect(tasks, isNotEmpty);
    for (final task in tasks) {
      expect(task.exercise.kind, _sentenceKind.kind, reason: task.word.id);
      final right = (task.exercise.answer as ChoiceAnswer).right;
      expect(right.lexemeId, task.word.id);
      expect(bundleOf(task.word, right.formKey), task.bundle);
    }
  });

  test('a learner at lesson 1 gets no sentence: the build names the '
      'reached lesson', () async {
    seedSettings(Settings(courseWords: LessonRange(1, 1)));
    final c = _container([_sentenceKind], 0);
    await expectLater(
      c.read(roundProvider(const MixedRound(FileFocus('verbs'))).future),
      throwsA(
        isA<AssertionError>().having(
          (e) => e.message,
          'message',
          contains('bestimmen: no sentence up to lesson 1)'),
        ),
      ),
    );
  });
}
