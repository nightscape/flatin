import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/home_screen.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('a card store that cannot be read is reported on the home screen',
      (tester) async {
    await seedNothingDue({'nouns': <String>{}, 'verbs': <String>{}});

    await tester.pumpWidget(wrapInApp(
      const HomeScreen(),
      overrides: [
        fsrsCardsProvider.overrideWith(
          (ref) async => throw const FormatException('broken store'),
        ),
      ],
    ));
    await letItLoad(tester);

    expect(find.textContaining('broken store'), findsWidgets);
  });
}
