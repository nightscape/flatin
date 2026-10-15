import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('with nothing due and every type off no word is shown',
      (tester) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    await seedNothingDue({
      'nouns': nouns.availableTypes.toSet(),
      'verbs': verbs.availableTypes.toSet(),
    });

    await tester.pumpWidget(wrapInApp(const WordClassificationScreen()));
    await letItLoad(tester);

    expect(find.byKey(const Key('wordClassification.word')), findsNothing);
    expect(find.text('No words available'), findsOneWidget);
  });
}
