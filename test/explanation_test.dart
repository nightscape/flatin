import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/diagnosis.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/test_axes.dart';
import 'support/trace_fixtures.dart';

const _nouns = 'lib/data/latin_nouns.yaml';
const _verbs = 'lib/data/latin_verbs.yaml';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T-expl-1 goldens', () {
    late List<PracticeItem> nouns;
    late List<PracticeItem> verbs;

    setUp(() async {
      nouns = await loadPracticeItems(_nouns);
      verbs = await loadPracticeItems(_verbs);
    });

    test('dominus: rule, stem, ending, and what dominis is', () {
      final item = nouns.firstWhere((i) => i.lemma == 'dominus');
      expect(_pairs(explainWrongAnswer(item, 'genitive_plural', 'dominis')), [
        [
          'explain.typeByRule',
          {
            'word': 'dominus',
            'suffix': 'us',
            'type': 'O-Deklination-maskulinum',
          },
        ],
        [
          'explain.stem',
          {'display': 'Stamm', 'stem': 'domin'},
        ],
        [
          'explain.generated',
          {
            'label': 'Genitiv Plural',
            'stem': 'domin',
            'ending': 'orum',
            'result': 'dominorum',
          },
        ],
        [
          'explain.diag.otherForm',
          {'answer': 'dominis', 'labels': 'Dativ/Ablativ Plural'},
        ],
      ]);
    });

    // The infinitive is the only principal part, so the stem is one cut from
    // it and the explanation names no intermediate form.
    test('amāre: the stem is cut from the infinitive', () {
      final item = verbs.firstWhere((i) => i.lemma == 'amāre');
      final lines = explainWrongAnswer(
        item,
        'praesens_third_person_singular',
        'amet',
      );
      expect(_pairs(lines).take(3), [
        [
          'explain.typeByRule',
          {'word': 'amāre', 'suffix': 'āre', 'type': 'A-Konjugation'},
        ],
        [
          'explain.stem',
          {'display': 'Stamm', 'stem': 'am'},
        ],
        [
          'explain.generated',
          {
            'label': 'Präsens: 3. Person Singular',
            'stem': 'am',
            'ending': 'at',
            'result': 'amat',
          },
        ],
      ]);
    });

    test('rex: the stem comes from the genitive, no rule names the type', () {
      final item = nouns.firstWhere((i) => i.lemma == 'regis');
      expect(
        _pairs(explainWrongAnswer(item, 'dative_singular', 'rexi')).take(2),
        [
          [
            'explain.typeDeclared',
            {'word': 'rex, regis', 'type': 'Konsonantische-Deklination-mf'},
          ],
          [
            'explain.stemSource',
            {
              'display': 'Stamm',
              'stem': 'reg',
              'source': 'regis',
              'suffix': 'is',
            },
          ],
        ],
      );
    });

    // "capere" matches the macron-blind "ēre" rule first, which names only
    // E-Konjugation, so no rule confirms the declared Mischkonjugation.
    test('capio: the type is declared and the Perfekt has no template', () {
      final item = verbs.firstWhere((i) => i.lemma == 'capere');
      expect(
        _pairs(
          explainWrongAnswer(item, 'perfekt_first_person_singular', 'capi'),
        ).take(2),
        [
          [
            'explain.typeDeclared',
            {'word': 'capio, capere', 'type': 'Mischkonjugation'},
          ],
          [
            'explain.irregular',
            {
              'dictionary': 'capio, capere',
              'label': 'Perfekt: 1. Person Singular',
              'result': 'cepi',
            },
          ],
        ],
      );
    });

    test('is: a type without pattern explains nothing but the forms', () {
      final item = nouns.firstWhere((i) => i.lemma == 'is');
      expect(item.derivation.stems, isEmpty);
      expect(
        _pairs(explainWrongAnswer(item, 'genitive_singular', 'ii')).take(2),
        [
          [
            'explain.typeDeclared',
            {'word': 'is', 'type': 'Pronomen-is-maskulinum'},
          ],
          [
            'explain.irregular',
            {'dictionary': 'is', 'label': 'Genitiv Singular', 'result': 'eius'},
          ],
        ],
      );
    });

    test('manus: the -us rule disagrees with the declared type', () {
      final item = nouns.firstWhere((i) => i.lemma == 'manus');
      expect(
        _pairs(explainWrongAnswer(item, 'dative_singular', 'mano')).first,
        [
          'explain.typeDeclared',
          {'word': 'manus', 'type': 'U-Deklination'},
        ],
      );
    });
  });

  group('plan 3.8 fallbacks', () {
    test(
      'an explicit form that differs from the rule keeps the rule',
      () async {
        final verbs = await loadPracticeItems(_verbs);
        final item = verbs.firstWhere((i) => i.lemma == 'gaudēre');
        final form =
            item.derivation.forms['perfekt_first_person_singular']!
                as IrregularForm;
        expect(form.regular, isNotNull);
        final lines = explainWrongAnswer(
          item,
          'perfekt_first_person_singular',
          form.regular!.result,
        );
        expect(lines.last.key, 'explain.diag.regularInsteadOfIrregular');
      },
    );

    // No item in the data reaches this: every infinitive rule that matches
    // names one type. The branch still has to be true when data changes.
    test('a rule with several candidates names them all', () {
      final item = PracticeItem(
        id: 'verbs:capio',
        lemma: 'capio',
        type: 'Mischkonjugation',
        translation: 'nehmen',
        principalParts: const [('', 'capio')],
        forms: const ['capio'],
        acceptedForms: const [['capio']],
        formLabels: [verbLabel('praes', '1', 'sg')],
        dataFileId: 'verbs',
        formOrder: const ['praesens_first_person_singular'],
        derivation: Derivation(
          type: 'Mischkonjugation',
          recognition: const TypeByRule(
            sourceWord: 'capio',
            suffix: 'io',
            candidateTypes: ['I-Konjugation', 'Mischkonjugation'],
          ),
          forms: {
            'praesens_first_person_singular': GivenForm(
              formKey: 'praesens_first_person_singular',
              variants: const ['capio'],
            ),
          },
          grammar: const Grammar({}),
        ),
      );

      expect(
        _pairs(
          explainWrongAnswer(item, 'praesens_first_person_singular', 'capeo'),
        ).first,
        [
          'explain.typeByRuleAmbiguous',
          {
            'word': 'capio',
            'suffix': 'io',
            'candidates': 'I-Konjugation, Mischkonjugation',
            'type': 'Mischkonjugation',
          },
        ],
      );
    });

    test('a stem rule that matches no suffix is an error, not a guess', () {
      expect(
        () => inferForms(
          {'type': 'A-Deklination', 'word': 'xyz'},
          {
            'A-Deklination': {
              'genitive_singular': '{stem}ae',
              'stem_extraction': 'remove_suffix:a',
            },
          },
          ['nominative_singular', 'genitive_singular'],
          'nominative_singular',
        ),
        throwsStateError,
      );
    });
  });

  group('classification lines', () {
    test('the shown form is traced back to the rule', () async {
      final nouns = await loadPracticeItems(_nouns);
      final item = nouns.firstWhere((i) => i.lemma == 'dominus');
      expect(
        _pairs(explainForm(item, ['dative_plural', 'ablative_plural'])).last,
        [
          'explain.formBackToRule',
          {
            'result': 'dominis',
            'stem': 'domin',
            'ending': 'is',
            'labels': 'Dativ/Ablativ Plural',
          },
        ],
      );
    });

    test('a picked label names the form it would be', () async {
      final nouns = await loadPracticeItems(_nouns);
      final item = nouns.firstWhere((i) => i.lemma == 'dominus');
      final picked = item.formLabels[item.formOrder.indexOf('genitive_plural')];
      expect(_pair(explainPickedLabel(item, picked, 'Genitiv Plural')), [
        'explain.pickedWouldBe',
        {'picked': 'Genitiv Plural', 'form': 'dominorum (domin + orum)'},
      ]);
    });

    test('a label the word does not have says so', () async {
      final nouns = await loadPracticeItems(_nouns);
      final item = nouns.firstWhere((i) => i.lemma == 'dominus');
      expect(_pair(explainPickedLabel(item, null, 'Vokativ Plural')), [
        'explain.pickedMissing',
        {'picked': 'Vokativ Plural'},
      ]);
    });
  });

  group('T-expl-3 the 3.2 trace', () {
    late Map<String, String> de;
    setUp(() async => de = await germanTexts());

    List<String> german(List<ExplanationLine> lines) =>
        [for (final line in lines) renderDe(de, line)];

    test('amō: school stem and the seam rule of the present', () {
      final lines = explainWrongAnswer(amare(), 'ind.praes.akt.1.sg', 'amao');
      expect(_pairs(lines).take(3), [
        [
          'explain.typeByRule',
          {
            'word': 'amāre, amāvī, amātum',
            'suffix': 'āre',
            'type': 'A-Konjugation',
          },
        ],
        [
          'explain.stemDefault',
          {
            'display': 'Präsensstamm',
            'stem': 'amā',
            'base': 'amāre − āre',
            'rest': 'ā',
          },
        ],
        [
          'explain.sandhi',
          {
            'label': 'Präsens: 1. Person Singular',
            'before': 'amā + ō',
            'after': 'amō',
            'rule': 'ā fällt vor Vokal aus',
          },
        ],
      ]);
      expect(german(lines).skip(1).take(2), [
        'Präsensstamm amā- (amāre − āre + ā)',
        'Präsens: 1. Person Singular: amā + ō = amō (ā fällt vor Vokal aus)',
      ]);
    });

    test('capere: three candidate types and the seam of the infinitive', () {
      final lines = explainWrongAnswer(capere(), 'inf.praes.akt', 'capīre');
      expect(_pairs(lines).first, [
        'explain.typeByRuleAmbiguous',
        {
          'word': 'capere',
          'suffix': 'ere',
          'candidates':
              'Konsonantische-Konjugation, Mischkonjugation, E-Konjugation',
          'type': 'Mischkonjugation',
        },
      ]);
      expect(
        german(lines)[2],
        'Infinitiv Präsens: capi + re = capere (i wird vor r zu e)',
      );
    });

    test('regit: the connecting vowel is part of the ending', () {
      final lines = explainWrongAnswer(regere(), 'ind.praes.akt.3.sg', 'reget');
      expect(german(lines)[2], 'Präsens: 3. Person Singular: reg + it = regit');
    });

    test('amantis: the PPA stem shortens the vowel before nt', () {
      final lines =
          explainWrongAnswer(amare(), 'part.praes.akt.gen.sg', 'amātis');
      expect(
        german(lines)[1],
        'PPA-Stamm: amā + nt = amant (Vokal vor nt/nd wird kurz)',
      );
      expect(german(lines)[2], endsWith('amant + is = amantis'));
    });

    test('amātus essem: a composed form reads out its parts', () {
      final lines =
          explainWrongAnswer(amare(), 'konj.plusq.pass.1.sg', 'amātus eram');
      expect(_pairs(lines)[1], [
        'explain.composed',
        {
          'label': 'Konjunktiv Plusquamperfekt Passiv: 1. Person Singular',
          'parts': 'amātus + essem',
          'result': 'amātus essem',
        },
      ]);
      expect(
        german(explainForm(amare(), ['konj.plusq.pass.1.sg'])).last,
        'Konjunktiv Plusquamperfekt Passiv: 1. Person Singular: '
        'amātus + essem = amātus essem',
      );
    });

    test('amātūrum esse: S17 names the form "Infinitiv Futur"', () {
      final lines = explainWrongAnswer(amare(), 'inf.fut.akt', 'amāre esse');
      expect(lines[1].params['label'], 'Infinitiv Futur');
    });

    test('possum: the affix seam rule explains the double s', () {
      final lines = explainWrongAnswer(posse(), 'ind.praes.akt.1.sg', 'potsum');
      expect(_pairs(lines)[1], [
        'explain.sandhi',
        {
          'label': 'Präsens: 1. Person Singular',
          'before': 'pot + sum',
          'after': 'possum',
          'rule': 't wird vor s zu s',
        },
      ]);
      expect(
        german(lines)[1],
        'Präsens: 1. Person Singular: pot + sum = possum (t wird vor s zu s)',
      );
    });

    test('potessem: the regular form of an irregular one is composed', () {
      final item = posse();
      expect(
        item.derivation.forms['konj.plusq.akt.1.sg'],
        isA<IrregularForm>().having(
          (f) => f.regular,
          'regular',
          isA<ComposedForm>(),
        ),
      );
      expect(
        diagnose(item, 'konj.plusq.akt.1.sg', 'potessem'),
        isA<RegularInsteadOfIrregular>(),
      );
      expect(
        german(explainWrongAnswer(item, 'konj.plusq.akt.1.sg', 'potessem')).last,
        'Du hast potessem geschrieben – das wäre die regelmäßige Form, '
        'aber Konjunktiv Plusquamperfekt: 1. Person Singular ist hier '
        'unregelmäßig',
      );
    });

    test('fortiōris: a default stem with the ending of another type', () {
      final lines = explainWrongAnswer(fortis(), 'komp.gen.sg', 'fortiōrae');
      expect(_pairs(lines).take(3), [
        [
          'explain.typeDeclared',
          {'word': 'fortis, forte', 'type': 'I-Deklination-mf'},
        ],
        [
          'explain.stemDefault',
          {
            'display': 'Komparativstamm',
            'stem': 'fortiōr',
            'base': 'fortis − is',
            'rest': 'iōr',
          },
        ],
        [
          'explain.generatedOtherType',
          {
            'label': 'Komparativ Genitiv Singular',
            'stem': 'fortiōr',
            'ending': 'is',
            'result': 'fortiōris',
            'endingType': 'Konsonantische-Deklination-mf',
          },
        ],
      ]);
      expect(german(lines)[1], 'Komparativstamm fortiōr- (fortis − is + iōr)');
      expect(
        german(lines)[2],
        'Komparativ Genitiv Singular: fortiōr + is = fortiōris '
        '(Endung der Konsonantische-Deklination-mf)',
      );
    });

    test('hortor: a deponent says so before the form', () {
      final lines =
          explainWrongAnswer(hortari(), 'ind.praes.akt.1.sg', 'hortō');
      expect(_pairs(lines)[1], [
        'explain.deponent',
        {'label': 'Präsens: 1. Person Singular'},
      ]);
      expect(
        german(lines)[1],
        'Präsens: 1. Person Singular ist ein Deponens: '
        'passive Form, aktive Bedeutung',
      );
    });

    test('amāvērunt: the other spelling is correct too', () {
      final lines =
          explainWrongAnswer(amare(), 'ind.perf.akt.3.pl', 'amāvērat');
      expect(german(lines).take(4), [
        'amāre, amāvī, amātum: Endung -āre → A-Konjugation',
        'Perfektstamm amāv- (amāvī − ī)',
        'Perfekt: 3. Person Plural: amāv + ērunt = amāvērunt',
        'auch richtig: amāvēre',
      ]);
    });

    test('afferō: both prefix spellings count', () {
      final lines =
          explainWrongAnswer(afferre(), 'ind.praes.akt.1.sg', 'afferu');
      expect(german(lines)[3], 'auch richtig: adferō');
    });

    test('abiī: the perfect has two spellings in the data', () {
      final lines = explainWrongAnswer(abire(), 'ind.perf.akt.1.sg', 'abiō');
      expect(german(lines)[2], 'auch richtig: abīvī');
    });

    test('Q11 A: a correct answer without macrons gets the marked spelling',
        () {
      final item = amare();
      expect(
        german(explainCorrectAnswer(item, 'ind.perf.akt.3.pl', 'amaverunt')),
        ['Richtig. Mit Längenzeichen: amāvērunt'],
      );
      expect(
        explainCorrectAnswer(item, 'ind.perf.akt.3.pl', 'amāvērunt'),
        isEmpty,
      );
      expect(
        explainCorrectAnswer(item, 'ind.perf.akt.3.pl', 'amāvēre'),
        isEmpty,
      );
    });
  });

  test('T-expl-2 every line exists in de.json with all its params', () async {
    final texts = _flatten(
      jsonDecode(await rootBundle.loadString('assets/flutter_i18n/de.json'))
          as Map<String, dynamic>,
    );

    int lineCount = 0;
    void check(ExplanationLine line, String where) {
      lineCount++;
      final text = texts[line.key];
      expect(text, isNotNull, reason: '$where: unknown key ${line.key}');
      for (final match in RegExp(r'\{(\w+)\}').allMatches(text!)) {
        expect(
          line.params,
          contains(match.group(1)),
          reason: '$where: ${line.key} misses {${match.group(1)}}',
        );
      }
    }

    final sweep = [
      for (final asset in [_nouns, _verbs]) ...await loadPracticeItems(asset),
      ...traceItems(),
    ];
    for (final item in sweep) {
      for (int i = 0; i < item.formOrder.length; i++) {
        final key = item.formOrder[i];
        final where = '${item.translation} $key';
        for (final answer in _wrongAnswers(item, i)) {
          for (final line in explainWrongAnswer(item, key, answer)) {
            check(line, where);
          }
        }
        for (final line in explainForm(item, [key])) {
          check(line, where);
        }
        check(explainPickedLabel(item, item.formLabels[i], 'gewählt'), where);
      }
      check(explainPickedLabel(item, null, 'gewählt'), item.translation);
    }
    expect(lineCount, greaterThan(0));
  });
}

