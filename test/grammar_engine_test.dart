// The engine goldens. `test/fixtures/paradigms.txt` holds every fixture
// item's full paradigm; it was checked form by form against the school
// paradigms of the grammar spike. The named goldens below repeat the cases
// the plan calls out, so a regression names the rule it broke instead of a
// line number in the snapshot.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/grammar/type_inference.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/form_label.dart';

const _nounsPath = 'test/fixtures/grammar_examples.yaml';
const _verbsPath = 'test/fixtures/grammar_examples_verbs.yaml';
const _paradigmsPath = 'test/fixtures/paradigms.txt';

final _sources = {
  _nounsPath: File(_nounsPath).readAsStringSync(),
  _verbsPath: File(_verbsPath).readAsStringSync(),
};

final List<GrammarFile> _files = parseGrammarFiles(_sources);
final GrammarEngine _engine = GrammarEngine(_files);

GrammarFile _fileOf(String itemId) =>
    _files.firstWhere((file) => file.items.any((item) => item.id == itemId));

Derivation _of(String itemId) =>
    _engine.of(_fileOf(itemId).dataFileId, itemId);

FormDerivation _form(String itemId, FormKey key) {
  final derivation = _of(itemId);
  final form = derivation.forms[key] ?? derivation.internal[key];
  if (form == null) fail('$itemId has no key $key');
  return form;
}

/// A golden: the accepted spellings in order, then the trace.
void _golden(String itemId, FormKey key, String variants, String trace) {
  final form = _form(itemId, key);
  expect(form.variants.join(' / '), variants, reason: '$itemId $key');
  expect(_trace(form), trace, reason: '$itemId $key trace');
}

