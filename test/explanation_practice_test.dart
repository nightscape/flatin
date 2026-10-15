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

    await tester.pumpWidget(wrapInApp(
      PracticeScreen(item: dominus),
      explainer: spy.explainer,
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    final correctRow = find.byKey(const Key('explanation.nominative_singular'));
    final wrongRow = find.byKey(const Key('explanation.genitive_singular'));
    final emptyRow = find.byKey(const Key('explanation.dative_singular'));

    expect(find.byType(ExplanationLines), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'dominus');
    await tester.enterText(find.byType(TextField).at(1), 'dominis');
    await tester.tap(find.byKey(const Key('practice.check.button')));
    await tester.pump();

    expect(wrongRow, findsOneWidget);
    expect(correctRow, findsNothing);
    expect(emptyRow, findsNothing);
    expect(find.byType(ExplanationLines), findsOneWidget);
    expect(spy.wrongAnswerCalls, [('genitive_singular', 'dominis')]);
    expect(
      find.text('Du hast dominis geschrieben – das passt zu keiner '
          'bekannten Form'),
      findsOneWidget,
    );
  });
}
