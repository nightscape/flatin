/// The axes of the two data files, for tests that build labels by hand.
///
/// [FormLabel] compares its [Axes] by identity, so a label made here is only
/// equal to another label made from the same constant.
library;

import 'package:latin_practice/models/form_label.dart';

final nounAxes = Axes(
  axes: [
    GrammarAxis(
      id: 'kasus',
      name: 'Kasus',
      values: const [
        ('nom', 'Nominativ'),
        ('gen', 'Genitiv'),
        ('dat', 'Dativ'),
        ('akk', 'Akkusativ'),
        ('abl', 'Ablativ'),
        ('vok', 'Vokativ'),
      ],
    ),
    GrammarAxis(
      id: 'numerus',
      name: 'Numerus',
      values: const [('sg', 'Singular'), ('pl', 'Plural')],
    ),
  ],
  head: const [],
  tail: const ['kasus', 'numerus'],
  mergeAxis: 'kasus',
);

final verbAxes = Axes(
  axes: [
    GrammarAxis(
      id: 'tempus',
      name: 'Tempus',
      values: const [
        ('praes', 'Präsens'),
        ('impf', 'Imperfekt'),
        ('fut', 'Futur I'),
        ('perf', 'Perfekt'),
        ('plusq', 'Plusquamperfekt'),
        ('imp', 'Imperativ'),
      ],
    ),
    GrammarAxis(
      id: 'person',
      name: 'Person',
      values: const [('1', '1. Person'), ('2', '2. Person'), ('3', '3. Person')],
    ),
    GrammarAxis(
      id: 'numerus',
      name: 'Numerus',
      values: const [('sg', 'Singular'), ('pl', 'Plural')],
    ),
  ],
  head: const ['tempus'],
  tail: const ['person', 'numerus'],
  mergeAxis: 'person',
);

FormLabel nounLabel(String kasus, String numerus) =>
    FormLabel(features: {'kasus': kasus, 'numerus': numerus}, axes: nounAxes);

FormLabel verbLabel(String tempus, String person, String numerus) => FormLabel(
  features: {'tempus': tempus, 'person': person, 'numerus': numerus},
  axes: verbAxes,
);
