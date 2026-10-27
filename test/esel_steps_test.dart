import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/diagnosis.dart';
import 'package:latin_practice/data/esel_steps.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/german_particle_verb.dart';
import 'support/trace_fixtures.dart';

const _nouns = 'lib/data/latin_nouns.yaml';
const _verbs = 'lib/data/latin_verbs.yaml';

const _esel = [
  EselKind.erkennen,
  EselKind.stamm,
  EselKind.endung,
  EselKind.lautregel,
];

/// The items the classification explains: every one but the vocab items.
Future<List<PracticeItem>> _grammarItems() async => [
  for (final i in await loadAllPracticeItems())
    if (!i.isVocab) i,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> nouns;
  late List<PracticeItem> verbs;

  setUp(() async {
    nouns = await loadPracticeItems(_nouns);
    verbs = await loadPracticeItems(_verbs);
  });

  PracticeItem noun(String lemma) => nouns.firstWhere((i) => i.lemma == lemma);
  PracticeItem verb(String lemma) => verbs.firstWhere((i) => i.lemma == lemma);

  group('T-esel-1 content', () {
    test('dominōrum: type, stem, ending, no sound rule', () {
      final steps = eselSteps(noun('dominus'), 'gen.pl');
      expect(steps.map((s) => s.kind), _esel);
      expect(_answers(steps), [
        'O-Deklination-maskulinum',
        'domin-',
        '-ōrum',
        'esel.noRule',
      ]);
      expect(steps.every((s) => !s.absent), isTrue);
      expect(
        steps[0].options.map((o) => o.text),
        containsAll(<String>['O-Deklination-maskulinum']),
      );
      expect(steps[3].options.map((o) => o.textKey).toSet(), {
        'esel.noRule',
        'esel.soundChanges',
      });
    });

    test('amō: the seam rule is the right option of the Lautregel step', () {
      final steps = eselSteps(verb('amāre'), 'ind.praes.akt.1.sg');
      expect(_answers(steps), [
        'A-Konjugation',
        'amā-',
        '-ō',
        'ā fällt vor Vokal aus',
      ]);
      final right = steps[3].options.firstWhere((o) => o.isRight);
      expect(right.text, 'ā fällt vor Vokal aus');
      expect(
        steps[3].options.firstWhere((o) => !o.isRight).textKey,
        'esel.noRule',
      );
    });

    test('ich mitteile: a glued particle offers no sound rule', () {
      final steps = eselSteps(mitteilen(), 'konj.praes.akt.1.sg');
      expect(steps[3].kind, EselKind.lautregel);
      expect(steps[3].answerKey, 'esel.noRule');
    });

    test('amātus essem: the parts are the Verbinden answer', () {
      final steps = eselSteps(verb('amāre'), 'konj.plusq.pass.1.sg');
      expect(steps.map((s) => s.kind), [..._esel, EselKind.verbinden]);
      expect(steps[1].absent, isTrue);
      expect(steps[1].answerKey, 'esel.absent.stamm');
      expect(steps[2].absent, isTrue);
      expect(steps.last.answer, 'amātus + essem');
      final distractor = steps.last.options.firstWhere((o) => !o.isRight);
      expect(distractor.text, startsWith('amātus + '));
      expect(distractor.text, isNot('amātus + essem'));
    });

    test('dīc: Merken, no options, the regular form kept', () {
      final item = verb('dīcere');
      const key = 'imp.praes.akt.2.sg';
      final steps = eselSteps(item, key);
      expect(
        (item.derivation.forms[key]! as IrregularForm).regular!.result,
        'dīce',
      );
      expect(steps.map((s) => s.kind), [..._esel, EselKind.merken]);
      expect(steps.last.options, isEmpty);
      expect(steps.last.answerKey, 'esel.answer.merken');
      expect(steps.last.answerParams, {
        'form': item.derivation.forms[key]!.result,
      });
      expect(
        steps.last.regular,
        (item.derivation.forms[key]! as IrregularForm).regular!.result,
      );
      expect(steps.sublist(1, 4).every((s) => s.absent), isTrue);
    });

    test('possem: the data quizzes the present stem, not a Merken card', () {
      final item = verb('posse');
      const key = 'konj.impf.akt.1.sg';
      final form = item.derivation.forms[key]! as GeneratedForm;
      expect(form.result, 'possem');
      expect(form.stemName, 'praesens');
      expect(form.ending, 'sem');

      final steps = eselSteps(item, key);
      expect(steps.map((s) => s.kind), _esel);
      expect(_answers(steps), ['Unregelmäßig', 'pos-', '-sem', 'esel.noRule']);
      expect(steps.every((s) => !s.absent), isTrue);
    });

    test('īssem: the Merken answer carries the form and its reason', () {
      final steps = eselSteps(verb('īre'), 'konj.plusq.akt.1.sg');
      expect(steps.last.kind, EselKind.merken);
      expect(steps.last.answerKey, 'esel.answer.merken');
      expect(steps.last.answerParams, {'form': 'īssem'});
      expect(steps.last.regular, 'iissem');
    });

    test('an irregular form without a regular one keeps regular null', () {
      final item = noun('is');
      expect(item.derivation.forms['nom.sg.m'], isA<IrregularForm>());
      final steps = eselSteps(item, 'nom.sg.m');
      expect(steps.last.kind, EselKind.merken);
      expect(steps.last.answerParams, {'form': 'is'});
      expect(steps.last.regular, isNull);
    });

    test('fortiōris: the borrowed ending names its type in the answer', () {
      final item = noun('fortis');
      final steps = eselSteps(item, 'gen.sg.m.komp');
      expect(item.derivation.forms['gen.sg.m.komp']!.result, 'fortiōris');
      expect(steps[1].answer, 'forti-');
      expect(steps[2].answer, '-ōris (Komparativendung)');
      expect(steps[2].options.firstWhere((o) => o.isRight).text, '-ōris');
    });

    test('a dictionary form is shown as the form to memorise', () async {
      final steps = eselSteps(await givenItem(), 'ind.perf.akt.1.sg');
      expect(steps.map((s) => s.kind), [..._esel, EselKind.merken]);
      expect(steps.last.questionKey, 'esel.question.given');
      expect(steps.last.answer, 'abiī');
      expect(steps.last.options, isEmpty);
    });

    test('a form the dictionary writes is not a quiz', () {
      for (final lemma in ['rēx', 'mare', 'animal']) {
        final item = noun(lemma);
        final steps = eselSteps(item, 'nom.sg');
        expect(steps.map((s) => s.kind), [
          ..._esel,
          EselKind.merken,
        ], reason: lemma);
        expect(
          steps.sublist(1, 4).every((s) => s.absent),
          isTrue,
          reason: lemma,
        );
        expect(steps.last.answerKey, 'esel.dictionaryForm', reason: lemma);
        expect(steps.last.options, isEmpty, reason: lemma);
        expect(steps.first.absent, isFalse, reason: lemma);
      }
    });

    test('a zero ending elsewhere keeps its question', () {
      final cases = [
        (noun('corpus'), 'akk.sg'),
        (noun('rēx'), 'vok.sg'),
        (verb('capere'), 'imp.praes.akt.2.sg'),
      ];
      for (final (item, formKey) in cases) {
        final where = '${item.id} $formKey';
        expect(
          (item.derivation.forms[formKey]! as GeneratedForm).ending,
          '',
          reason: where,
        );
        final step = eselSteps(item, formKey)[2];
        expect(step.absent, isFalse, reason: where);
        expect(step.answerKey, 'esel.noEnding', reason: where);
        expect(
          step.options.firstWhere((o) => o.isRight).textKey,
          'esel.noEnding',
          reason: where,
        );
        expect(step.options.length, inInclusiveRange(2, 3), reason: where);
      }
    });
  });

  group('T-esel-2 distractors from the diagnosis', () {
    test('WrongStem puts the stem the learner used among the options', () {
      final item = noun('dominus');
      final diagnosis = diagnose(item, 'gen.pl', 'dominusōrum');
      expect(diagnosis, isA<WrongStem>());
      final steps = eselSteps(item, 'gen.pl', diagnosis: diagnosis);
      expect(steps[1].options.map((o) => o.text), contains('dominus-'));
    });

    test('the uncut dictionary form is an option only as the used stem', () {
      final item = noun('canis');
      final used = diagnose(item, 'dat.sg', 'canisī');
      expect(used, isA<WrongStem>());
      expect((used as WrongStem).usedStem, 'canis');
      expect(
        eselSteps(
          item,
          'dat.sg',
          diagnosis: used,
        )[1].options.map((o) => o.text),
        contains('canis-'),
      );
      final others = <Diagnosis?>[
        null,
        diagnose(item, 'dat.sg', 'canibus'),
        diagnose(item, 'dat.sg', 'canae'),
      ];
      expect(others[1], isA<OtherFormOfWord>());
      expect(others[2], isA<EndingOfOtherType>());
      for (final diagnosis in others) {
        expect(
          eselSteps(
            item,
            'dat.sg',
            diagnosis: diagnosis,
          )[1].options.map((o) => o.text),
          isNot(contains('canis-')),
          reason: 'diagnosis ${diagnosis.runtimeType}',
        );
      }
    });

    test('OtherFormOfWord puts that form\'s ending among the options', () {
      final item = noun('dominus');
      final diagnosis = diagnose(item, 'gen.pl', 'dominīs');
      expect(diagnosis, isA<OtherFormOfWord>());
      final steps = eselSteps(item, 'gen.pl', diagnosis: diagnosis);
      expect(steps[2].options.map((o) => o.text), contains('-īs'));
    });

    test('EndingOfOtherType puts that type\'s ending among the options', () {
      final item = noun('dominus');
      final diagnosis = diagnose(item, 'gen.pl', 'dominārum');
      expect(diagnosis, isA<EndingOfOtherType>());
      final steps = eselSteps(item, 'gen.pl', diagnosis: diagnosis);
      expect(steps[2].options.map((o) => o.text), contains('-ārum'));
    });

    test('without a diagnosis the steps are still complete', () {
      final steps = eselSteps(noun('dominus'), 'gen.pl');
      expect(steps.map((s) => s.kind), _esel);
      expect(steps[1].options, hasLength(3));
    });
  });

  group('T-esel-3 determinism', () {
    test('two calls give the same option order', () {
      final item = noun('dominus');
      expect(
        _texts(eselSteps(item, 'gen.pl')),
        _texts(eselSteps(item, 'gen.pl')),
      );
    });

    test('another form key may order the same question differently', () {
      final item = noun('dominus');
      final here = eselSteps(item, 'gen.pl')[0].options.map((o) => o.text);
      final there = eselSteps(item, 'dat.pl')[0].options.map((o) => o.text);
      expect(here.toSet(), there.toSet());
      expect(here, isNot(there));
    });
  });

  group('T-esel-4 laws over all data', () {
    test('every form of every item yields lawful steps', () async {
      final all = await _grammarItems();
      for (final item in all) {
        for (final formKey in item.formOrder) {
          final steps = eselSteps(item, formKey);
          final where = '${item.id} $formKey';
          expect(steps.take(4).map((s) => s.kind), _esel, reason: where);
          expect(steps.length, inInclusiveRange(4, 5), reason: where);

          for (final step in steps) {
            if (step.answerKey == null) {
              expect(step.answer.trim(), isNotEmpty, reason: where);
              expect(step.answer.trim(), isNot('-'), reason: where);
            }
            if (step.options.isEmpty) continue;
            expect(step.options.length, inInclusiveRange(2, 3), reason: where);
            expect(
              step.options.where((o) => o.isRight),
              hasLength(1),
              reason: where,
            );
            final right = step.options.firstWhere((o) => o.isRight);
            final rest = step.options.where((o) => !o.isRight);
            for (final option in rest) {
              expect(option.identity, isNot(right.identity), reason: where);
              expect(
                norm(option.identity),
                isNot(norm(right.identity)),
                reason: where,
              );
            }
            expect(
              step.options.map((o) => norm(o.identity)).toSet(),
              hasLength(step.options.length),
              reason: where,
            );
            for (final option in step.options) {
              if (option.textKey != null) continue;
              expect(option.text.trim(), isNotEmpty, reason: where);
              expect(option.text.trim(), isNot('-'), reason: where);
            }
            if (step.kind == EselKind.erkennen) {
              for (final option in step.options) {
                expect(
                  item.derivation.grammar.classByType,
                  contains(option.text),
                  reason: where,
                );
              }
            }
            if (step.kind == EselKind.endung) {
              final index = item.formOrder.indexOf(formKey);
              final generated =
                  item.derivation.forms[formKey]! as GeneratedForm;
              final stem = item.derivation.stems[generated.stemName]!;
              for (final option in rest) {
                for (final spelling in stem.variants) {
                  expect(
                    item.accepts(index, spelling + option.text.substring(1)),
                    isFalse,
                    reason: '$where: ${option.text} is also correct',
                  );
                }
              }
            }
          }
        }
      }
    });

    test('every generated form has a Lautregel question', () async {
      for (final item in await _grammarItems()) {
        for (final formKey in item.formOrder) {
          if (item.derivation.forms[formKey] is! GeneratedForm) continue;
          final steps = eselSteps(item, formKey);
          // A form the dictionary writes is shown, not derived.
          if (steps.last.kind == EselKind.merken) continue;
          final step = steps[3];
          expect(step.absent, isFalse, reason: '${item.id} $formKey');
          expect(step.options, hasLength(2), reason: '${item.id} $formKey');
          expect(
            step.options.any((o) => o.textKey == 'esel.noRule'),
            isTrue,
            reason: '${item.id} $formKey',
          );
        }
      }
    });

    test('no stamm option is the uncut dictionary form', () async {
      final offenders = <String>[];
      for (final item in await _grammarItems()) {
        final dictionary = {
          for (final part in item.principalParts) norm(part.$2),
          norm(item.lemma),
        };
        for (final formKey in item.formOrder) {
          final form = item.derivation.forms[formKey]!;
          final words = {
            ...dictionary,
            if (form is GeneratedForm)
              if (item.derivation.stems[form.stemName] case StemFromPart source)
                norm(source.sourceWord),
          };
          final step = eselSteps(item, formKey)[1];
          for (final option in step.options.where((o) => !o.isRight)) {
            final bare = option.text.replaceFirst(RegExp(r'-$'), '');
            if (words.contains(norm(bare))) {
              offenders.add(
                '${item.id} $formKey: ${option.text} '
                '(right ${step.answer})',
              );
            }
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.take(10).join('\n'));
    });

    test(
      'the zero-ending forms split 174 dictionary forms / 2293 questions',
      () async {
        var zeroEnding = 0;
        final dictionaryForms = <String>[];
        final withQuestion = <String>[];
        for (final item in await _grammarItems()) {
          for (final formKey in item.formOrder) {
            final form = item.derivation.forms[formKey];
            if (form is! GeneratedForm || form.ending.isNotEmpty) continue;
            zeroEnding++;
            final steps = eselSteps(item, formKey);
            if (steps.last.answerKey == 'esel.dictionaryForm') {
              dictionaryForms.add('${item.id} $formKey');
            } else {
              withQuestion.add('${item.id} $formKey');
            }
          }
        }
        expect(zeroEnding, 2467);
        expect(dictionaryForms, hasLength(174));
        expect(withQuestion, hasLength(2293));
        expect(
          dictionaryForms.map((e) => e.split(' ').first).toSet().toList()
            ..sort(),
          _dictionaryFormItems,
        );
      },
    );

    test('the classified types are exactly the types the items have', () async {
      final all = await loadAllPracticeItems();
      final used = {for (final item in all) item.type};
      expect(all.first.derivation.grammar.classByType.keys.toSet(), used);
    });
  });

  group('T-esel-5 i18n', () {
    test(
      'every esel key the builder emits exists in de.json and en.json',
      () async {
        final de = await germanTexts();
        final en = await englishTexts();
        final emitted = <String>{};
        for (final item in await _grammarItems()) {
          for (final formKey in item.formOrder) {
            for (final step in eselSteps(item, formKey)) {
              emitted.add(step.questionKey);
              if (step.answerKey != null) emitted.add(step.answerKey!);
              emitted.addAll(step.options.map((o) => o.textKey).nonNulls);
            }
          }
        }
        expect(emitted, isNotEmpty);
        for (final key in emitted) {
          expect(de, contains(key));
          expect(en, contains(key));
        }
        for (final kind in EselKind.values) {
          expect(de, contains('esel.kind.${kind.name}.letter'));
          expect(de, contains('esel.kind.${kind.name}.name'));
          expect(en, contains('esel.kind.${kind.name}.name'));
        }
        expect(de, contains('esel.show'));
        expect(de, contains('esel.legend.title'));
        expect(en, contains('esel.show'));
        expect(en, contains('esel.legend.title'));
      },
    );

    test('the texts of the steps leave no parameter open', () async {
      final steps = [
        ...eselSteps(noun('dominus'), 'gen.pl'),
        ...eselSteps(verb('amāre'), 'konj.plusq.pass.1.sg'),
        ...eselSteps(verb('dīcere'), 'imp.praes.akt.2.sg'),
      ];
      String filled(String text, Map<String, String> params) =>
          text.replaceAllMapped(
            RegExp(r'\{(\w+)\}'),
            (match) => params[match.group(1)]!,
          );
      for (final texts in [await germanTexts(), await englishTexts()]) {
        for (final step in steps) {
          expect(
            filled(texts[step.questionKey]!, step.questionParams),
            isNot(contains('{')),
          );
          if (step.answerKey == null) continue;
          expect(
            filled(texts[step.answerKey]!, step.answerParams),
            isNot(contains('{')),
          );
        }
      }
    });
  });
}

/// The answer of every step, a keyed one as its key and params: a pin must not
/// read as an empty string just because the answer is a phrase.
List<String> _answers(List<EselStep> steps) => [
  for (final step in steps)
    step.answerKey == null
        ? step.answer
        : [step.answerKey!, ...step.answerParams.values].join(' '),
];

List<String> _texts(List<EselStep> steps) => [
  for (final step in steps)
    for (final o in step.options) o.identity,
];

/// The items with a form the dictionary itself writes. The rule reads the
/// first key of `formOrder` that spells the principal part, so a reorder of the
/// data would move it: this list makes such a move visible.
const _dictionaryFormItems = [
  'nouns:acer',
  'nouns:aedis',
  'nouns:aetas',
  'nouns:amor',
  'nouns:animal',
  'nouns:arbor',
  'nouns:ars',
  'nouns:asper',
  'nouns:ater',
  'nouns:auctor',
  'nouns:auctoritas',
  'nouns:auris',
  'nouns:caedes',
  'nouns:caesar',
  'nouns:calamitas',
  'nouns:canis',
  'nouns:caput',
  'nouns:carmen',
  'nouns:celer',
  'nouns:cicero',
  'nouns:cinis',
  'nouns:civis',
  'nouns:clades',
  'nouns:clamor',
  'nouns:classis',
  'nouns:clemens',
  'nouns:comes',
  'nouns:coniunx',
  'nouns:consul',
  'nouns:cor',
  'nouns:corpus',
  'nouns:crudelis',
  'nouns:crudelitas',
  'nouns:cupiditas',
  'nouns:custos',
  'nouns:dens',
  'nouns:dignitas',
  'nouns:discrimen',
  'nouns:dives',
  'nouns:dolor',
  'nouns:dux',
  'nouns:facinus',
  'nouns:felix',
  'nouns:finis',
  'nouns:flos',
  'nouns:foedus',
  'nouns:fortis',
  'nouns:frater',
  'nouns:fur',
  'nouns:gens',
  'nouns:gravis',
  'nouns:homo',
  'nouns:honos',
  'nouns:hospes',
  'nouns:hostis',
  'nouns:imago',
  'nouns:immortalis',
  'nouns:imperator',
  'nouns:incredibilis',
  'nouns:infelix',
  'nouns:ingens',
  'nouns:iter',
  'nouns:iuvenis',
  'nouns:labor',
  'nouns:laus',
  'nouns:legio',
  'nouns:lex',
  'nouns:liber',
  'nouns:libertas',
  'nouns:litus',
  'nouns:lux',
  'nouns:maiestas',
  'nouns:mare',
  'nouns:mater',
  'nouns:mercator',
  'nouns:miles',
  'nouns:miser',
  'nouns:mollis',
  'nouns:mons',
  'nouns:mors',
  'nouns:mos',
  'nouns:mulier',
  'nouns:munus',
  'nouns:navis',
  'nouns:nobilis',
  'nouns:nomen',
  'nouns:noster',
  'nouns:nox',
  'nouns:nubes',
  'nouns:numen',
  'nouns:occasio',
  'nouns:omnis',
  'nouns:oratio',
  'nouns:orbis',
  'nouns:os',
  'nouns:pars',
  'nouns:pater',
  'nouns:pauper',
  'nouns:pax',
  'nouns:pecus',
  'nouns:pes',
  'nouns:pietas',
  'nouns:plebs',
  'nouns:pons',
  'nouns:potestas',
  'nouns:princeps',
  'nouns:prudens',
  'nouns:pulcher',
  'nouns:pulchritudo',
  'nouns:pulvis',
  'nouns:regio',
  'nouns:rex',
  'nouns:salus',
  'nouns:sanguis',
  'nouns:scelus',
  'nouns:senator',
  'nouns:senex',
  'nouns:sermo',
  'nouns:servitus',
  'nouns:sol',
  'nouns:soror',
  'nouns:talis',
  'nouns:tempestas',
  'nouns:tempus',
  'nouns:terror',
  'nouns:timor',
  'nouns:tristis',
  'nouns:turpis',
  'nouns:urbs',
  'nouns:uxor',
  'nouns:vester',
  'nouns:vestis',
  'nouns:vetus',
  'nouns:virgo',
  'nouns:virtus',
  'nouns:voluptas',
  'nouns:vox',
  'nouns:vulnus',
  'verbs:abesse',
  'verbs:abire',
  'verbs:adire',
  'verbs:afferre',
  'verbs:auferre',
  'verbs:conferre',
  'verbs:efferre',
  'verbs:exire',
  'verbs:ferre',
  'verbs:inferre',
  'verbs:inire',
  'verbs:ire',
  'verbs:nolle',
  'verbs:offerre',
  'verbs:perferre',
  'verbs:perire',
  'verbs:praeesse',
  'verbs:redire',
  'verbs:referre',
  'verbs:subire',
  'verbs:velle',
];
