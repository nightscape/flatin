import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/explanation_harness.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('a correct pick gets no explanation box', (tester) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    await seedNothingDue({
      'nouns': nouns.availableTypes.where((t) => t != 'U-Deklination').toSet(),
      'verbs': verbs.availableTypes.toSet(),
    });
    final items = (await loadPracticeItems('lib/data/latin_nouns.yaml'))
        .where((i) => i.type == 'U-Deklination');
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
    final item = items.singleWhere((i) => i.forms.contains(shown));
    final correct = item.formLabels[item.forms.indexOf(shown!)];

    await pickOption(tester, 0, correct.display('kasus')!);
    await pickOption(tester, 1, correct.display('numerus')!);
    await tester.tap(find.byKey(const Key('wordClassification.check.button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explanation.classification')), findsNothing);
    expect(spy.pickedCalls, isEmpty);
  });
}
