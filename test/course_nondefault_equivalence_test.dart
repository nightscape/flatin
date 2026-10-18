import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';

import 'support/course_providers.dart';
import 'support/legacy_selection.dart';

/// A learner who switched words, a type and two forms off by hand and whose
/// course still covers everything: what the app practises must be what the
/// settings alone practised before the course filter existed.
final _byHand = Settings(
  deselectedWords: {'rosa', 'dominus'},
  disabledTypes: {
    'nouns': {'U-Deklination'},
    'verbs': {'I-Konjugation'},
  },
  disabledForms: {
    'nouns': {'gen.sg', 'abl.pl'},
  },
  disabledFeatures: {
    'verbs': {
      'genus': {'pass'},
    },
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a hand-made selection practises what the old readers practised',
      () async {
    seedSettings(_byHand);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final items = await loadAllPracticeItems();
    final expected = items.where((item) => legacyItemSelected(_byHand, item));
    expect(expected, isNotEmpty);
    expect(expected.length, lessThan(items.length));

    final practicable =
        await container.read(practicableItemsByTypeProvider.future);
    final shown = {
      for (final byType in practicable.values) ...byType.map((i) => i.id),
    };
    expect(shown, expected.map((item) => item.id).toSet());

    final filter = await container.read(courseFilterProvider.future);
    for (final item in expected) {
      expect(
        filter.practicedForms(item.dataFileId, item.formLabels),
        legacyEnabledForms(_byHand, item.dataFileId, item.formLabels),
        reason: item.id,
      );
    }
  });
}
