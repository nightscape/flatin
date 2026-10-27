import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';

import 'support/hand_items.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('words that differ only in quantity keep their own lesson', () async {
    final lessons = await loadLessonData(bookAssets);

    expect(lessons.wordToLesson['hīc'], 2);
    expect(lessons.wordToLesson['hic'], 28);
    expect(lessons.wordToLesson['pārēre'], 6);
    expect(lessons.wordToLesson['parere'], 27);
  });

  test('an item is looked up by its own spelling', () async {
    final lessons = await loadLessonData(bookAssets);
    final items = await loadAllPracticeItems();

    int lessonOf(String lemma) =>
        lessons.lessonNumberOf(items.singleWhere((i) => i.lemma == lemma));

    expect(lessonOf('hic'), 28);
    expect(lessonOf('parere'), 27);
    expect(lessonOf('pārēre'), 6);
    expect(lessonOf('occīdere'), 30);
    expect(lessonOf('bēstia'), 4);
    expect(lessonOf('īgnōrāre'), 14);
  });

  test('a lesson word spelt without the item\'s macrons fails the load', () {
    const lessons = LessonData(
      wordToLesson: {'ignorare': 1},
      lessonWords: {
        1: ['ignorare'],
      },
      bookByLesson: {1: 1},
      books: [],
    );
    final item = handItem(
      dataFileId: 'verbs',
      lemma: 'īgnōrāre',
      axes: fullVerbAxes,
      forms: {
        'ind.praes.akt.3.sg': ['īgnōrat'],
      },
    );

    expect(
      () => assertLessonsCoverItems(lessons, [item]),
      throwsA(
        isStateError.having(
          (e) => e.message,
          'message',
          allOf(
            contains('īgnōrāre'),
            contains('the lessons spell it "ignorare"'),
          ),
        ),
      ),
    );
  });
}
