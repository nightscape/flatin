import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/token_lessons.dart';

import 'support/latin_course.dart';

const _clause = Clause(
  id: 'c',
  art: 'haupt',
  tokens: [],
  de: [],
  ausrichtung: [],
);

List<int> _wordLesson(
  LessonData lessons,
  Curriculum curriculum,
  String lemma,
) => LessonLookup(
  latinLang,
  lessons,
  curriculum,
  const {},
).of(WordToken('t', lemma, lemma, Analyse(const {})), _clause).word;

/// Lesson lists in which pairs of spellings that differ only in quantity
/// marks (hic/hīc) sit in drawn lessons, in drawn order.
LessonData _homographLessons(Random r) {
  const pairs = [
    ('hic', 'hīc'),
    ('liber', 'līber'),
    ('malum', 'mālum'),
    ('populus', 'pōpulus'),
    ('os', 'ōs'),
  ];
  final lessonWords = <int, List<String>>{};
  for (final (a, b) in pairs) {
    for (final w in r.nextBool() ? [a, b] : [b, a]) {
      (lessonWords[1 + r.nextInt(5)] ??= []).add(w);
    }
  }
  final ordered = lessonWords.keys.toList()..sort();
  final wordToLesson = <String, int>{};
  for (final l in ordered) {
    for (final w in lessonWords[l]!) {
      wordToLesson.putIfAbsent(w, () => l);
    }
  }
  return LessonData(
    wordToLesson: wordToLesson,
    lessonWords: {for (final l in ordered) l: lessonWords[l]!},
    bookByLesson: {for (final l in ordered) l: 1},
    books: const ['b'],
  );
}

/// A word of [lessons] whose spelling has quantity marks, respelled without
/// them, when no other word of the lists folds to the same letters.
(String, int)? _respelled(Random r, LessonData lessons) {
  final byLetters = <String, List<String>>{};
  for (final w in lessons.wordToLesson.keys) {
    (byLetters[latinLang.fold(w)] ??= []).add(w);
  }
  final marked = [
    for (final MapEntry(:key, :value) in byLetters.entries)
      if (value.length == 1 && key != value.single) value.single,
  ];
  if (marked.isEmpty) return null;
  final w = marked[r.nextInt(marked.length)];
  return (latinLang.fold(w), lessons.wordToLesson[w]!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a word the lesson lists spell exactly shows the lesson of that '
    'spelling, also when another spelling folds to the same letters',
    () async {
      final curriculum = await loadCurriculum(latinCourse.books);
      final real = await loadLessonData(latinCourse.books);
      for (final lessons in [
        real,
        for (var seed = 0; seed < 50; seed++) _homographLessons(Random(seed)),
      ]) {
        for (final MapEntry(key: lemma, value: lesson)
            in lessons.wordToLesson.entries) {
          expect(_wordLesson(lessons, curriculum, lemma), [
            lesson,
          ], reason: lemma);
        }
      }
    },
  );

  test('a token that spells a listed word without its quantity marks shows '
      'the lesson of that word', () async {
    final curriculum = await loadCurriculum(latinCourse.books);
    final real = await loadLessonData(latinCourse.books);
    for (var seed = 0; seed < 200; seed++) {
      final (spelling, lesson) = _respelled(Random(seed), real)!;
      expect(_wordLesson(real, curriculum, spelling), [
        lesson,
      ], reason: spelling);
    }
  });

  test('a token that no list spells exactly and that folds to several list '
      'words shows each distinct lesson once, ascending', () async {
    final curriculum = await loadCurriculum(latinCourse.books);
    const triples = [
      ('pārēre', 'parere', 'pārere'),
      ('līberī', 'liberi', 'līberi'),
    ];
    var same = 0, different = 0;
    for (var seed = 0; seed < 100; seed++) {
      final r = Random(seed);
      for (final (marked, plain, token) in triples) {
        final lessonOfMarked = 1 + r.nextInt(4);
        final lessonOfPlain = 1 + r.nextInt(4);
        final lessons = LessonData(
          wordToLesson: {marked: lessonOfMarked, plain: lessonOfPlain},
          lessonWords: {
            lessonOfMarked: [marked],
            lessonOfPlain: [plain],
          },
          bookByLesson: {lessonOfMarked: 1, lessonOfPlain: 1},
          books: const ['b'],
        );
        lessonOfMarked == lessonOfPlain ? same++ : different++;
        expect(
          _wordLesson(lessons, curriculum, token),
          {lessonOfMarked, lessonOfPlain}.toList()..sort(),
          reason: '$token in seed $seed',
        );
      }
    }
    expect(same, greaterThan(0));
    expect(different, greaterThan(0));
  });
}
