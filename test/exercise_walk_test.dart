import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/exercise_interpreter.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/exercise_spec.dart' show OneSentence;
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/grammar_exercise_harness.dart';
import 'support/latin_course.dart';

const _firstLesson = 21;
const _wordsPerBundle = 2;

void _answer(PracticeItem word, Exercise exercise) {
  final (right, wrong) = rightAndWrong(word, exercise);
  expect(attribute(word, exercise, right), (
    word: Rating.good,
    grammar: Rating.good,
  ), reason: '${exercise.kind} of ${word.id}');
  final rating = attribute(word, exercise, wrong);
  // A marking with one of its pills wrong, or one wrong tick beside a single
  // right one, rates Hard, not Again.
  expect(
    exercise.answer is MarksAnswer || exercise.answer is TickAnswer
        ? !isRight(rating)
        : rating.word == Rating.again || rating.grammar == Rating.again,
    isTrue,
    reason: 'a wrong ${exercise.kind} of ${word.id} blames no card',
  );
}

/// Asks [inner] in [ctx], whatever context the caller passes, as the round
/// asks a sentence kind in the context over every file.
final class _InContext implements ExerciseGenerator {
  const _InContext(this.inner, this.ctx);

  final ExerciseGenerator inner;
  final ExerciseContext ctx;

  @override
  ExerciseKind get kind => inner.kind;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext _,
    Random rng,
  ) => inner.build(word, bundle, ctx, rng);
}

void main() {
  late List<PracticeItem> items;
  late Curriculum curriculum;
  late LessonData lessons;
  late GermanForms german;
  late SentenceCorpus corpus;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    items = await loadAllPracticeItems();
    corpus = await loadSentenceCorpus();
    curriculum = await loadCurriculum(latinCourse.books);
    lessons = await loadLessonData(latinCourse.books);
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    german = await container.read(germanFormsProvider.future);
    container.dispose();
  });

  CourseFilter filterAt(int lesson) => CourseFilter(
    Settings(courseWords: LessonRange(1, lesson)),
    curriculum,
    lessons,
  );

  test('every bundle a course position from lesson $_firstLesson on unlocks '
      'builds an exercise in every kind that fits, and both answers rate', () {
    final rng = Random(139);
    final built = <ExerciseKind>{};
    for (final dataFileId in ['nouns', 'verbs']) {
      final ofFile = items.where((i) => i.dataFileId == dataFileId).toList();
      var seen = <GrammarBundle>{};
      for (var lesson = _firstLesson; lesson <= lastLesson; lesson++) {
        final filter = filterAt(lesson);
        final pool = ofFile.where(filter.reachesPractice).toList();
        final unlocked = unlockedBundles(filter, pool);
        final ctx = ExerciseContext(
          unlocked: unlocked,
          pool: pool,
          german: german,
        );
        final everyFile = items.where(filter.reachesPractice).toList();
        final acrossFiles = ExerciseContext(
          unlocked: unlockedBundles(filter, everyFile),
          pool: everyFile,
          german: german,
          sentences: corpus,
          reachedLesson: reachedLesson(filter.settings),
        );
        ExerciseContext contextOf(ExerciseGenerator g) =>
            g is SpecGenerator && g.spec.select is OneSentence
            ? acrossFiles
            : ctx;
        for (final bundle in unlocked.difference(seen)) {
          final words = pool.where(
            (w) => unlockedBundles(filter, [w]).contains(bundle),
          );
          bool covered(PracticeItem w) => w.formOrder.any(
            (key) => bundleOf(w, key) == bundle && german.covers(w, key),
          );
          // The few words with German text in this bundle all go in, so the
          // German kinds meet every bundle they can.
          final sample = [
            ...words.where(covered),
            ...(words.where((w) => !covered(w)).toList()..shuffle(rng)).take(
              _wordsPerBundle,
            ),
          ];
          for (final word in sample) {
            for (final stability in [0.0, 10.0]) {
              _answer(
                word,
                buildExercise(
                  word,
                  bundle,
                  ctx,
                  stability,
                  rng,
                  registry: [
                    for (final g in exerciseGenerators)
                      _InContext(g, contextOf(g)),
                  ],
                ),
              );
            }
            for (final generator in exerciseGenerators) {
              final Exercise exercise;
              try {
                exercise = generator.build(
                  word,
                  bundle,
                  contextOf(generator),
                  rng,
                );
              } on CannotBuild {
                continue;
              }
              _answer(word, exercise);
              built.add(generator.kind);
            }
          }
        }
        seen = {...seen, ...unlocked};
      }
    }
    expect(built, {for (final g in exerciseGenerators) g.kind});
  });
}
