import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/explanation_harness.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('the real explainer explains a fixed classification item',
      (tester) async {
    await seedNothingDue({});
    final items = await loadPracticeItems('lib/data/latin_nouns.yaml');
    final dominus = items.firstWhere((i) => i.lemma == 'dominus');
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(
      WordClassificationScreen(item: dominus, formKey: 'gen.pl'),
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('wordClassification.word'))).data,
      'dominōrum',
    );

    await pickOption(tester, 0, 'Genitiv');
    await pickOption(tester, 1, 'Singular');
    await tester.tap(find.byKey(const Key('wordClassification.check.button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explanation.classification')), findsOneWidget);
    expect(find.text('dominus: Endung -us → O-Deklination-maskulinum'),
        findsOneWidget);
    expect(find.text('dominōrum = domin + ōrum → Genitiv Plural'), findsOneWidget);
    expect(
      find.text('Du hast Genitiv Singular gewählt – das wäre dominī '
          '(domin + ī)'),
      findsOneWidget,
    );
  });
}
