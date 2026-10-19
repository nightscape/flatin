import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('with nothing due the shown word belongs to an enabled type', (
    tester,
  ) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    final enabledType = nouns.availableTypes.first;
    await seedNothingDue({
      'nouns': nouns.availableTypes.skip(1).toSet(),
      'verbs': verbs.availableTypes.toSet(),
    });

    final container = ProviderContainer();
    expect(await container.read(dueCardsProvider.future), isEmpty);
    final practicable = await container.read(
      practicableItemsByTypeProvider.future,
    );
    expect(practicable['nouns']!.every((i) => i.type == enabledType), isTrue);
    expect(practicable['verbs'], isEmpty);
    final allowed = practicable['nouns']!.expand((item) => item.forms).toSet();
    container.dispose();

    await tester.pumpWidget(wrapInApp(const WordClassificationScreen()));
    await letItLoad(tester);

    final shown = tester
        .widget<Text>(find.byKey(const Key('wordClassification.word')))
        .data;
    expect(allowed, contains(shown));
  });

  testWidgets('with nothing due and every type off no word is shown', (
    tester,
  ) async {
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
