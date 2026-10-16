import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';

void main() {
  test('the nouns of the lessons are found by their dictionary form', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final lessons = await loadLessonData(lessonDataAsset);
    final items = await loadAllPracticeItems();

    for (final lemma in ['rēx', 'uxor', 'corpus', 'urbs', 'mare']) {
      final item = items.singleWhere((i) => i.lemma == lemma);
      expect(lessons.lessonFor(item), isNotNull, reason: lemma);
    }
    expect(items.singleWhere((i) => i.lemma == 'rēx').id, 'nouns:rex');
  });
}
