import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/practice_providers.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:fsrs/fsrs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('translationChoices', () {
    for (final file in ['nouns', 'verbs']) {
      test('$file: correct answer, unique, at most 4, deterministic', () async {
        SharedPreferences.setMockInitialValues({});
        final items = await loadPracticeItems('lib/data/latin_$file.yaml');
        final container = ProviderContainer();
        addTearDown(container.dispose);

        for (final item in items) {
          final choices = await container.read(
            translationChoicesProvider(item).future,
          );
          expect(choices, contains(item.translation), reason: item.translation);
          expect(choices.toSet().length, choices.length, reason: '$choices');
          expect(choices.length, lessThanOrEqualTo(4));
          expect(choices.length, greaterThan(1), reason: item.translation);

          final fresh = ProviderContainer();
          addTearDown(fresh.dispose);
          expect(
            await fresh.read(translationChoicesProvider(item).future),
            choices,
          );
        }
      });
    }
  });

  group('checkAnswers translationCorrect', () {
    late PracticeItem item;
    late ProviderContainer container;

    setUp(() async {
      item = (await loadPracticeItems('lib/data/latin_nouns.yaml')).first;
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    bool? check(String? selected) {
      final notifier = container.read(practiceProvider(item).notifier);
      notifier.checkAnswers(
        [],
        [],
        selectedTranslation: selected,
        correctTranslation: item.translation,
      );
      return container.read(practiceProvider(item)).translationCorrect;
    }

    test('true for the correct translation', () {
      expect(check(item.translation), isTrue);
    });

    test('false for a wrong translation', () {
      expect(check('${item.translation} (wrong)'), isFalse);
    });

    test('false when nothing is selected', () {
      expect(check(null), isFalse);
    });

    test('hideAnswers clears the result', () {
      check(item.translation);
      container.read(practiceProvider(item).notifier).hideAnswers();
      expect(container.read(practiceProvider(item)).translationCorrect, isNull);
    });
  });

  group('suggestRating', () {
    test('wrong translation forces again', () {
      expect(suggestRating([true, true], false), Rating.again);
    });

    test('right translation, all forms right is good', () {
      expect(suggestRating([true, true], true), Rating.good);
    });

    test('right translation, some forms right is hard', () {
      expect(suggestRating([true, false, null], true), Rating.hard);
    });
  });
}