void main() {
  group('Paradigmen', () {
    test('every fixture item derives to the recorded paradigm', () {
      final want = File(_paradigmsPath).readAsStringSync().split('\n');
      final got = _renderAll().split('\n');
      for (var i = 0; i < want.length && i < got.length; i++) {
        expect(got[i], want[i], reason: '$_paradigmsPath line ${i + 1}');
      }
      expect(got.length, want.length, reason: 'number of lines');
    });
  });

  group('Formengoldens', () {
    test('composition with a mapped tempus', () {
      _golden(
        'amare',
        'konj.plusq.pass.1.sg',
        'amātus essem',
        'compose(amare[part.perf.pass.sg.nom.m]=amātus '
            '+ esse[konj.impf.akt.1.sg]=essem, join=" ")',
      );
      _golden(
        'amare',
        'ind.perf.pass.1.sg',
        'amātus sum',
        'compose(amare[part.perf.pass.sg.nom.m]=amātus '
            '+ esse[ind.praes.akt.1.sg]=sum, join=" ")',
      );
    });

    test('a template list gives a variant', () {
      _golden(
        'amare',
        'ind.perf.akt.3.pl',
        'amāvērunt / amāvēre',
        '{perfekt}+ērunt [Perfekt-System]',
      );
      _golden(
        'amare',
        'part.praes.akt.sg.abl.m',
        'amante / amantī',
        '{ppa}+e [3-Endungen-Partizip]',
      );
    });

    test('a delegate binds the comparison stem', () {
      _golden(
        'fortis',
        'gen.sg.m.komp',
        'fortiōris',
        '{kstamm}+iōris [Komparativ-Endungen]',
      );
      _golden(
        'fortis',
        'adv.komp',
        'fortius',
        '{kstamm}+ius [Komparativ-Endungen]',
      );
      _golden(
        'fortis',
        'dat.pl.m.sup',
        'fortissimīs',
        '{sup}+īs [a-o-Endungen]',
      );
      _golden(
        'bonus',
        'nom.sg.m.komp',
        'melior',
        '{kstamm}+ior [Komparativ-Endungen]',
      );
    });

    test('an item override is irregular and keeps the rule form', () {
      _golden('bonus', 'adv.pos', 'bene', 'irregular (rule: bonē)');
      final bene = _form('bonus', 'adv.pos') as IrregularForm;
      expect(bene.regular, isA<GeneratedForm>());
      expect(bene.regular!.result, 'bonē');
    });

    test('posse: overrides over a composition', () {
      _golden(
        'posse',
        'ind.praes.akt.1.sg',
        'possum',
        'compose(praefix:pos(t_s) + esse[ind.praes.akt.1.sg]=sum, join="")',
      );
      _golden('posse', 'ind.perf.akt.1.sg', 'potuī', '{perfekt}+ī '
          '[Perfekt-System]');
      _golden('posse', 'konj.impf.akt.1.sg', 'possem',
          'irregular (rule: potessem)');
      final possem = _form('posse', 'konj.impf.akt.1.sg') as IrregularForm;
      expect(possem.regular, isA<ComposedForm>());
      expect(possem.regular!.result, 'potessem');
    });

    test('prodesse: the prefix loses its d before a consonant', () {
      _golden(
        'prodesse',
        'ind.praes.akt.1.sg',
        'prōsum',
        'compose(praefix:prō(d_ausfall) + esse[ind.praes.akt.1.sg]=sum, '
            'join="")',
      );
      _golden(
        'prodesse',
        'ind.praes.akt.2.sg',
        'prōdes',
        'compose(praefix:prōd + esse[ind.praes.akt.2.sg]=es, join="")',
      );
      _golden(
        'prodesse',
        'part.fut.akt.sg.nom.m',
        'prōfutūrus',
        'compose(praefix:prō(d_ausfall) + esse[part.fut.akt.sg.nom.m]'
            '=futūrus, join="")',
      );
    });

    test('afferre: the assimilated spelling is shown, ad- accepted', () {
      _golden(
        'afferre',
        'ind.praes.akt.1.sg',
        'afferō / adferō',
        'compose(praefix:af(d_angleich) + ferre[ind.praes.akt.1.sg]=ferō, '
            'join="")',
      );
      _golden(
        'afferre',
        'ind.perf.akt.1.sg',
        'attulī / adtulī',
        'compose(praefix:at(d_angleich) + ferre[ind.perf.akt.1.sg]=tulī, '
            'join="")',
      );
      _golden(
        'afferre',
        'part.perf.pass.sg.nom.n',
        'allātum / adlātum',
        'compose(praefix:al(d_angleich) + '
            'ferre[part.perf.pass.sg.nom.n]=lātum, join="")',
      );
    });

    test('a composition passes on the variants of its parts', () {
      _golden(
        'abire',
        'ind.perf.akt.1.sg',
        'abiī / abīvī',
        'compose(praefix:ab + ire[ind.perf.akt.1.sg]=iī, join="")',
      );
    });

    test('a part list gives a stem variant', () {
      expect(_of('bonus').stems['sup']!.variants, ['optim', 'optum']);
      _golden('bonus', 'nom.sg.m.sup', 'optimus / optumus',
          '{sup}+us [a-o-Endungen]');
    });

    test('an empty ending', () {
      _golden('acer', 'nom.sg.m.pos', 'ācer', '{nom_m}+ [3-Endungen]');
    });
  });

  group('Deponentien (S10)', () {
    test('hortārī is a deponent in every tempus', () {
      _golden('hortari', 'ind.praes.akt.1.sg', 'hortor',
          '{praesens}+or [A-Konjugation] [a_ausfall]');
      expect(_of('hortari').deponentKeys, contains('ind.praes.akt.1.sg'));
      _golden(
        'hortari',
        'inf.fut.akt',
        'hortātūrum esse',
        'compose(hortari[part.fut.akt.sg.akk.m]=hortātūrum '
            '+ esse[inf.praes.akt]=esse, join=" ")',
      );
      expect(_of('hortari').deponentKeys, isNot(contains('inf.fut.akt')));
      final keys = _keys('hortari');
      expect(keys, isNot(contains('inf.fut.pass')));
      expect(keys.where((key) => key.startsWith('imp.fut')), isEmpty);
    });

    test('audēre is a semi-deponent', () {
      _golden(
        'audere',
        'ind.perf.akt.1.sg',
        'ausus sum',
        'compose(audere[part.perf.pass.sg.nom.m]=ausus '
            '+ esse[ind.praes.akt.1.sg]=sum, join=" ")',
      );
      expect(_of('audere').deponentKeys, contains('ind.perf.akt.1.sg'));
      expect(
        _keys('audere').where((key) => key.startsWith('ind.praes.pass')),
        isEmpty,
      );
      expect(_form('audere', 'ind.praes.akt.1.sg').result, 'audeō');
    });

    test('an item override names the key after the move (Q14)', () {
      final engine = _patched({
        'parts: {infinitiv: hortārī, praesens_1sg: hortor}\n'
            '    deponent: all':
            'parts: {infinitiv: hortārī, praesens_1sg: hortor}\n'
            '    deponent: all\n'
            '    forms: {ind.praes.akt.1.sg: "hortō"}',
      });
      final form = engine.of('verbs', 'hortari').forms['ind.praes.akt.1.sg']!;
      expect(form.result, 'hortō');
      expect((form as IrregularForm).regular!.result, 'hortor');
    });
  });

  group('Schulstämme (S18)', () {
    test('A-Konjugation', () {
      expect(_of('amare').stems['praesens']!.stem, 'amā');
      _golden('amare', 'ind.praes.akt.1.sg', 'amō',
          '{praesens}+ō [A-Konjugation] [a_ausfall]');
      _golden('amare', 'ind.praes.akt.3.sg', 'amat',
          '{praesens}+t [A-Konjugation] [kurz_t]');
      _golden('amare', 'ind.praes.akt.3.pl', 'amant',
          '{praesens}+nt [A-Konjugation] [kurz_nt]');
      _golden('amare', 'konj.praes.akt.1.sg', 'amem',
          '{praesens}+em [A-Konjugation] [a_ausfall]');
      _golden('amare', 'part.praes.akt.sg.gen.m', 'amantis',
          '{ppa}+is [3-Endungen]');
      expect(_of('amare').stems['ppa']!.stem, 'amant');
    });

    test('E-Konjugation', () {
      _golden('monere', 'konj.praes.akt.1.sg', 'moneam',
          '{praesens}+am [E-Konjugation] [vokal_kurz]');
      _golden('monere', 'ind.perf.akt.1.sg', 'monuī',
          '{perfekt}+ī [Perfekt-System]');
    });

    test('I-Konjugation', () {
      _golden('audire', 'ind.praes.akt.3.pl', 'audiunt',
          '{praesens}+unt [I-Konjugation] [vokal_kurz]');
      _golden('audire', 'ind.fut.akt.2.sg', 'audiēs',
          '{praesens}+ēs [I-Konjugation] [vokal_kurz]');
      _golden('audire', 'ind.praes.akt.3.sg', 'audit',
          '{praesens}+t [I-Konjugation] [kurz_t]');
    });

    test('Konsonantische: no rule fires', () {
      _golden('regere', 'ind.praes.akt.3.sg', 'regit',
          '{praesens}+it [Konsonantische]');
      _golden('regere', 'ind.fut.pass.2.sg', 'regēris',
          '{praesens}+ēris [Konsonantische]');
    });

    test('Mischkonjugation', () {
      _golden('capere', 'inf.praes.akt', 'capere',
          '{praesens}+re [I-Konjugation] [i_e_r]');
      _golden('capere', 'ind.praes.pass.2.sg', 'caperis',
          '{praesens}+ris [I-Konjugation] [i_e_r]');
      _golden('capere', 'imp.praes.akt.2.sg', 'cape',
          '{praesens}+ [I-Konjugation] [i_e_auslaut]');
      _golden('capere', 'inf.praes.pass', 'capī',
          '{praesens}+ī [Mischkonjugation] [i_ausfall]');
    });

    test('the theme vowel comes from the type, not from the item', () {
      final engine = _patched({
        'parts: {infinitiv: amāre, praesens_1sg: amō}':
            'parts: {infinitiv: amare, praesens_1sg: amo}',
      });
      final forms = engine.of('verbs', 'amare').forms;
      expect(forms['ind.praes.akt.2.sg']!.result, 'amās');
      expect(forms['ind.praes.akt.1.pl']!.result, 'amāmus');
    });

    test('every rule fires for the type that lists it', () {
      final fired = _firedRules();
      final listed = <String, Set<String>>{};
      for (final file in _files) {
        for (final item in file.items) {
          listed[item.typeName] = file.type(item.typeName).sandhi.toSet();
        }
      }
      expect(listed.values.expand((rules) => rules), isNotEmpty);
      for (final entry in listed.entries) {
        expect(entry.value.difference(fired[entry.key] ?? {}), isEmpty,
            reason: 'type ${entry.key}');
      }
    });
  });

  group('Schlüsselmengen', () {
    test('amāre: the perfect passive, and the keys that do not exist', () {
      final keys = _keys('amare');
      expect(
        keys.where((key) => key.startsWith('ind.perf.pass')).toList(),
        [
          'ind.perf.pass.1.sg',
          'ind.perf.pass.1.pl',
          'ind.perf.pass.2.sg',
          'ind.perf.pass.2.pl',
          'ind.perf.pass.3.sg',
          'ind.perf.pass.3.pl',
        ],
      );
      expect(keys.where((key) => key.startsWith('imp.perf')), isEmpty);
      expect(keys.where((key) => key.startsWith('konj.fut2')), isEmpty);
    });

    test('posse has no imperative, no participle and no future infinitive',
        () {
      final keys = _keys('posse');
      expect(keys.where((key) => key.startsWith('imp')), isEmpty);
      expect(keys.where((key) => key.startsWith('part')), isEmpty);
      expect(keys, isNot(contains('inf.fut.akt')));
      expect(keys, contains('inf.praes.akt'));
    });
  });

  group('Invarianten I1-I7', () {
    test('the fixtures hold internal forms', () {
      final internal = [
        for (final file in _files)
          for (final item in file.items)
            ..._engine.of(file.dataFileId, item.id).internal.keys,
      ];
      expect(internal, isNotEmpty);
    });

    test('over every fixture item and key', () {
      for (final file in _files) {
        for (final item in file.items) {
          _checkInvariants(file, item, _engine.of(file.dataFileId, item.id));
        }
      }
    });
  });

  group('Typerkennung (S11)', () {
    test('amāre: rule āre on the infinitive', () {
      final recognition = _of('amare').recognition as TypeByRule;
      expect(recognition.sourceWord, 'amāre');
      expect(recognition.suffix, 'āre');
      expect(recognition.candidateTypes, ['A-Konjugation']);
      expect(typeByRuleAmbiguous(_fileOf('amare').item('amare')), isFalse);
    });

    test('monēre: rule ēre', () {
      final recognition = _of('monere').recognition as TypeByRule;
      expect(recognition.suffix, 'ēre');
      expect(recognition.candidateTypes, ['E-Konjugation']);
    });

    test('capere: the rule leaves three candidates, type: picks one', () {
      final recognition = _of('capere').recognition as TypeByRule;
      expect(recognition.suffix, 'ere');
      expect(recognition.candidateTypes,
          ['Konsonantische', 'Mischkonjugation', 'E-Konjugation']);
      expect(typeByRuleAmbiguous(_fileOf('capere').item('capere')), isTrue);
    });

    test('capere without type: load throws', () {
      expect(
        () => _patched({
          '  - type: Mischkonjugation\n'
              '    translation: fassen': '  - translation: fassen',
        }),
        throwsA(isA<SchemaError>()),
      );
    });

    test('capiō: a rule on another part', () {
      final file = parseGrammarFile(_miniSource, path: 'mini.yaml');
      final derivation = GrammarEngine([file]).of('mini', 'capio');
      final recognition = derivation.recognition as TypeByRule;
      expect(recognition.sourceWord, 'capiō');
      expect(recognition.suffix, 'iō');
      expect(recognition.candidateTypes,
          ['I-Konjugation', 'Mischkonjugation']);
      expect(derivation.forms['pl']!.result, 'capimus');
    });
  });

  group('Ladezeit', () {
    test('the fixtures fifty times', () {
      final watch = Stopwatch()..start();
      for (var run = 0; run < 50; run++) {
        final files = parseGrammarFiles(_sources);
        final engine = GrammarEngine(files);
        for (final file in files) {
          for (final item in file.items) {
            engine.of(file.dataFileId, item.id);
          }
        }
      }
      watch.stop();
      // ignore: avoid_print
      print('load+derive, fixtures x50: ${watch.elapsedMilliseconds} ms');
    });
  });
}

