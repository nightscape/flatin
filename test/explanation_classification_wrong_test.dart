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
        .singleWhere((i) => i.id == 'verbs:capere');
    // Its macron-free spelling is also the spelling of the ablative.
    const shownKey = 'part.fut.akt.sg.nom.f';
    final spy = ExplainerSpy();
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapInApp(
      WordClassificationScreen(item: item, formKey: shownKey),
      explainer: spy.explainer,
      forcedLocale: const Locale('de'),
    ));
    await letItLoad(tester);

    final shown = tester
        .widget<Text>(find.byKey(const Key('wordClassification.word')))
        .data;
    // A label of another form of the same word: wrong, but it exists.
    final wrong = item.formLabels[item.forms.indexWhere((f) => f != shown)];

    final sections = selectorsFor(verbs.formLabelsByKey.values.toList());
    Future<void> pickAll(int row, Map<String, String> features) async {
      for (int i = 0; i < sections.sections.length; i++) {
        final section = sections.sections[i];
        final code = features[section];
        await pickOption(
          tester,
          row * sections.sections.length + i,
          code == null ? '—' : sections.optionText(section, code),
        );
      }
    }

    await pickAll(0, wrong.features);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    // Imperativ exists only for the 2nd person, so this maps to no label.
    await pickAll(1, {
      'modus': 'imp',
      'tempus': 'praes',
      'genus_verbi': 'akt',
      'person': '1',
      'numerus': 'sg',
    });
    await tester.tap(find.byKey(const Key('wordClassification.check.button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explanation.classification')), findsOneWidget);
    expect(spy.formCalls, [
      [
        'part.fut.akt.sg.nom.f',
        'part.fut.akt.sg.abl.f',
        'part.fut.akt.sg.vok.f',
        'part.fut.akt.pl.nom.n',
        'part.fut.akt.pl.akk.n',
        'part.fut.akt.pl.vok.n',
      ]
    ]);
    expect(spy.pickedCalls, hasLength(2));
    expect(spy.pickedCalls[0].$1?.displayName, wrong.displayName);
    expect(spy.pickedCalls[1].$1, isNull);
    expect(spy.pickedCalls[1].$2, 'Imperativ Präsens Aktiv 1. Person Singular');
    expect(find.text('Imperativ Präsens Aktiv 1. Person Singular gibt es bei diesem Wort nicht'),
        findsOneWidget);
  });
}
