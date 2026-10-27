import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';

import 'support/course_providers.dart';

Future<CourseFilter> _unlinked(LessonRange words, LessonRange grammar) async {
  seedSettings(
    Settings()
        .withGrammarLinked(to: false)
        .withWordRange(words)
        .withGrammarRange(grammar),
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(courseFilterProvider.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The grammar range's lower bound narrows the asked forms only: every word
  /// in the word range stays, a word without a form in the grammar range
  /// through its basic form.
  for (final (words, grammar) in [
    (LessonRange(25, 28), LessonRange(25, 28)),
    (LessonRange(25, 28), LessonRange(10, 28)),
    (LessonRange(1, 4), LessonRange(2, 4)),
  ]) {
    test('words $words with grammar $grammar keep every word', () async {
      final items = await loadAllPracticeItems();
      final filter = await _unlinked(words, grammar);
      final inRange = items.where(filter.wordInRange).toList();

      expect(inRange, isNotEmpty);
      expect(items.where(filter.reachesPractice).length, inRange.length);
    });
  }

  test(
    'a noun with no form in the grammar range is asked its basic form',
    () async {
      final items = await loadAllPracticeItems();
      final filter = await _unlinked(LessonRange(25, 28), LessonRange(25, 28));
      final inRange = items.where(filter.wordInRange);
      int forms(PracticeItem i) =>
          filter.practicedForms(i.dataFileId, i.formLabels).length;
      final nouns = inRange.where((i) => i.dataFileId == 'nouns').toList();

      expect(nouns, isNotEmpty);
      expect(nouns.map(forms), everyElement(1));
      expect(
        inRange.where((i) => i.dataFileId == 'verbs').map(forms),
        contains(greaterThan(0)),
      );
    },
  );
}