// ------------------------------------------------------------------ helpers

List<FormKey> _keys(String itemId) {
  final derivation = _of(itemId);
  return [...derivation.forms.keys, ...derivation.internal.keys];
}

/// Parses the verbs fixture with [edits] applied to its source. Every left
/// side must occur exactly once, so a changed fixture fails here and not in
/// an unrelated golden.
GrammarEngine _patched(Map<String, String> edits) {
  var source = _sources[_verbsPath]!;
  for (final edit in edits.entries) {
    expect(edit.key.allMatches(source).length, 1,
        reason: 'patch does not fit the fixture any more: ${edit.key}');
    source = source.replaceFirst(edit.key, edit.value);
  }
  return GrammarEngine(parseGrammarFiles({
    _nounsPath: _sources[_nounsPath]!,
    _verbsPath: source,
  }));
}

/// The ids of the sandhi rules that fire, by the name of the item's type.
Map<String, Set<String>> _firedRules() {
  final fired = <String, Set<String>>{};
  for (final file in _files) {
    for (final item in file.items) {
      final ofType = fired.putIfAbsent(item.typeName, () => {});
      void add(SandhiRule? rule) {
        if (rule != null) ofType.add(rule.id);
      }

      final derivation = _engine.of(file.dataFileId, item.id);
      for (final stem in derivation.stems.values) {
        if (stem is StemFromDefault) add(stem.sandhiRule);
      }
      for (final form in [
        ...derivation.forms.values,
        ...derivation.internal.values,
      ]) {
        _walk(form, (part) {
          if (part is AffixPart) add(part.sandhiRule);
        }, add);
      }
    }
  }
  return fired;
}

