import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/explanation_harness.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('the checked screen fits a small window', (tester) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    await seedNothingDue({
      'nouns': nouns.availableTypes.where((t) => t != 'U-Deklination').toSet(),
      'verbs': verbs.availableTypes.toSet(),
    });
    final item = (await loadPracticeItems('lib/data/latin_nouns.yaml'))
        .singleWhere((i) => i.id == 'nouns:manus');
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(
      WordClassificationScreen(item: item, formKey: 'nom.sg'),
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    // manibus, so neither the shown form nor one of its macron twins: the
    // check adds the explanation box and the feedback message.
    final wrong = item.formLabels[item.formOrder.indexOf('dat.pl')];

    await pickOption(tester, 0, wrong.display('kasus')!);
    await pickOption(tester, 1, wrong.display('numerus')!);
    await tester.tap(find.byKey(const Key('wordClassification.check.button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wordClassification.check.button')),
        findsNothing);
    expect(find.byKey(const Key('explanation.classification')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
