import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the lessons of both volumes are loaded in reading order', () async {
    final first = await loadLessonData([bookAssets.first]);
    final both = await loadLessonData(bookAssets);

    expect(bookAssets.length, 2);
    expect(first.lessonWords.keys, [for (var l = 1; l <= 20; l++) l]);
    expect(both.lessonWords.keys, [for (var l = 1; l <= 40; l++) l]);
    expect(both.books, ['Agite 1', 'Agite 2']);

    expect(both.lessonWords[21]!.take(3), ['amor', 'salūs', 'prōvidēre']);
    expect(both.lessonWords[21]!.length, 25);
    expect(both.wordToLesson['salūs'], 21);
  });

  test('a word stays with the lesson that introduces it first', () async {
    final both = await loadLessonData(bookAssets);
    final firstVolume = await loadLessonData([bookAssets.first]);

    for (final entry in firstVolume.wordToLesson.entries) {
      expect(both.wordToLesson[entry.key], entry.value, reason: entry.key);
    }
  });

  test('a lesson listed by two books is rejected', () async {
    expect(
      loadLessonData([bookAssets.first, bookAssets.first]),
      throwsStateError,
    );
  });
}
