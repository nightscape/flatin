import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/key_echo_app.dart';
import 'support/key_echo_i18n.dart';
import 'support/word_classification_harness.dart' show letItLoad;

void main() {
  testWidgets('the real explainer explains a wrong genitive plural', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final items = await loadPracticeItems('lib/data/latin_nouns.yaml');
    final dominus = items.firstWhere((i) => i.lemma == 'dominus');
    final row = dominus.formOrder.indexOf('gen.pl');

    await tester.pumpWidget(
      wrapInKeyEchoAppWith(PracticeScreen(item: dominus)),
    );
    await letItLoad(tester);

    await tester.enterText(find.byType(TextField).at(row), 'dominis');
    await tester.tap(find.byKey(const Key('practice.check.button')));
    await tester.pump();

    expect(find.byKey(const Key('explanation.gen.pl')), findsOneWidget);
    expect(
      find.text(
        keyEcho('explain.diag.otherForm', {
          'answer': 'dominis',
          'labels': 'Dativ/Ablativ Plural',
        }),
      ),
      findsOneWidget,
    );
  });
}