/// Visits [form] and the derivations below it (`regular`, composed parts).
void _walk(
  FormDerivation form,
  void Function(FormPart part) onPart,
  void Function(SandhiRule? rule) onRule,
) {
  switch (form) {
    case GeneratedForm(:final sandhiRule):
      onRule(sandhiRule);
    case ComposedForm(:final parts):
      for (final part in parts) {
        onPart(part);
      }
    case IrregularForm(:final regular):
      if (regular != null) _walk(regular, onPart, onRule);
    case GivenForm():
      break;
  }
}

void _checkInvariants(GrammarFile file, GrammarItem item, Derivation d) {
  final plan = file.keysByItem[item.id]!;
  final where = 'item ${item.id}';

  // I1: the key plan and the derivation agree, in S7 order.
  expect(d.forms.keys.toSet(), plan.emitted, reason: where);
  expect(d.internal.keys.toSet(), plan.internal, reason: where);
  final sorted = d.forms.keys.toList()
    ..sort((a, b) =>
        file.axes.compare(file.axes.parseKey(a), file.axes.parseKey(b)));
  expect(d.forms.keys.toList(), sorted, reason: '$where: S7 order');

  final rules = [
    for (final id in file.type(item.typeName).sandhi) file.sandhi[id]!,
  ];

  for (final entry in {...d.forms, ...d.internal}.entries) {
    final key = entry.key;
    final form = entry.value;
    expect(form.formKey, key, reason: '$where $key');

    // I6.
    expect(form.variants.first, form.result, reason: '$where $key');
    expect(
      form.variants.map(norm).toSet().length,
      form.variants.length,
      reason: '$where $key: two variants are norm-equal',
    );

    switch (form) {
      // I2.
      case GeneratedForm(:final stemName, :final ending, :final sandhiRule):
        final stem = d.stems[stemName];
        expect(stem, isNotNull, reason: '$where $key: stem $stemName');
        final seam = sandhi(rules, stem!.stem, ending,
            wordFinal: true, lemma: item.lemma);
        expect(seam.rule?.id, sandhiRule?.id, reason: '$where $key');
        expect(seam.text + ending, form.result, reason: '$where $key');

      // I3.
      case ComposedForm(:final parts, :final join):
        expect(parts.map((part) => part.text).join(join), form.result,
            reason: '$where $key');
        for (final part in parts) {
          if (part is LexemeFormPart) {
            expect(part.derivation.result, part.text, reason: '$where $key');
          }
        }

      // I4.
      case IrregularForm(:final regular):
        if (regular != null) {
          expect(regular.formKey, key, reason: '$where $key');
          expect(norm(regular.result), isNot(norm(form.result)),
              reason: '$where $key');
        }

      case GivenForm():
        break;
    }
  }

  // I2 for the stems built by a template.
  for (final stem in d.stems.values) {
    if (stem is! StemFromDefault) continue;
    final rest = stem.template.substring(stem.template.indexOf('}') + 1);
    final seam = sandhi(rules, stem.base.stem, rest,
        wordFinal: false, lemma: item.lemma);
    expect(seam.rule?.id, stem.sandhiRule?.id, reason: '$where ${stem.name}');
    expect(seam.text + rest, stem.stem, reason: '$where ${stem.name}');
  }

  // I5.
  if (d.stems.isEmpty) {
    for (final form in d.forms.values) {
      expect(form, isNot(isA<GeneratedForm>()), reason: where);
      if (form is ComposedForm) {
        expect(form.parts.whereType<AffixPart>(), isEmpty, reason: where);
      }
    }
  }

  // I7.
  for (final key in d.deponentKeys) {
    expect(file.axes.parseKey(key)['genus_verbi'], 'akt', reason: '$where $key');
    final passive = file.axes.formatKey({
      ...file.axes.parseKey(key),
      'genus_verbi': 'pass',
    });
    expect(plan.deponent, contains(key), reason: '$where $key');
    expect(d.forms, isNot(contains(passive)), reason: '$where $key');
  }
}

