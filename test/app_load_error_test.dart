import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/main.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets(
    'a failing card store shows its error without waiting for retries',
    (tester) async {
      await seedNothingDue({'nouns': <String>{}, 'verbs': <String>{}});

      await tester.pumpWidget(
        wrapInApp(
          const LatinPracticeApp(),
          overrides: [
            fsrsCardsProvider.overrideWith(
              (ref) async => throw const FormatException('broken store'),
            ),
          ],
        ),
      );
      await letItLoad(tester);

      expect(find.textContaining('broken store'), findsWidgets);
    },
  );
}
