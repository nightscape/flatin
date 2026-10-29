/// Hand-made items of the 3.2 derivation types: named stems, seam rules,
/// composition, deponents and variants. The v1 loader builds none of these,
/// so the trace consumers are tested against values the engine lane will
/// later produce.
library;

import 'dart:convert';

import 'package:latin_practice/data/asset_text.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

final verbAxes = Axes(
  axes: [
    GrammarAxis(
      id: 'modus',
      name: 'Modus',
      values: const [
        ('ind', 'Indikativ'),
        ('konj', 'Konjunktiv'),
        ('inf', 'Infinitiv'),
        ('part', 'Partizip'),
      ],
      hiddenInLabel: const {'ind'},
    ),
    GrammarAxis(
      id: 'tempus',
      name: 'Tempus',
      values: const [
        ('praes', 'Präsens'),
        ('impf', 'Imperfekt'),
        ('fut', 'Futur I'),
        ('perf', 'Perfekt'),
        ('plusq', 'Plusquamperfekt'),
      ],
    ),
    GrammarAxis(
      id: 'genus_verbi',
      name: 'Genus verbi',
      values: const [('akt', 'Aktiv'), ('pass', 'Passiv')],
      hiddenInLabel: const {'akt'},
    ),
    GrammarAxis(
      id: 'kasus',
      name: 'Kasus',
      values: const [('nom', 'Nominativ'), ('gen', 'Genitiv')],
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
  head: const ['modus', 'tempus', 'genus_verbi'],
  tail: const ['kasus', 'person', 'numerus'],
  mergeAxis: 'person',
  // S17/Q13: the future infinitive and participle are not "Futur I".
  labelOverrides: [
    LabelOverride(
      when: {
        'modus': {'inf', 'part'},
      },
      axis: 'tempus',
      values: const {'fut': 'Futur'},
    ),
  ],
);

final adjectiveAxes = Axes(
  axes: [
    GrammarAxis(
      id: 'komparation',
      name: 'Steigerung',
      values: const [
        ('pos', 'Positiv'),
        ('komp', 'Komparativ'),
        ('sup', 'Superlativ'),
      ],
      hiddenInLabel: const {'pos'},
    ),
    GrammarAxis(
      id: 'kasus',
      name: 'Kasus',
      values: const [
        ('nom', 'Nominativ'),
        ('gen', 'Genitiv'),
        ('dat', 'Dativ'),
      ],
    ),
    GrammarAxis(
      id: 'numerus',
      name: 'Numerus',
      values: const [('sg', 'Singular'), ('pl', 'Plural')],
    ),
  ],
  head: const [],
  tail: const ['komparation', 'kasus', 'numerus'],
  mergeAxis: 'kasus',
);

const aAusfall = SandhiRule(id: 'a_ausfall', explain: 'ā fällt vor Vokal aus');
const kurzVorNt = SandhiRule(
  id: 'kurz_nt',
  explain: 'Vokal vor nt/nd wird kurz',
);
const iVorR = SandhiRule(id: 'i_vor_r', explain: 'i wird vor r zu e');
const tVorS = SandhiRule(id: 't_s', explain: 't wird vor s zu s');

/// An item whose `forms` and `acceptedForms` follow its derivation (I1).
PracticeItem traceItem({
  required String id,
  required String lemma,
  required String type,
  required String translation,
  required List<(String, String)> principalParts,
  required Axes axes,
  required Derivation derivation,
  String dataFileId = 'verbs',
}) {
  final keys = derivation.forms.keys.toList();
  return PracticeItem(
    id: id,
    lemma: lemma,
    type: type,
    translation: translation,
    bookTranslation: translation,
    principalParts: principalParts,
    formOrder: keys,
    forms: [for (final key in keys) derivation.forms[key]!.result],
    acceptedForms: [for (final key in keys) derivation.forms[key]!.variants],
    formLabels: [for (final key in keys) FormLabel.fromKey(key, axes)],
    dataFileId: dataFileId,
    derivation: derivation,
    baseFormKeys: const [],
  );
}

/// amāre: school stems (root + theme vowel), a seam rule in the present, the
/// PPA stem with a quantity rule, perfect variants and two compositions.
PracticeItem amare() {
  final wurzel = StemFromPart(
    name: 'wurzel',
    display: 'Wurzel',
    variants: const ['am'],
    part: 'infinitiv',
    sourceWord: 'amāre',
    removedSuffix: 'āre',
  );
  final praesens = StemFromDefault(
    name: 'praesens',
    display: 'Präsensstamm',
    variants: const ['amā'],
    template: '{wurzel}ā',
    base: wurzel,
  );
  final ppa = StemFromDefault(
    name: 'ppa',
    display: 'PPA-Stamm',
    variants: const ['amant'],
    template: '{praesens}nt',
    base: praesens,
    sandhiRule: kurzVorNt,
  );
  final perfekt = StemFromPart(
    name: 'perfekt',
    display: 'Perfektstamm',
    variants: const ['amāv'],
    part: 'perfekt',
    sourceWord: 'amāvī',
    removedSuffix: 'ī',
  );
  final ppp = StemFromPart(
    name: 'ppp',
    display: 'PPP-Stamm',
    variants: const ['amāt'],
    part: 'ppp',
    sourceWord: 'amātum',
    removedSuffix: 'um',
  );

  return traceItem(
    id: 'verbs:amare',
    lemma: 'amāre',
    type: 'A-Konjugation',
    translation: 'lieben',
    principalParts: const [('', 'amāre'), ('', 'amāvī'), ('', 'amātum')],
    axes: verbAxes,
    derivation: Derivation(
      type: 'A-Konjugation',
      recognition: const TypeByRule(
        sourceWord: 'amāre',
        suffix: 'āre',
        candidateTypes: ['A-Konjugation'],
      ),
      stems: {
        'wurzel': wurzel,
        'praesens': praesens,
        'ppa': ppa,
        'perfekt': perfekt,
        'ppp': ppp,
      },
      grammar: const Grammar({}, {}, {}, 'de'),
      forms: {
        'ind.praes.akt.1.sg': GeneratedForm(
          formKey: 'ind.praes.akt.1.sg',
          variants: const ['amō'],
          stemName: 'praesens',
          ending: 'ō',
          endingType: 'A-Konjugation',
          sandhiRule: aAusfall,
        ),
        'ind.perf.akt.3.pl': GeneratedForm(
          formKey: 'ind.perf.akt.3.pl',
          variants: const ['amāvērunt', 'amāvēre'],
          stemName: 'perfekt',
          ending: 'ērunt',
          endingType: 'A-Konjugation',
        ),
        'part.praes.akt.gen.sg': GeneratedForm(
          formKey: 'part.praes.akt.gen.sg',
          variants: const ['amantis'],
          stemName: 'ppa',
          ending: 'is',
          endingType: 'A-Konjugation',
        ),
        'konj.plusq.pass.1.sg': ComposedForm(
          formKey: 'konj.plusq.pass.1.sg',
          variants: const ['amātus essem'],
          joins: [' '],
          parts: [
            LexemeFormPart(
              lexemeId: 'verbs:amare',
              key: 'part.perf.pass.nom.sg',
              derivation: GivenForm(
                formKey: 'part.perf.pass.nom.sg',
                variants: const ['amātus'],
              ),
            ),
            LexemeFormPart(
              lexemeId: 'verbs:esse',
              key: 'konj.plusq.akt.1.sg',
              derivation: GivenForm(
                formKey: 'konj.plusq.akt.1.sg',
                variants: const ['essem'],
              ),
            ),
          ],
        ),
        'inf.fut.akt': ComposedForm(
          formKey: 'inf.fut.akt',
          variants: const ['amātūrum esse'],
          joins: [' '],
          parts: [
            LexemeFormPart(
              lexemeId: 'verbs:amare',
              key: 'part.fut.akt.nom.sg',
              derivation: GivenForm(
                formKey: 'part.fut.akt.nom.sg',
                variants: const ['amātūrum'],
              ),
            ),
            LexemeFormPart(
              lexemeId: 'verbs:esse',
              key: 'inf.praes.akt',
              derivation: GivenForm(
                formKey: 'inf.praes.akt',
                variants: const ['esse'],
              ),
            ),
          ],
        ),
      },
      internal: {
        'part.perf.pass.nom.sg': GeneratedForm(
          formKey: 'part.perf.pass.nom.sg',
          variants: const ['amātus'],
          stemName: 'ppp',
          ending: 'us',
          endingType: 'a-o-Endungen',
        ),
      },
    ),
  );
}

/// capere: the `ere` rule leaves three candidates, and the infinitive seam
/// turns the theme vowel into e.
PracticeItem capere() {
  final wurzel = StemFromPart(
    name: 'wurzel',
    display: 'Wurzel',
    variants: const ['cap'],
    part: 'infinitiv',
    sourceWord: 'capere',
    removedSuffix: 'ere',
  );
  final praesens = StemFromDefault(
    name: 'praesens',
    display: 'Präsensstamm',
    variants: const ['capi'],
    template: '{wurzel}i',
    base: wurzel,
  );

  return traceItem(
    id: 'verbs:capere',
    lemma: 'capere',
    type: 'Mischkonjugation',
    translation: 'nehmen',
    principalParts: const [('', 'capere')],
    axes: verbAxes,
    derivation: Derivation(
      type: 'Mischkonjugation',
      recognition: const TypeByRule(
        sourceWord: 'capere',
        suffix: 'ere',
        candidateTypes: [
          'Konsonantische-Konjugation',
          'Mischkonjugation',
          'E-Konjugation',
        ],
      ),
      stems: {'wurzel': wurzel, 'praesens': praesens},
      grammar: const Grammar({}, {}, {}, 'de'),
      forms: {
        'inf.praes.akt': GeneratedForm(
          formKey: 'inf.praes.akt',
          variants: const ['capere'],
          stemName: 'praesens',
          ending: 're',
          endingType: 'Mischkonjugation',
          sandhiRule: iVorR,
        ),
      },
    ),
  );
}

/// regere: the connecting vowel belongs to the ending, so the seam is plain.
PracticeItem regere() {
  final praesens = StemFromPart(
    name: 'praesens',
    display: 'Präsensstamm',
    variants: const ['reg'],
    part: 'infinitiv',
    sourceWord: 'regere',
    removedSuffix: 'ere',
  );

  return traceItem(
    id: 'verbs:regere',
    lemma: 'regere',
    type: 'Konsonantische-Konjugation',
    translation: 'lenken',
    principalParts: const [('', 'regere')],
    axes: verbAxes,
    derivation: Derivation(
      type: 'Konsonantische-Konjugation',
      recognition: const TypeDeclared(),
      stems: {'praesens': praesens},
      grammar: const Grammar({}, {}, {}, 'de'),
      forms: {
        'ind.praes.akt.3.sg': GeneratedForm(
          formKey: 'ind.praes.akt.3.sg',
          variants: const ['regit'],
          stemName: 'praesens',
          ending: 'it',
          endingType: 'Konsonantische-Konjugation',
        ),
      },
    ),
  );
}

/// posse: a composition with an affix that the seam rule changes, beside a
/// type pattern on the present stem, as `lib/data/latin_verbs.yaml` has it.
PracticeItem posse() {
  final praesens = StemFromPart(
    name: 'praesens',
    display: 'Präsensstamm',
    variants: const ['pos'],
    part: 'praesens_stamm',
    sourceWord: 'pos',
    removedSuffix: '',
  );

  ComposedForm composed(
    FormKey key,
    String result,
    String affix,
    String verb,
    SandhiRule? rule,
  ) => ComposedForm(
    formKey: key,
    variants: [result],
    joins: [''],
    parts: [
      AffixPart(
        stemName: 'praesens',
        text: affix,
        sandhi: true,
        sandhiRule: rule,
      ),
      LexemeFormPart(
        lexemeId: 'verbs:esse',
        key: key,
        derivation: GivenForm(formKey: key, variants: [verb]),
      ),
    ],
  );

  return traceItem(
    id: 'verbs:posse',
    lemma: 'posse',
    type: 'Unregelmäßig-posse',
    translation: 'können',
    principalParts: const [('', 'posse'), ('', 'potuī')],
    axes: verbAxes,
    derivation: Derivation(
      type: 'Unregelmäßig-posse',
      recognition: const TypeDeclared(),
      stems: {'praesens': praesens},
      grammar: const Grammar({}, {}, {}, 'de'),
      forms: {
        'ind.praes.akt.1.sg': composed(
          'ind.praes.akt.1.sg',
          'possum',
          'pos',
          'sum',
          tVorS,
        ),
        'konj.impf.akt.1.sg': GeneratedForm(
          formKey: 'konj.impf.akt.1.sg',
          variants: const ['possem'],
          stemName: 'praesens',
          ending: 'sem',
          endingType: 'Unregelmäßig',
        ),
      },
    ),
  );
}

/// fortis: a comparative stem from a default template, with an ending of
/// another type (S14 delegation).
PracticeItem fortis() {
  final stamm = StemFromPart(
    name: 'stamm',
    display: 'Stamm',
    variants: const ['fort'],
    part: 'genitiv',
    sourceWord: 'fortis',
    removedSuffix: 'is',
  );
  final komparativ = StemFromDefault(
    name: 'komparativ',
    display: 'Komparativstamm',
    variants: const ['fortiōr'],
    template: '{stamm}iōr',
    base: stamm,
  );

  return traceItem(
    id: 'nouns:fortis',
    lemma: 'fortis',
    type: 'I-Deklination-mf',
    translation: 'tapfer',
    principalParts: const [('', 'fortis'), ('', 'forte')],
    axes: adjectiveAxes,
    dataFileId: 'nouns',
    derivation: Derivation(
      type: 'I-Deklination-mf',
      recognition: const TypeDeclared(),
      stems: {'stamm': stamm, 'komparativ': komparativ},
      grammar: const Grammar({}, {}, {}, 'de'),
      forms: {
        'komp.gen.sg': GeneratedForm(
          formKey: 'komp.gen.sg',
          variants: const ['fortiōris'],
          stemName: 'komparativ',
          ending: 'is',
          endingType: 'Konsonantische-Deklination-mf',
        ),
      },
    ),
  );
}

/// hortārī: a deponent. The key is active, the form passive (S10).
PracticeItem hortari() {
  final praesens = StemFromPart(
    name: 'praesens',
    display: 'Präsensstamm',
    variants: const ['hortā'],
    part: 'infinitiv',
    sourceWord: 'hortārī',
    removedSuffix: 'rī',
  );

  return traceItem(
    id: 'verbs:hortari',
    lemma: 'hortārī',
    type: 'A-Konjugation',
    translation: 'ermahnen',
    principalParts: const [('', 'hortārī')],
    axes: verbAxes,
    derivation: Derivation(
      type: 'A-Konjugation',
      recognition: const TypeByRule(
        sourceWord: 'hortārī',
        suffix: 'ārī',
        candidateTypes: ['A-Konjugation'],
      ),
      stems: {'praesens': praesens},
      grammar: const Grammar({}, {}, {}, 'de'),
      deponentKeys: const {'ind.praes.akt.1.sg'},
      forms: {
        'ind.praes.akt.1.sg': GeneratedForm(
          formKey: 'ind.praes.akt.1.sg',
          variants: const ['hortor'],
          stemName: 'praesens',
          ending: 'or',
          endingType: 'A-Konjugation',
          sandhiRule: aAusfall,
        ),
      },
    ),
  );
}

/// afferre: both prefix spellings are correct (Q12, sandhi `variant: true`).
PracticeItem afferre() {
  final praesens = StemFromPart(
    name: 'praesens',
    display: 'Präsensstamm',
    variants: const ['affer', 'adfer'],
    part: 'infinitiv',
    sourceWord: 'afferre',
    removedSuffix: 're',
  );

  return traceItem(
    id: 'verbs:afferre',
    lemma: 'afferre',
    type: 'Unregelmäßig-ferre',
    translation: 'herbeibringen',
    principalParts: const [('', 'afferre')],
    axes: verbAxes,
    derivation: Derivation(
      type: 'Unregelmäßig-ferre',
      recognition: const TypeDeclared(),
      stems: {'praesens': praesens},
      grammar: const Grammar({}, {}, {}, 'de'),
      forms: {
        'ind.praes.akt.1.sg': GeneratedForm(
          formKey: 'ind.praes.akt.1.sg',
          variants: const ['afferō', 'adferō'],
          stemName: 'praesens',
          ending: 'ō',
          endingType: 'Unregelmäßig-ferre',
        ),
      },
    ),
  );
}

/// abīre: the perfect has two spellings in the data (S9, part list).
PracticeItem abire() => traceItem(
  id: 'verbs:abire',
  lemma: 'abīre',
  type: 'Unregelmäßig-ire',
  translation: 'weggehen',
  principalParts: const [('', 'abīre'), ('', 'abiī')],
  axes: verbAxes,
  derivation: Derivation(
    type: 'Unregelmäßig-ire',
    recognition: const TypeDeclared(),
    grammar: const Grammar({}, {}, {}, 'de'),
    forms: {
      'ind.perf.akt.1.sg': GivenForm(
        formKey: 'ind.perf.akt.1.sg',
        variants: const ['abiī', 'abīvī'],
      ),
    },
  ),
);

/// Every hand-made item, for the sweeps.
List<PracticeItem> traceItems() => [
  amare(),
  capere(),
  regere(),
  posse(),
  fortis(),
  hortari(),
  afferre(),
  abire(),
];

/// The German text of a line, as the screens render it.
String renderDe(Map<String, String> texts, ExplanationLine line) {
  final text = texts[line.key];
  if (text == null) throw StateError('de.json has no key ${line.key}');
  return text.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (match) => line.params[match.group(1)]!,
  );
}

/// en.json flattened to "explain.diag.noMatch" style keys.
Future<Map<String, String>> englishTexts() =>
    _texts('assets/flutter_i18n/en.json');

/// de.json flattened to "explain.diag.noMatch" style keys.
Future<Map<String, String>> germanTexts() =>
    _texts('assets/flutter_i18n/de.json');

Future<Map<String, String>> _texts(String path) async {
  Map<String, String> flatten(Map<String, dynamic> json, String prefix) {
    final flat = <String, String>{};
    json.forEach((key, value) {
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        flat.addAll(flatten(value, path));
      } else {
        flat[path] = value as String;
      }
    });
    return flat;
  }

  return flatten(
    jsonDecode(await loadAssetText(path)) as Map<String, dynamic>,
    '',
  );
}

/// The data has no dictionary form of its own (every form is derived), so the
/// GivenForm branch is pinned on a hand-made item of a type the data uses. It
/// carries the loaded grammar, because the Erkennen step reads the word class
/// of its type from there (S19).
Future<PracticeItem> givenItem() async => traceItem(
  id: 'verbs:abire',
  lemma: 'abīre',
  type: 'Unregelmäßig',
  translation: 'weggehen',
  principalParts: const [('', 'abīre'), ('', 'abiī')],
  axes: verbAxes,
  derivation: Derivation(
    type: 'Unregelmäßig',
    recognition: const TypeDeclared(),
    grammar: (await loadAllPracticeItems()).first.derivation.grammar,
    forms: {
      'ind.perf.akt.1.sg': GivenForm(
        formKey: 'ind.perf.akt.1.sg',
        variants: const ['abiī', 'abīvī'],
      ),
    },
  ),
);
