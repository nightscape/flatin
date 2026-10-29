import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';

import 'support/course_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('after a base forms practice, the next due verb has something to '
      'ask under a grammar range that excludes most verbs', () async {
    seedSettings(
      Settings(
        courseWords: LessonRange(1, 26),
        courseGrammar: LessonRange(26, 26),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final filter = await container.read(courseFilterProvider.future);
    final next = await container.read(
      nextDueItemProvider('verbs', const BaseForms()).future,
    );
    expect(next, isNotNull);
    expect(const BaseForms().offers(next!, filter), isTrue, reason: next.id);
  });
}