/// The answers the diagnosis sweep uses, for the form at [index].
List<String> _wrongAnswers(PracticeItem item, int index) {
  final correct = item.forms[index];
  final answers = <String>['zzz'];

  final other = item.forms.firstWhere(
    (f) => norm(f) != norm(correct),
    orElse: () => '',
  );
  if (other.isNotEmpty) answers.add(other);

  final form = item.derivation.forms[item.formOrder[index]]!;
  if (form is GeneratedForm) answers.add('xq${form.ending}');

  final stem = item.derivation.stems.values.singleOrNull;
  if (stem != null) {
    for (final entry in item.derivation.grammar.templatesByType.entries) {
      final template = entry.value[item.formOrder[index]];
      if (entry.key == item.type || template == null) continue;
      final candidate = stem.stem + template.endings.first;
      if (norm(candidate) != norm(correct)) answers.add(candidate);
    }
  }

  if (form is IrregularForm && form.regular != null) {
    answers.add(form.regular!.result);
  }

  return answers.where((a) => !item.accepts(index, a)).toList();
}

/// Key and params as a list: records compare maps by identity, lists by value.
List<Object> _pair(ExplanationLine line) => [line.key, line.params];

List<List<Object>> _pairs(List<ExplanationLine> lines) =>
    lines.map(_pair).toList();

/// Flattens the nested JSON into "explain.diag.noMatch" style keys.
Map<String, String> _flatten(Map<String, dynamic> json, [String prefix = '']) {
  final flat = <String, String>{};
  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      flat.addAll(_flatten(value, path));
    } else {
      flat[path] = value as String;
    }
  });
  return flat;
}
