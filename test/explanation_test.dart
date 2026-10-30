import 'dart:convert';

import 'package:latin_practice/data/asset_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/trace_fixtures.dart';

const _nouns = 'lib/data/latin_nouns.yaml';
const _verbs = 'lib/data/latin_verbs.yaml';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T-expl-1 goldens', () {
    late List<PracticeItem> nouns;

    setUp(() async {
      nouns = await loadPracticeItems(_nouns);
    });

    test('dominus: what dominis is', () {
      final item = nouns.firstWhere((i) => i.lemma == 'dominus');
      expect(_pairs(explainWrongAnswer(item, 'gen.pl', 'dominis')), [
        [
          'explain.diag.otherForm',
          {'answer': 'dominis', 'labels': 'Dativ/Ablativ Plural'},
        ],
      ]);
    });
  });

  group('plan 3.8 fallbacks', () {
    test(
      'an explicit form that differs from the rule keeps the rule',
      () async {
        final verbs = await loadPracticeItems(_verbs);
        final item = verbs.firstWhere((i) => i.lemma == 'dīcere');
        final form =
            item.derivation.forms['imp.praes.akt.2.sg']! as IrregularForm;
        expect(form.regular, isNotNull);
        final lines = explainWrongAnswer(
          item,
          'imp.praes.akt.2.sg',
          form.regular!.result,
        );
        expect(lines.last.key, 'explain.diag.regularInsteadOfIrregular');
      },
    );
  });

  group('classification lines', () {
    test('a picked label names the form it would be', () async {
      final nouns = await loadPracticeItems(_nouns);
      final item = nouns.firstWhere((i) => i.lemma == 'dominus');
      final picked = item.formLabels[item.formOrder.indexOf('gen.pl')];
      expect(_pair(explainPickedLabel(item, picked, 'Genitiv Plural')), [
        'explain.pickedWouldBe',
        {'picked': 'Genitiv Plural', 'form': 'dominōrum (domin + ōrum)'},
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

    List<String> german(List<ExplanationLine> lines) => [
      for (final line in lines) renderDe(de, line),
    ];

    test('īre: the impersonal passive is composed by the rule', () async {
      final verbs = await loadPracticeItems(_verbs);
      final item = verbs.firstWhere((i) => i.lemma == 'īre');
      final form = item.derivation.forms['konj.plusq.pass.3.sg']!;
      expect(form, isA<ComposedForm>());
      expect(form.variants, ['itum esset']);
      expect(item.derivation.forms, isNot(contains('konj.plusq.pass.3.pl')));
    });

    test('hortor: a deponent says so before the form', () {
      final lines = explainWrongAnswer(
        hortari(),
        'ind.praes.akt.1.sg',
        'hortō',
      );
      expect(_pairs(lines).first, [
        'explain.deponent',
        {'label': 'Präsens: 1. Person Singular'},
      ]);
      expect(
        german(lines).first,
        'Präsens: 1. Person Singular ist ein Deponens: '
        'passive Form, aktive Bedeutung',
      );
    });

    test('amāvērunt: the other spelling is correct too', () {
      final lines = explainWrongAnswer(
        amare(),
        'ind.perf.akt.3.pl',
        'amāvērat',
      );
      expect(german(lines).first, 'auch richtig: amāvēre');
    });

    test('afferō: both prefix spellings count', () {
      final lines = explainWrongAnswer(
        afferre(),
        'ind.praes.akt.1.sg',
        'afferu',
      );
      expect(german(lines).first, 'auch richtig: adferō');
    });

    test('abiī: the perfect has two spellings in the data', () {
      final lines = explainWrongAnswer(abire(), 'ind.perf.akt.1.sg', 'abiō');
      expect(german(lines).first, 'auch richtig: abīvī');
    });

    test(
      'Q11 A: a correct answer without macrons gets the marked spelling',
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
      },
    );
  });

  test('T-expl-2 every line exists in de.json with all its params', () async {
    final texts = _flatten(
      jsonDecode(await loadAssetText('assets/flutter_i18n/de.json'))
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
