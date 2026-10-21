import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Rating;
import 'package:latin_practice/data/attribution.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/grammar_exercise_harness.dart';

const _firstLesson = 21;
const _wordsPerBundle = 2;

void _answer(PracticeItem word, Exercise exercise) {
  final (right, wrong) = rightAndWrong(word, exercise);
  expect(attribute(word, exercise, right), (
    word: Rating.good,
    grammar: Rating.good,
  ), reason: '${exercise.kind} of ${word.id}');
  final rating = attribute(word, exercise, wrong);
  expect(
    rating.word == Rating.again || rating.grammar == Rating.again,
    isTrue,
    reason: 'a wrong ${exercise.kind} of ${word.id} blames no card',
  );
}

void main() {
  late List<PracticeItem> items;
  late Curriculum curriculum;
  late LessonData lessons;
  late GermanForms german;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    items = await loadAllPracticeItems();
    curriculum = await loadCurriculum(curriculumAssets);
    lessons = await loadLessonData(lessonDataAssets);
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
              _answer(word, buildExercise(word, bundle, ctx, stability, rng));
            }
            for (final generator in exerciseGenerators) {
              final Exercise exercise;
              try {
                exercise = generator.build(word, bundle, ctx, rng);
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
