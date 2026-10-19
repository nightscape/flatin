/// Axes and items built by hand, for the grammar the interim YAML has no
/// word for: Modus, Genus verbi and forms without Person.
library;

import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

/// Verb axes with every axis the engine knows, so a test can span them.
final fullVerbAxes = Axes(
  axes: [
    GrammarAxis(
      id: 'modus',
      name: 'Modus',
      values: const [
        ('ind', 'Indikativ'),
        ('konj', 'Konjunktiv'),
        ('inf', 'Infinitiv'),
      ],
      hiddenInLabel: const {'ind'},
    ),
    GrammarAxis(
      id: 'tempus',
      name: 'Tempus',
      values: const [
        ('praes', 'Präsens'),
        ('fut', 'Futur I'),
        ('perf', 'Perfekt'),
      ],
    ),
    GrammarAxis(
      id: 'genus',
      name: 'Genus verbi',
      values: const [('akt', 'Aktiv'), ('pass', 'Passiv')],
      hiddenInLabel: const {'akt'},
    ),
    GrammarAxis(
      id: 'person',
      name: 'Person',
      values: const [
        ('1', '1. Person'),
        ('2', '2. Person'),
        ('3', '3. Person'),
      ],
    ),
    GrammarAxis(
      id: 'numerus',
      name: 'Numerus',
      values: const [('sg', 'Singular'), ('pl', 'Plural')],
    ),
  ],
  head: const ['modus', 'tempus', 'genus'],
  tail: const ['person', 'numerus'],
  mergeAxis: 'person',
  // S17: the Infinitiv has one future tense, so its label drops the "I".
  labelOverrides: [
    LabelOverride(
      when: {
        'modus': {'inf'},
      },
      axis: 'tempus',
      values: {'fut': 'Futur'},
    ),
  ],
);

FormLabel fullVerbLabel(String key) => FormLabel.fromKey(key, fullVerbAxes);

/// An item whose forms are given as they stand: [forms] maps every form key
/// to its accepted spellings, the shown one first.
PracticeItem handItem({
  required String dataFileId,
  required String lemma,
  required Axes axes,
  required Map<FormKey, List<String>> forms,
  String type = 'Testtyp',
  String translation = 'Testwort',
}) {
  final keys = forms.keys.toList();
  return PracticeItem(
    id: '$dataFileId:$lemma',
    lemma: lemma,
    type: type,
    translation: translation,
    principalParts: [('', lemma)],
    dataFileId: dataFileId,
    formOrder: keys,
    forms: [for (final key in keys) forms[key]!.first],
    acceptedForms: [for (final key in keys) forms[key]!],
    formLabels: [for (final key in keys) FormLabel.fromKey(key, axes)],
    derivation: Derivation(
      type: type,
      recognition: const TypeDeclared(),
      forms: {
        for (final key in keys)
          key: GivenForm(formKey: key, variants: forms[key]!),
      },
      grammar: const Grammar({}, {}),
    ),
  );
}
