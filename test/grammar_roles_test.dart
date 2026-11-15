import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/exercise.dart';

import 'support/gen_verbs_file.dart';
import 'support/grammar_breaker.dart';
import 'support/hand_items.dart';
import 'support/latin_course.dart' show latinLang;

const _nounsPath = 'lib/data/latin_nouns.yaml';
const _verbsPath = 'lib/data/latin_verbs.yaml';

List<GrammarFile> _parse(Map<String, dynamic> tree) =>
    parseGrammarFiles(lang: latinLang, {'drawn.yaml': grammarSource(tree)});

/// A drawn file with its roles, and the parse of it.
({DrawnVerbsFile drawn, DrawnRoles roles, GrammarFile file, Grammar grammar})
_drawParsed(int seed) {
  final r = Random(seed);
  final base = drawVerbsFile(r);
  final roles = drawRoles(r, base);
  final drawn = base.withRoles(roles);
  final file = _parse(drawn.tree).single;
  return (
    drawn: drawn,
    roles: roles,
    file: file,
    grammar: GrammarEngine([file]).grammar,
  );
}

void main() {
  group('the shipped Latin files give their roles', () {
    final files = parseGrammarFiles(lang: latinLang, {
      _nounsPath: File(_nounsPath).readAsStringSync(),
      _verbsPath: File(_verbsPath).readAsStringSync(),
    });
    final grammar = GrammarEngine(files).grammar;
    final nouns = files.firstWhere((f) => f.dataFileId == 'nouns').roles;
    final verbs = files.firstWhere((f) => f.dataFileId == 'verbs').roles;

    test('the irregular and the borrowing types', () {
      expect(grammar.irregularTypes, {
        'esse-Typ',
        'esse-Kompositum',
        'Unregelmäßig',
      });
      const conjugation = {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'};
      expect(grammar.borrowsByType, {
        for (final type in [
          'A-Konjugation',
          'E-Konjugation',
          'I-Konjugation',
          'Konsonantische',
          'Unregelmäßig',
          'esse-Typ',
        ])
          type: conjugation,
        'Mischkonjugation': {'I-Konjugation', ...conjugation},
        'Adjektiv-a-o': {'Komparativ-Endungen', 'a-o-Endungen'},
        'Adjektiv-a-o-er': {
          'Adjektiv-a-o',
          'Komparativ-Endungen',
          'a-o-Endungen',
          'a-o-er-Endungen',
        },
        'Adjektiv-dreiendig': {
          'Adjektiv-3',
          'Komparativ-Endungen',
          '3-Endungen',
          'a-o-Endungen',
        },
        'Adjektiv-zweiendig': {
          'Adjektiv-3',
          'Komparativ-Endungen',
          '3-Endungen',
          'a-o-Endungen',
        },
        'Konsonantische-Deklination-i-mf': {'Konsonantische-Deklination-mf'},
        'Konsonantische-Deklination-i-n': {'Konsonantische-Deklination-n'},
        'E-Deklination-Konsonantstamm': {'E-Deklination'},
      });
      expect(grammar.agreeingTypes, hasLength(11));
    });

    test('the axes and keys of nouns and verbs', () {
      expect(verbs.bundleAxes, ['modus', 'tempus', 'genus_verbi']);
      expect(nouns.bundleAxes, isEmpty);
      expect(nouns.baseForm, ('kasus', 'nom'));
      expect(verbs.baseForm, ('modus', 'inf'));
      expect(verbs.changeAxes, ['genus_verbi', 'tempus', 'numerus']);
      expect(nouns.changeAxes, ['numerus']);
      expect(verbs.swapAxis, 'numerus');
      expect(nouns.genusAxis, 'genus');
      expect(verbs.principalSupine, 'sup.akk');
      expect(verbs.principalPromptsFrom, [
        'ind.perf.akt.1.sg',
        'sup.akk',
        'part.perf.',
      ]);
      expect(
        [for (final p in verbs.principalRow) p.key],
        ['inf.praes.akt', 'ind.praes.akt.1.sg', 'ind.perf.akt.1.sg', 'sup.akk'],
      );
    });

    test(
      'the gloss key keeps the part of the key the German data files by',
      () {
        expect(verbs.glossKeyOf('ind.praes.akt.1.sg'), 'ind.praes.akt.1.sg');
        expect(verbs.glossKeyOf('inf.praes.akt'), 'inf.praes.akt');
        expect(verbs.glossKeyOf('part.perf.pass.nom.sg.m'), 'part.perf.pass');
        expect(() => verbs.glossKeyOf('sup.akk'), throwsArgumentError);
      },
    );
  });

  group('a drawn file round-trips its roles and drives the consumers', () {
    for (var seed = 0; seed < 40; seed++) {
      test('seed $seed', () {
        final (:drawn, :roles, :file, :grammar) = _drawParsed(seed);
        final parsed = file.roles;

        expect(parsed.bundleAxes, roles.bundleAxes);
        expect(parsed.baseForm, roles.baseForm);
        expect(parsed.changeAxes, roles.changeAxes);
        expect(parsed.swapAxis, roles.swapAxis);
        expect(parsed.lookAlikes, roles.lookAlikes);
        checkLookAlikeSets([parsed]);
        expect(grammar.irregularTypes, roles.irregular);
        expect(grammar.borrowsByType, {
          for (final e in roles.borrows.entries) e.key: e.value.toSet(),
        });

        final key = drawn.keys.map(drawn.keyOf).first;
        final features = drawn.keys.first;
        for (final type in ['T', 'TD', 'T2']) {
          final item = handItem(
            dataFileId: file.dataFileId,
            lemma: 'w$type',
            axes: file.axes,
            forms: {
              key: ['x'],
            },
            type: type,
            role: DataFileRole.verb,
            grammar: grammar,
          );
          expect(
            const IrregularVerbs().includes(item),
            roles.irregular.contains(type),
            reason: type,
          );
          expect(typePhrase(grammar, type), 'endings of $type');
          expect(
            bundleOf(item, key),
            roles.bundleAxes.isEmpty
                ? type
                : drawn.keyOf({
                    for (final axis in roles.bundleAxes) axis: features[axis]!,
                  }),
            reason: type,
          );
        }
      });
    }
  });

  group('a kind whose look-alike set no verb file declares is refused', () {
    for (var seed = 0; seed < 20; seed++) {
      test('seed $seed', () {
        final r = Random(seed);
        final base = drawVerbsFile(r);
        final tree = base.withRoles(drawRoles(r, base)).tree;
        final sets = tree['look_alikes'] as Map<String, dynamic>;
        sets['tock'] = sets.remove('tick');
        expect(
          () => checkLookAlikeSets([_parse(tree).single.roles]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('"tick"'),
            ),
          ),
        );
      });
    }
  });

  group('a role that names nothing the file has is refused, naming it', () {
    void refused(
      String reason,
      void Function(Map<String, dynamic> tree) edit,
      String rule,
      List<String> clauses,
    ) {
      test(reason, () {
        for (var seed = 0; seed < 10; seed++) {
          final r = Random(seed);
          final base = drawVerbsFile(r);
          final tree = base.withRoles(drawRoles(r, base)).tree;
          edit(tree);
          expect(
            () => _parse(tree),
            throwsA(
              isA<SchemaError>()
                  .having((e) => e.rule, 'rule', rule)
                  .having(
                    (e) => e.message,
                    'message',
                    allOf([for (final c in clauses) contains(c)]),
                  ),
            ),
            reason: 'seed $seed',
          );
        }
      });
    }

    Map<String, dynamic> typeOf(Map<String, dynamic> tree, String name) =>
        (tree['types'] as Map<String, dynamic>)[name] as Map<String, dynamic>;

    refused(
      'a borrowed type that no file declares',
      (tree) => typeOf(tree, 'T')['borrows'] = ['NoSuchType'],
      'S39',
      ['types.T.borrows[0]', 'NoSuchType'],
    );
    refused(
      'a type that borrows itself',
      (tree) => typeOf(tree, 'T2')['borrows'] = ['T2'],
      'S39',
      ['types.T2.borrows[0]', '"T2"'],
    );
    refused(
      'an unknown axis in bundle_axes',
      (tree) => tree['bundle_axes'] = ['no_such_axis'],
      'S31',
      ['bundle_axes', 'no_such_axis'],
    );
    refused(
      'an unknown code in base_form',
      (tree) => tree['base_form'] = {'ax0': 'no_such_code'},
      'S32',
      ['base_form', 'ax0: no_such_code'],
    );
    refused(
      'an unknown axis in change_axes',
      (tree) => tree['change_axes'] = ['no_such_axis'],
      'S33',
      ['change_axes', 'no_such_axis'],
    );
    refused(
      'an irregular flag that is no boolean',
      (tree) => typeOf(tree, 'T')['irregular'] = 'yes',
      'S38',
      ['type T irregular'],
    );
  });
}