// ----------------------------------------------------------------- snapshot

String _renderAll() {
  final out = StringBuffer();
  for (final file in _files) {
    for (final item in file.items) {
      out.writeln('## ${item.id} (${file.dataFileId}) ${item.typeName}');
      final derivation = _engine.of(file.dataFileId, item.id);
      for (final stem in derivation.stems.values) {
        out.writeln('- stem ${stem.name} = ${stem.variants.join(" / ")}');
      }
      for (final entry in {
        ...derivation.forms,
        ...derivation.internal,
      }.entries) {
        final deponent =
            derivation.deponentKeys.contains(entry.key) ? ' (deponent)' : '';
        out.writeln('${entry.key}$deponent | '
            '${entry.value.variants.join(" / ")} | ${_trace(entry.value)}');
      }
    }
  }
  return out.toString();
}

String _trace(FormDerivation form) => switch (form) {
      GivenForm() => 'given',
      GeneratedForm(
        :final stemName,
        :final ending,
        :final endingType,
        :final sandhiRule
      ) =>
        '{$stemName}+$ending [$endingType]'
            '${sandhiRule == null ? "" : " [${sandhiRule.id}]"}',
      ComposedForm(:final parts, :final join) =>
        'compose(${parts.map((part) => switch (part) {
              AffixPart(:final stemName, :final text, :final sandhiRule) =>
                '$stemName:$text'
                    '${sandhiRule == null ? "" : "(${sandhiRule.id})"}',
              LexemeFormPart(:final lexemeId, :final key) =>
                '$lexemeId[$key]=${part.text}',
            }).join(" + ")}, join="$join")',
      IrregularForm(:final regular) =>
        'irregular${regular == null ? "" : " (rule: ${regular.result})"}',
    };

// A file of its own: `capiō` has no infinitive, so the rule must read
// another part (S11), which the verbs fixture cannot show.
const _miniSource = '''
data_file_id: mini

axes:
  numerus: {name: Numerus, values: {sg: Singular, pl: Plural}}

label:
  head: [numerus]
  tail: []
  merge_axis: numerus

parts:
  praesens_1sg: {label: "1. Person Singular"}

defaults:
  given_part: praesens_1sg
  lemma_part: praesens_1sg

type_inference:
  praesens_1sg:
    - {suffix: "iō", types: [I-Konjugation, Mischkonjugation]}

types:
  I-Konjugation:
    required_stems: [wurzel]
    stems:
      wurzel: {from: praesens_1sg, remove: "iō", display: Wortstock}
    forms:
      sg: "{wurzel}iō"
      pl: "{wurzel}īmus"

  Mischkonjugation:
    required_stems: [wurzel]
    stems:
      wurzel: {from: praesens_1sg, remove: "iō", display: Wortstock}
    forms:
      sg: "{wurzel}iō"
      pl: "{wurzel}imus"

items:
  - type: Mischkonjugation
    translation: fassen
    parts: {praesens_1sg: capiō}
''';
