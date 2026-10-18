import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the lessons of both volumes are loaded in reading order', () async {
    final first = await loadLessonData([lessonDataAssets.first]);
    final both = await loadLessonData(lessonDataAssets);

    expect(lessonDataAssets.length, 2);
    expect(both.lessonNames.length, first.lessonNames.length + 51);
    expect(both.lessonNames.take(first.lessonNames.length), first.lessonNames);
    expect(both.lessonNames[first.lessonNames.length], 'Lektion 21');
    expect(both.lessonNames.last, 'Lektion 40 Junkturen');

    expect(both.lessonWords['Lektion 21']!.take(3), [
      'amor',
      'salūs',
      'prōvidēre',
    ]);
    expect(both.lessonWords['Lektion 21']!.length, 25);
    expect(both.wordToLesson['salūs'], 'Lektion 21');
  });

  test('a word stays with the lesson that introduces it first', () async {
    final both = await loadLessonData(lessonDataAssets);
    final firstVolume = await loadLessonData([lessonDataAssets.first]);

    for (final entry in firstVolume.wordToLesson.entries) {
      expect(both.wordToLesson[entry.key], entry.value, reason: entry.key);
    }
  });

  test('a lesson name used by two indexes is rejected', () async {
    expect(
      loadLessonData([lessonDataAssets.first, lessonDataAssets.first]),
      throwsStateError,
    );
  });
}
