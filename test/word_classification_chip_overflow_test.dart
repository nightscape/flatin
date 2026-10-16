import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/explanation_harness.dart';
import 'support/word_classification_harness.dart';

void main() {
  testWidgets('a long correct-answer chip fits a narrow window',
      (tester) async {
    final nouns = await getFormMetadata('lib/data/latin_nouns.yaml');
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    await seedNothingDue({
      'nouns': nouns.availableTypes.toSet(),
      'verbs':
          verbs.availableTypes.where((t) => t != 'Mischkonjugation').toSet(),
    });
    final item = (await loadPracticeItems('lib/data/latin_verbs.yaml'))
        .singleWhere((i) => i.id == 'verbs:capere');
    // A participle: its label spells out six features, the longest the app has.
    const shownKey = 'part.fut.akt.sg.nom.f';
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(
      WordClassificationScreen(item: item, formKey: shownKey),
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    final shown = tester
        .widget<Text>(find.byKey(const Key('wordClassification.word')))
        .data;
    final sections = selectorsFor(verbs.formLabelsByKey.values.toList());
    final wrong = item.formLabels[item.forms.indexWhere((f) => f != shown)];
    for (int i = 0; i < sections.sections.length; i++) {
      final section = sections.sections[i];
      final code = wrong.features[section];
      await pickOption(tester, i,
          code == null ? '—' : sections.optionText(section, code));
    }
    await tester.tap(find.byKey(const Key('wordClassification.check.button')));
    await tester.pumpAndSettle();

    expect(find.text('Partizip Futur I Aktiv Singular Nominativ feminin'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
