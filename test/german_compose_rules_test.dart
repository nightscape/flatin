// S21–S24 on the German verb data, with test verbs for the cases the course
// verbs do not cover.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/form_label.dart';
import 'package:yaml/yaml.dart';

const _path = 'lib/data/german_verbs.yaml';

const _testItems = '''
  - type: stark
    translation: {de: ankommen, en: arrive}
    parts: {infinitiv: ankommen, grundverb: kommen, partikel: an, praeteritum: kam, partizip2: angekommen}
    slots: {hilfsverb: hv_sein}
    absent: *ohne_passiv
  - id: sich waschen
    type: stark
    translation: {de: sich waschen, en: wash oneself}
    parts: {infinitiv: waschen, praesens_3sg: wäscht, praeteritum: wusch, partizip2: gewaschen}
    slots: {reflexiv: refl}
    absent: *ohne_passiv
  - id: abschied nehmen
    type: stark
    translation: {de: Abschied nehmen, en: take leave}
    parts: {infinitiv: Abschied nehmen, grundverb: nehmen, wortgruppe: Abschied, praesens_3sg: nimmt, praeteritum: nahm, partizip2: Abschied genommen}
    absent: *ohne_passiv
  - type: unregelmäßig
    translation: {de: haben, en: have}
    parts: {infinitiv: haben, praesens_2sg: hast, praesens_3sg: hat, praeteritum: hatte, konjunktiv2: hätte, partizip2: gehabt}
  - type: unregelmäßig
    translation: {de: werden, en: become}
    parts: {infinitiv: werden, praesens_2sg: wirst, praesens_3sg: wird, praeteritum: wurde, konjunktiv2: würde, partizip2: geworden}
    slots: {hilfsverb: hv_sein}
    absent: *ohne_passiv
  - id: not tun
    type: stark
    translation: {de: Not tun, en: be needed}
    parts: {infinitiv: Not tun, grundverb: tun, wortgruppe: Not, praesens_1sg: tue, praesens_3sg: tut, praesens_1pl: tun, praeteritum: tat, partizip2: Not getan}
    absent: *ohne_passiv
  - type: stark
    translation: {de: mittragen, en: share}
    parts: {infinitiv: mittragen, grundverb: tragen, partikel: mit, praesens_3sg: trägt, praeteritum: trug, konjunktiv2: trüge, partizip2: mitgetragen}
  - type: schwach
    translation: {de: mitteilen, en: inform}
    parts: {infinitiv: mitteilen, grundverb: teilen, partikel: mit, partizip2: mitgeteilt}
  - type: schwach
    translation: {de: mitstimmen, en: vote along}
    parts: {infinitiv: mitstimmen, grundverb: stimmen, partikel: mit, partizip2: mitgestimmt}
    absent: *ohne_passiv
''';

final _course = File(_path).readAsStringSync();

/// `items:` is the last key of the file, so appended items belong to it.
String _withTestItems(String yaml) => '$yaml$_testItems';

GrammarEngine _engine(String yaml) =>
    GrammarEngine(parseGrammarFiles({_path: yaml}));

List<String>? _accepted(GrammarEngine engine, String id, FormKey key) =>
    engine.of('german_verbs', id).forms[key]?.variants;

String _replaceOnce(String text, String from, String to) {
  expect(from.allMatches(text), hasLength(1), reason: from);
  return text.replaceFirst(from, to);
}

Matcher _schemaError(String rule) =>
    throwsA(isA<SchemaError>().having((e) => e.rule, 'rule', rule));

String accepted2(GrammarEngine e, String id) =>
    _accepted(e, id, 'konj.praes.akt.3.sg')!.single;

