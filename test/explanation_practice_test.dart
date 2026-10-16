import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/widgets/explanation_lines.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/explanation_harness.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('the practice screen explains only the wrong rows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final items = await loadPracticeItems('lib/data/latin_nouns.yaml');
    final dominus = items.firstWhere((i) => i.lemma == 'dominus');
    final spy = ExplainerSpy();
    final nomRow = dominus.formOrder.indexOf('nom.sg');
    final genRow = dominus.formOrder.indexOf('gen.sg');

    await tester.pumpWidget(wrapInApp(
      PracticeScreen(item: dominus),
      explainer: spy.explainer,
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    final correctRow = find.byKey(const Key('explanation.nom.sg'));
    final wrongRow = find.byKey(const Key('explanation.gen.sg'));
    final emptyRow = find.byKey(const Key('explanation.dat.sg'));

    expect(find.byType(ExplanationLines), findsNothing);

    await tester.enterText(find.byType(TextField).at(nomRow), 'dominus');
    await tester.enterText(find.byType(TextField).at(genRow), 'dominis');
    await tester.tap(find.byKey(const Key('practice.check.button')));
    await tester.pump();

    expect(wrongRow, findsOneWidget);
    expect(correctRow, findsNothing);
    expect(emptyRow, findsNothing);
    // The right row gets the spelling line instead of a diagnosis.
    expect(find.byKey(const Key('macrons.nom.sg')),
        findsOneWidget);
    expect(find.byType(ExplanationLines), findsNWidgets(2));
    expect(spy.wrongAnswerCalls, [('gen.sg', 'dominis')]);
    expect(spy.correctAnswerCalls, [('nom.sg', 'dominus')]);
    expect(
      find.text('Du hast dominis geschrieben – das passt zu keiner '
          'bekannten Form'),
      findsOneWidget,
    );
  });
}
