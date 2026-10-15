import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/test_axes.dart';

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
          {'stem': 'domin'},
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
        ['explain.stem', {'stem': 'am'}],
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
            {'stem': 'reg', 'source': 'regis', 'suffix': 'is'},
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

    for (final asset in [_nouns, _verbs]) {
      for (final item in await loadPracticeItems(asset)) {
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

  return answers
      .where((a) => a.toLowerCase() != correct.toLowerCase())
      .toList();
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
