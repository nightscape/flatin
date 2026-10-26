import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';

import 'support/course_providers.dart';

Future<CourseFilter> _unlinked(LessonRange words, LessonRange grammar) async {
  seedSettings(
    Settings()
        .withGrammarFollowsWords(false)
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
      expect(filter.summary(items).words, inRange.length);
    });
  }

  test(
    'a noun with no form in the grammar range is asked its basic form',
    () async {
      final items = await loadAllPracticeItems();
      final filter = await _unlinked(LessonRange(25, 28), LessonRange(25, 28));
      final nouns = items
          .where((i) => i.dataFileId == 'nouns' && filter.wordInRange(i))
          .toList();
      final summary = filter.summary(items);

      expect(nouns, isNotEmpty);
      expect(summary.nounForms, nouns.length);
      expect(summary.verbForms, greaterThan(0));
    },
  );
}