void main() {
  final engine = _engine(_withTestItems(_course));
  List<String>? accepted(String id, FormKey key) => _accepted(engine, id, key);

  group('S21 separators', () {
    test('a one-word particle joins the verb in verb-final order', () {
      expect(accepted('ankommen', 'konj.praes.akt.3.pl'), [
        'sie (Pl.) ankommen',
      ]);
      expect(accepted('zusammenrufen', 'konj.praes.akt.1.sg'), [
        'ich zusammenrufe',
      ]);
    });

    test(
      'a word group and a particle glue to the verb in verb-final order',
      () {
        expect(accepted('wiederherstellen', 'konj.praes.akt.3.sg'), [
          'er/sie/es wiederherstellt',
        ]);
        expect(accepted('wiederherstellen', 'konj.perf.akt.3.sg'), [
          'er/sie/es wiederhergestellt hat',
        ]);
        expect(accepted('wiederherstellen', 'konj.plusq.akt.3.sg'), [
          'er/sie/es wiederhergestellt hätte',
        ]);
        expect(accepted('wiederherstellen', 'ind.praes.akt.3.sg'), [
          'er/sie/es stellt wieder her',
        ]);
      },
    );

    test('no form separates a word group from the particle that follows', () {
      const synthetic = '''
  - id: wiederherbringen
    type: stark
    translation: {de: wiederherbringen, en: bring back}
    parts: {infinitiv: wiederherbringen, grundverb: bringen, wortgruppe: wieder, partikel: her, praesens_3sg: bringt, praeteritum: brachte, konjunktiv2: brächte, partizip2: wiederhergebracht}
    absent: *ohne_passiv
''';
      final course = _withTestItems(_course) + synthetic;
      final all = _engine(course);
      final items = (loadYaml(course) as YamlMap)['items'] as YamlList;
      var checked = 0;
      for (final item in items) {
        final parts = item['parts'] as YamlMap;
        if (parts['partikel'] == null || parts['wortgruppe'] == null) continue;
        final id = item['id'] ?? (item['translation'] as YamlMap)['de'];
        final apart = RegExp(
          '${parts['wortgruppe']} ${parts['partikel']}\\p{L}',
          unicode: true,
        );
        for (final form in all.of('german_verbs', '$id').forms.entries) {
          for (final text in form.value.variants) {
            checked++;
            expect(apart.hasMatch(text), isFalse, reason: '$id ${form.key}');
          }
        }
      }
      expect(checked, greaterThan(100));
      expect(
        all
            .of('german_verbs', 'wiederherbringen')
            .forms['konj.impf.akt.3.sg']!
            .variants,
        contains('er/sie/es wiederherbrächte'),
      );
    });

    test('a particle stays a word of its own elsewhere', () {
      expect(accepted('ankommen', 'ind.praes.akt.3.sg'), [
        'er/sie/es kommt an',
      ]);
      expect(accepted('abschied nehmen', 'konj.praes.akt.3.pl'), [
        'sie (Pl.) Abschied nehmen',
      ]);
      expect(accepted('abschied nehmen', 'ind.impf.akt.1.sg'), [
        'ich nahm Abschied',
      ]);
    });

    test('a spaced word group ending in t keeps its spelling before a t', () {
      expect(accepted('not tun', 'konj.praes.akt.3.sg'), ['er/sie/es Not tut']);
    });

    test('the trace keeps one separator per seam', () {
      final form =
          engine.of('german_verbs', 'ankommen').forms['konj.praes.akt.1.sg']
              as ComposedForm;
      expect(form.joins, [' ', '']);
      expect(form.joinedText, form.result);
    });

    test('a join on the last part throws', () {
      final yaml = _replaceOnce(
        _course,
        '          - {self: roh, set: {modus: ind}, pass: [tempus, person, numerus]}\n',
        '          - {self: roh, set: {modus: ind}, pass: [tempus, person, numerus], join: " "}\n',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S21'));
    });
  });

  group('S18 seams', () {
    const persons = ['ich', 'du', 'er/sie/es', 'wir', 'ihr', 'sie (Pl.)'];
    const keys = ['1.sg', '2.sg', '3.sg', '1.pl', '2.pl', '3.pl'];

    test('a glued particle keeps its spelling before t and st', () {
      for (final (id, verb) in [
        ('mitteilen', 'mitteil'),
        ('mitstimmen', 'mitstimm'),
      ]) {
        final endings = ['e', 'st', 't', 'en', 't', 'en'];
        for (var i = 0; i < keys.length; i++) {
          expect(accepted(id, 'konj.praes.akt.${keys[i]}'), [
            '${persons[i]} $verb${endings[i]}',
          ], reason: '$id ${keys[i]}');
        }
      }
      expect(accepted('mitteilen', 'ind.praes.akt.3.sg'), [
        'er/sie/es teilt mit',
      ]);
    });

    test('"sandhi" on a part that is not a stem part throws', () {
      final yaml = _replaceOnce(
        _course,
        '          - {self: roh, set: {modus: part, tempus: praes}}\n',
        '          - {self: roh, set: {modus: part, tempus: praes}, sandhi: false}\n',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S13'));
    });

    test(
      'a glued particle keeps its spelling in a synthetic konjunktiv II',
      () {
        expect(
          accepted('mittragen', 'konj.impf.akt.1.sg'),
          contains('ich mittrüge'),
        );
      },
    );

    test('every glued stem part of the German verbs skips sandhi', () {
      final file = parseGrammarFiles({_path: _course}).single;
      final glued = [
        for (final type in file.types.values)
          for (final compose in type.composes)
            for (final part in compose.parts.whereType<StemPart>())
              if (part.join == '' || part.glueBefore != null) part,
      ];
      expect(glued, isNotEmpty);
      expect(glued.where((part) => part.sandhi), isEmpty);
    });

    test('a "glue_before" that names no later stem of the rule throws', () {
      for (final target in ['partikl', 'wortgruppe']) {
        final yaml = _replaceOnce(
          _course,
          '          - {stem: wortgruppe, optional: true, glue_before: partikel}\n'
              '          - {stem: partikel, optional: true, join: "", sandhi: false}\n'
              '          - {self: roh, set: {modus: ind}',
          '          - {stem: wortgruppe, optional: true, glue_before: $target}\n'
              '          - {stem: partikel, optional: true, join: "", sandhi: false}\n'
              '          - {self: roh, set: {modus: ind}',
        );
        expect(
          () => parseGrammarFiles({_path: yaml}),
          _schemaError('S21'),
          reason: target,
        );
      }
    });

    test('a "glue_before" on the last part throws', () {
      final yaml = _replaceOnce(
        _course,
        '          - {stem: partikel, optional: true}\n'
            '      - match: {modus: ind, tempus: fut, genus_verbi: akt}',
        '          - {stem: partikel, optional: true, glue_before: wortgruppe}\n'
            '      - match: {modus: ind, tempus: fut, genus_verbi: akt}',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S21'));
    });

    test('a non-string "glue_before" throws', () {
      final yaml = _replaceOnce(
        _course,
        'glue_before: partikel}\n          - {stem: partikel, optional: true, join: "", sandhi: false}\n          - {self: roh, set: {modus: ind}',
        'glue_before: 5}\n          - {stem: partikel, optional: true, join: "", sandhi: false}\n          - {self: roh, set: {modus: ind}',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S21'));
    });

    test('a word group glued to a particle takes no sandhi at the seam', () {
      const items = '''
  - id: geradeentgegenstellen
    type: schwach
    translation: {de: geradeentgegenstellen, en: x}
    parts: {infinitiv: geradeentgegenstellen, grundverb: stellen, wortgruppe: gerade, partikel: entgegen, partizip2: geradeentgegengestellt}
  - id: sattteilnehmen
    type: stark
    translation: {de: sattteilnehmen, en: y}
    parts: {infinitiv: sattteilnehmen, grundverb: nehmen, wortgruppe: satt, partikel: teil, praesens_3sg: nimmt, praeteritum: nahm, partizip2: sattteilgenommen}
    absent: *ohne_passiv
''';
      final e = _engine(_withTestItems(_course) + items);
      expect(
        accepted2(e, 'geradeentgegenstellen'),
        'er/sie/es geradeentgegenstellt',
      );
      expect(
        accepted2(e, 'sattteilnehmen'),
        'er/sie/es satt'
        'teilnimmt',
      );
    });

    test('a non-boolean "sandhi" throws', () {
      final yaml = _replaceOnce(
        _course,
        '          - {stem: partikel, optional: true, join: "", sandhi: false}\n'
            '          - {self: roh, set: {modus: ind}',
        '          - {stem: partikel, optional: true, join: "", sandhi: "no"}\n'
            '          - {self: roh, set: {modus: ind}',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S13'));
    });

    test('the seam between verb stem and ending keeps its sandhi', () {
      expect(accepted('arbeiten', 'ind.praes.akt.3.sg'), [
        'er/sie/es arbeitet',
      ]);
    });
  });

  group('S22 optional parts', () {
    test('an optional part without a form drops out with its separator', () {
      expect(accepted('rufen', 'ind.praes.akt.3.pl'), ['sie (Pl.) rufen']);
      expect(accepted('rufen', 'inf.praes.akt'), ['rufen']);
      expect(accepted('sich waschen', 'ind.praes.akt.3.sg'), [
        'er/sie/es wäscht sich',
      ]);
      expect(accepted('sich waschen', 'inf.perf.akt'), [
        'sich gewaschen haben',
      ]);
    });

    test('a part that is not optional still removes the key', () {
      final yaml = _replaceOnce(
        _course,
        '          - {self: roh, pass: [modus, tempus, person, numerus]}\n'
            '          - {slot: reflexiv, pass: [person, numerus], optional: true}\n',
        '          - {self: roh, pass: [modus, tempus, person, numerus]}\n'
            '          - {slot: reflexiv, pass: [person, numerus]}\n',
      );
      final strict = _engine(yaml);
      expect(_accepted(strict, 'rufen', 'ind.praes.akt.3.pl'), isNull);
      expect(_accepted(strict, 'sich freuen', 'ind.praes.akt.3.pl'), [
        'sie (Pl.) freuen sich',
      ]);
    });

    test('a rule of optional parts only throws', () {
      final yaml = _replaceOnce(
        _course,
        '          - {self: roh, set: {modus: part, tempus: praes}}\n',
        '          - {self: roh, set: {modus: part, tempus: praes}, optional: true}\n',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S22'));
    });
  });

  group('S23 slots', () {
    test('an item fills a slot, else its type does', () {
      expect(
        accepted('kommen', 'ind.perf.akt.1.sg')!.first,
        'ich bin gekommen',
      );
      expect(accepted('ankommen', 'inf.perf.akt'), ['angekommen sein']);
      expect(accepted('rufen', 'ind.perf.akt.1.sg')!.first, 'ich habe gerufen');
      expect(accepted('sich waschen', 'ind.plusq.akt.2.pl'), [
        'ihr hattet euch gewaschen',
      ]);
    });

    test('an item without a reflexive slot has no reflexive pronoun', () {
      expect(accepted('rufen', 'ind.plusq.akt.2.pl'), ['ihr hattet gerufen']);
    });

    test('an item slot its type does not read throws', () {
      final yaml = _replaceOnce(
        _course,
        '    slots: {hilfsverb: hv_sein}\n    absent: *ohne_passiv\n  - type: unregelmäßig',
        '    slots: {hilfsverb: hv_sein, objekt: refl}\n    absent: *ohne_passiv\n  - type: unregelmäßig',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S23'));
    });

    test('a slot naming an unknown item throws', () {
      final yaml = _replaceOnce(
        _course,
        '    slots: {hilfsverb: hv_sein}\n    absent: *ohne_passiv\n  - type: unregelmäßig',
        '    slots: {hilfsverb: hv_bleiben}\n    absent: *ohne_passiv\n  - type: unregelmäßig',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S5'));
    });
  });

  group('S24 variant rules', () {
    test('the perfect also accepts the simple past', () {
      expect(accepted('rufen', 'ind.perf.akt.3.pl'), [
        'sie (Pl.) haben gerufen',
        'sie (Pl.) riefen',
      ]);
      expect(accepted('ankommen', 'ind.perf.akt.1.sg'), [
        'ich bin angekommen',
        'ich kam an',
      ]);
      expect(accepted('sich waschen', 'ind.perf.akt.2.sg'), [
        'du hast dich gewaschen',
        'du wuschst dich',
      ]);
    });

    test('the shown text and its parts come from the main rule', () {
      final form =
          engine.of('german_verbs', 'rufen').forms['ind.perf.akt.3.pl']
              as ComposedForm;
      expect(form.result, 'sie (Pl.) haben gerufen');
      expect(form.joinedText, form.result);
    });

    test('a key without a variant rule keeps one text', () {
      expect(accepted('rufen', 'ind.plusq.akt.3.pl'), [
        'sie (Pl.) hatten gerufen',
      ]);
      expect(accepted('rufen', 'konj.impf.akt.3.pl'), [
        'sie (Pl.) rufen würden',
      ]);
    });

    test('a variant rule for a key no other rule makes throws', () {
      final yaml = _replaceOnce(
        _course,
        '      - match: {modus: ind, tempus: perf, genus_verbi: akt}\n'
            '        variant: true\n',
        '      - match: {modus: konj, tempus: fut, genus_verbi: akt}\n'
            '        variant: true\n',
      );
      expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S24'));
    });
  });

  group('the subjunctive II', () {
    test('sein, haben and werden keep their own form', () {
      expect(accepted('sein', 'konj.impf.akt.3.pl'), ['sie (Pl.) wären']);
      expect(accepted('haben', 'konj.impf.akt.3.pl'), ['sie (Pl.) hätten']);
      expect(accepted('werden', 'konj.impf.akt.3.pl'), ['sie (Pl.) würden']);
    });

    test('other verbs take "würde" and accept a synthetic form', () {
      expect(accepted('wissen', 'konj.impf.akt.3.pl'), [
        'sie (Pl.) wissen würden',
        'sie (Pl.) wüssten',
      ]);
      expect(accepted('sich freuen', 'konj.impf.akt.1.pl'), [
        'wir uns freuen würden',
      ]);
    });
  });

  group('a verb without a personal passive', () {
    test('a verb flagged ohne_passiv has no passive form', () {
      for (final id in ['arbeiten', 'wissen', 'kommen', 'sich freuen']) {
        final keys = engine.of('german_verbs', id).forms.keys;
        expect(keys.where((k) => k.contains('.pass')), isEmpty, reason: id);
      }
    });

    test('an unflagged verb keeps its passive', () {
      expect(accepted('rufen', 'ind.praes.pass.3.pl'), [
        'sie (Pl.) werden gerufen',
      ]);
    });
  });

  test('a compose part with an unknown key throws', () {
    final yaml = _replaceOnce(
      _course,
      '          - {self: roh, set: {modus: part, tempus: praes}}\n',
      '          - {self: roh, set: {modus: part, tempus: praes}, optinal: true}\n',
    );
    expect(() => parseGrammarFiles({_path: yaml}), _schemaError('S13'));
  });
}
