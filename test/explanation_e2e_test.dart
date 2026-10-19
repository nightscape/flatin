import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('the real explainer explains a wrong genitive plural', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final items = await loadPracticeItems('lib/data/latin_nouns.yaml');
    final dominus = items.firstWhere((i) => i.lemma == 'dominus');
    final row = dominus.formOrder.indexOf('gen.pl');

    await tester.pumpWidget(
      wrapInApp(
        PracticeScreen(item: dominus),
        forcedLocale: const Locale('de'),
      ),
    );
    await letItLoad(tester);

    await tester.enterText(find.byType(TextField).at(row), 'dominis');
    await tester.tap(find.byKey(const Key('practice.check.button')));
    await tester.pump();

    expect(find.byKey(const Key('explanation.gen.pl')), findsOneWidget);
    expect(find.text('Stamm domin-'), findsNothing);
    expect(
      find.text('Du hast dominis geschrieben – das ist Dativ/Ablativ Plural'),
      findsOneWidget,
    );
  });
}
