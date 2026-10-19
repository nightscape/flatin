import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';

import 'support/explanation_harness.dart';
import 'support/hand_items.dart';
import 'support/word_classification_harness.dart';

/// Spans Modus, Tempus, Genus verbi, Person and Numerus; the Infinitiv has
/// neither Person nor Numerus.
PracticeItem spanningItem() => handItem(
  dataFileId: 'verbs',
  lemma: 'amāre',
  axes: fullVerbAxes,
  forms: {
    'ind.praes.akt.3.sg': ['amat'],
    'ind.praes.akt.3.pl': ['amant'],
    'ind.praes.pass.3.sg': ['amātur'],
    'konj.praes.akt.3.sg': ['amet'],
    'ind.fut.akt.3.sg': ['amābit'],
    'inf.fut.akt': ['amātūrum esse'],
  },
);

void main() {
  final item = spanningItem();
  final selectors = selectorsFor(item.formLabels);

  test('every axis the forms disagree on gets a selector', () {
    expect(selectors.sections, [
      'modus',
      'tempus',
      'genus',
      'person',
      'numerus',
    ]);
    expect(selectors.fixed, isEmpty);
  });

  test('an axis some form lacks offers "—" first', () {
    expect(selectors.options['person'], [absentValue, '3']);
    expect(selectors.optionText('person', absentValue), '—');
  });

  test('an axis every enabled form agrees on is hidden and fixed', () {
    final indicative = item.formLabels
        .where((label) => label.features['modus'] == 'ind')
        .toList();
    final only = selectorsFor(indicative);

    expect(only.sections, isNot(contains('modus')));
    expect(only.fixed['modus'], 'ind');
    expect(
      only.labelFor({
        'tempus': 'praes',
        'genus': 'akt',
        'person': '3',
        'numerus': 'sg',
      }, item.formLabels),
      fullVerbLabel('ind.praes.akt.3.sg'),
    );
  });

  test('two forms that differ only in Genus verbi are told apart', () {
    Map<String, String?> picks(String genus) => {
      'modus': 'ind',
      'tempus': 'praes',
      'genus': genus,
      'person': '3',
      'numerus': 'sg',
    };

    expect(
      selectors.labelFor(picks('akt'), item.formLabels),
      fullVerbLabel('ind.praes.akt.3.sg'),
    );
    expect(
      selectors.labelFor(picks('pass'), item.formLabels),
      fullVerbLabel('ind.praes.pass.3.sg'),
    );
  });

  test('a combination the item has no form for maps to no label', () {
    expect(
      selectors.labelFor({
        'modus': 'konj',
        'tempus': 'fut',
        'genus': 'pass',
        'person': '3',
        'numerus': 'pl',
      }, item.formLabels),
      isNull,
    );
  });

  test('a selector names the axis value, the label may rename it (S17)', () {
    expect(selectors.optionText('tempus', 'fut'), 'Futur I');
    expect(fullVerbLabel('inf.fut.akt').displayName, 'Infinitiv Futur');
  });

  testWidgets('the screen asks one dropdown per axis', (tester) async {
    await seedNothingDue({});
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapInApp(
        WordClassificationScreen(item: item, formKey: 'inf.fut.akt'),
        forcedLocale: const Locale('de'),
      ),
    );
    await letItLoad(tester);

    expect(
      find.byType(DropdownButtonFormField<String>),
      findsNWidgets(selectors.sections.length),
    );

    await pickOption(tester, 0, 'Infinitiv');
    await pickOption(tester, 1, 'Futur I');
    await pickOption(tester, 2, 'Aktiv');
    await pickOption(tester, 3, '—');
    await pickOption(tester, 4, '—');
    await tester.tap(find.byKey(const Key('wordClassification.check.button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explanation.classification')), findsNothing);
    expect(find.text('Infinitiv Futur I Aktiv'), findsOneWidget);
  });
}
