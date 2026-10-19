import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';

import 'support/course_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the card counts only what practice shows', () async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    seedSettings(Settings(disabledForms: {'nouns': nouns.formOrder.toSet()}));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final practicable = await container.read(
      practicableItemsByTypeProvider.future,
    );
    final filter = await container.read(courseFilterProvider.future);
    final summary = filter.summary(await loadAllPracticeItems());

    expect(practicable['nouns'], isEmpty);
    expect(practicable['verbs'], isNotEmpty);
    expect(summary.words, practicable['verbs']!.length);
    expect(summary.nounForms, 0);
  });
}
