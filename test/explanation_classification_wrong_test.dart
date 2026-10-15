import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/explanation_harness.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('every wrong pick gets its own explanation line',
      (tester) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    await seedNothingDue({
      'nouns': nouns.availableTypes.toSet(),
      'verbs':
          verbs.availableTypes.where((t) => t != 'Mischkonjugation').toSet(),
    });
    final item = (await loadPracticeItems('lib/data/latin_verbs.yaml'))
        .singleWhere((i) => i.type == 'Mischkonjugation');
    final spy = ExplainerSpy();
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(
      const WordClassificationScreen(),
      explainer: spy.explainer,
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    final shown = tester
        .widget<Text>(find.byKey(const Key('wordClassification.word')))
        .data;
    // A label of another form of the same word: wrong, but it exists.
    final wrong = item.formLabels[item.forms.indexWhere((f) => f != shown)];

    await pickOption(tester, 0, wrong.tense!);
    await pickOption(tester, 1, wrong.name);
    await pickOption(tester, 2, wrong.number);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    // Imperativ exists only for the 2nd person, so this maps to no label.
    await pickOption(tester, 3, 'Imperativ');
    await pickOption(tester, 4, '1. Person');
    await pickOption(tester, 5, 'Singular');
    await tester.tap(find.byKey(const Key('wordClassification.check.button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explanation.classification')), findsOneWidget);
    expect(spy.formCalls, [
      [for (final i in item.forms.asMap().keys) if (item.forms[i] == shown) item.formOrder[i]]
    ]);
    expect(spy.pickedCalls, hasLength(2));
    expect(spy.pickedCalls[0].$1?.displayName, wrong.displayName);
    expect(spy.pickedCalls[1].$1, isNull);
    expect(spy.pickedCalls[1].$2, 'Imperativ 1. Person Singular');
    expect(find.text('Imperativ 1. Person Singular gibt es bei diesem Wort nicht'),
        findsOneWidget);
  });
}
