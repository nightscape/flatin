import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/main.dart';

import 'support/word_classification_harness.dart';

/// Two widget tests in one file must not interfere. The second one used to
/// wait forever on the practice data that the first one had already loaded.
void main() {
  for (final run in ['first', 'second']) {
    testWidgets('the $run test of the file reaches the home screen',
        (tester) async {
      await seedNothingDue({'nouns': <String>{}, 'verbs': <String>{}});

      await tester.pumpWidget(wrapInApp(const LatinPracticeApp()));
      await letItLoad(tester);

      expect(find.text('Nouns (Deklination)'), findsOneWidget);
      expect(find.text('Verbs (Konjugation)'), findsOneWidget);
    });
  }
}
