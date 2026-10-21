// The schema 3.2 parser: the fixture loads, keys round-trip, labels read as
// they should, and every rule of lib/data/SCHEMA.md rejects its own mistake.
//
// Must-fail proof: swapping `kasus` and `numerus` in the `axes:` list of the
// nouns fixture makes "key round trip" red (the keys then break axis order).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/form_label.dart';

const _nounsPath = 'test/fixtures/grammar_examples.yaml';
const _verbsPath = 'test/fixtures/grammar_examples_verbs.yaml';

Map<String, String> get _fixture => {
  _nounsPath: File(_nounsPath).readAsStringSync(),
  _verbsPath: File(_verbsPath).readAsStringSync(),
};

/// The item lines the `absent:` tests hang their own list under: posse has
/// konj keys from a compose rule and no override, ferre overrides generated
/// konj imperfect keys.
const _posseParts = '    parts: {infinitiv: posse,';
const _ferreParts = '    parts: {infinitiv: ferre,';

/// The fixture with one line replaced in whichever file holds it, for the
/// failing-load tests.
Map<String, String> _fixtureWith(String original, String replacement) =>
    _fixtureWithAll([(original, replacement)]);

/// The fixture with several lines replaced, each in whichever file holds it.
Map<String, String> _fixtureWithAll(List<(String, String)> edits) {
  var sources = _fixture;
  for (final (original, replacement) in edits) {
    final holders = sources.keys.where(
      (p) => sources[p]!.split(original).length == 2,
    );
    expect(
      holders,
      hasLength(1),
      reason: '"$original" must occur once in exactly one fixture file',
    );
    final path = holders.single;
    sources = {
      ...sources,
      path: sources[path]!.replaceFirst(original, replacement),
    };
  }
  return sources;
}

/// Parses [sources] and expects the rule [rule] to reject them with a message
/// holding [clause], the one clause of the rule that must bite.
void _expectRejected(String rule, String clause, Map<String, String> sources) {
  expect(
    () => parseGrammarFiles(sources),
    throwsA(
      isA<SchemaError>()
          .having((e) => e.rule, 'rule', rule)
          .having((e) => e.message, 'message', contains(clause)),
    ),
  );
}

/// Kasus before Numerus, Nominativ before Genitiv, Singular before Plural.
Axes _twoAxes() => Axes(
  axes: [
    GrammarAxis(
      id: 'kasus',
      name: 'Kasus',
      values: const [('nom', 'Nominativ'), ('gen', 'Genitiv')],
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

void main() {
  test('key round trip (axis order)', () {
    final axes = _twoAxes();
    for (final key in ['nom.sg', 'nom.pl', 'gen.sg', 'gen.pl']) {
      expect(axes.formatKey(axes.parseKey(key)), key);
    }
  });

  group('compare (S7)', () {
    final axes = _twoAxes();
    int cmp(String a, String b) =>
        axes.compare(axes.parseKey(a), axes.parseKey(b));

    test('the first axis decides', () {
      expect(cmp('nom.pl', 'gen.sg'), isNegative);
      expect(cmp('gen.sg', 'nom.pl'), isPositive);
    });

    test('then the value order inside the axis', () {
      expect(cmp('nom.sg', 'nom.pl'), isNegative);
      expect(cmp('nom.pl', 'nom.sg'), isPositive);
      expect(cmp('nom.sg', 'nom.sg'), isZero);
    });

    test('an absent axis sorts before any value', () {
      expect(cmp('sg', 'nom.sg'), isNegative);
      expect(cmp('nom.sg', 'sg'), isPositive);
    });
  });

  group('the fixture', () {
    late List<GrammarFile> files;
    late GrammarFile nouns;
    late GrammarFile verbs;

    setUpAll(() {
      files = parseGrammarFiles(_fixture);
      nouns = files.firstWhere((f) => f.dataFileId == 'nouns');
      verbs = files.firstWhere((f) => f.dataFileId == 'verbs');
    });

    test('holds the two worked data files', () {
      expect(files, hasLength(2));
      expect(nouns.items, isNotEmpty);
      expect(verbs.items, isNotEmpty);
    });

    test('key round trip', () {
      for (final file in files) {
        final keys = <FormKey>{
          for (final type in file.types.values) ...type.forms.keys,
          for (final item in file.items) ...item.forms.keys,
          for (final planned in file.keysByItem.values) ...planned.emitted,
          for (final planned in file.keysByItem.values) ...planned.internal,
        };
        expect(keys, isNotEmpty, reason: file.dataFileId);
        for (final key in keys) {
          final features = file.axes.parseKey(key);
          expect(file.axes.formatKey(features), key, reason: key);
        }
      }
    });

    test('every item has a type and keys', () {
      for (final file in files) {
        for (final item in file.items) {
          expect(file.types, contains(item.typeName), reason: item.id);
          expect(
            file.keysByItem[item.id]!.emitted,
            isNotEmpty,
            reason: item.id,
          );
        }
      }
    });

    test('a deponent practises its passive forms as active (S10)', () {
      final keys = verbs.keysByItem['hortari']!;
      expect(keys.emitted, contains('ind.praes.akt.1.sg'));
      expect(keys.deponent, contains('ind.praes.akt.1.sg'));
      expect(
        keys.emitted.where((k) => k.contains('.pass')),
        isEmpty,
        reason: 'a full deponent has no passive key',
      );
      expect(keys.emitted, contains('inf.fut.akt'), reason: 'S10 keeps it');
    });

    test('absent removes the keys the word has not (S15)', () {
      final keys = verbs.keysByItem['posse']!;
      expect(keys.emitted.where((k) => k.startsWith('imp.')), isEmpty);
      expect(keys.emitted, isNot(contains('inf.fut.akt')));
      expect(keys.emitted, contains('ind.praes.akt.1.sg'));
    });

    test('a declared type wins over the inference rules (S11)', () {
      final ire = verbs.items.firstWhere((i) => i.id == 'ire');
      expect(ire.typeRule!.types, ['I-Konjugation']);
      expect(ire.typeName, 'Unregelmäßig');
    });

    test('an inferred type needs no declaration (S11)', () {
      final inferred = verbs.items.where((i) => i.declaredType == null);
      expect(inferred, isNotEmpty);
      for (final item in inferred) {
        expect(item.typeName, item.typeRule!.types.single, reason: item.id);
      }
    });

    test('ä, ö, ü and ß are letters in a sandhi rule (S16)', () {
      final verbs = parseGrammarFiles(
        _fixtureWith(
          '{end: t, before: [s], replace: s,',
          '{end: äöüß, before: [äöüß], replace: äöüß,',
        ),
      ).firstWhere((f) => f.dataFileId == 'verbs');
      expect(verbs.sandhi['t_s']!.end, 'äöüß');
      expect(verbs.sandhi['t_s']!.beforeStarts, ['äöüß']);
      expect(verbs.sandhi['t_s']!.replaceText, 'äöüß');
    });
  });

  group('labels', () {
    late GrammarFile nouns;
    late GrammarFile verbs;

    setUpAll(() {
      final files = parseGrammarFiles(_fixture);
      nouns = files.firstWhere((f) => f.dataFileId == 'nouns');
      verbs = files.firstWhere((f) => f.dataFileId == 'verbs');
    });

    test('an override drops the number of a non-finite Futur (S17)', () {
      expect(
        FormLabel.fromKey('inf.fut.akt', verbs.axes).displayName,
        'Infinitiv Futur',
      );
    });

    test('a finite form keeps it', () {
      expect(
        FormLabel.fromKey('ind.fut.akt.1.sg', verbs.axes).displayName,
        'Futur I: 1. Person Singular',
      );
    });

    test('describeLabels merges the merge axis', () {
      expect(
        describeLabels([
          FormLabel.fromKey('dat.pl', nouns.axes),
          FormLabel.fromKey('abl.pl', nouns.axes),
        ]),
        'Dativ/Ablativ Plural',
      );
    });

    test('describeLabels keeps other axes apart', () {
      expect(
        describeLabels([
          FormLabel.fromKey('ind.praes.akt.3.sg', verbs.axes),
          FormLabel.fromKey('ind.perf.akt.3.sg', verbs.axes),
        ]),
        'Präsens: 3. Person Singular, Perfekt: 3. Person Singular',
      );
      expect(
        describeLabels([
          FormLabel.fromKey('gen.sg.m.komp', nouns.axes),
          FormLabel.fromKey('gen.sg.n.komp', nouns.axes),
        ]),
        'Komparativ maskulin: Genitiv Singular, '
        'Komparativ neutrum: Genitiv Singular',
      );
    });
  });

  group('rejects', () {
    test('S1: a code in two axes', () {
      _expectRejected(
        'S1',
        'is declared by axis kasus and axis adverb',
        _fixtureWith(
          '      adv: {de: Adverb, en: Adverb}',
          '      adv: {de: Adverb, en: Adverb}\n'
              '      nom: {de: Nominativ, en: Nominative}',
        ),
      );
    });

    test('S1: a key that is not canonical', () {
      _expectRejected(
        'S1',
        'breaks axis order',
        _fixtureWith(
          '      nom.sg.m: "{stamm}us"',
          '      sg.nom.m: "{stamm}us"',
        ),
      );
    });

    test('S2: two placeholders in one template', () {
      _expectRejected(
        'S2',
        'has more than one placeholder',
        _fixtureWith(
          '      nom.sg.m: "{stamm}us"',
          '      nom.sg.m: "{stamm}{stamm}us"',
        ),
      );
    });

    test('S2: a template that names no stem of its type', () {
      _expectRejected(
        'S2',
        'names no stem',
        _fixtureWith('      nom.sg.m: "{stamm}us"', '      nom.sg.m: "{}us"'),
      );
    });

    test('S2: a template that names a stem the type has not', () {
      _expectRejected(
        'S2',
        'has no stem "unbekannt"',
        _fixtureWith(
          'akk.sg: ["{stamm}im", "{stamm}em"]',
          'akk.sg: ["{unbekannt}im", "{stamm}em"]',
        ),
      );
    });

    test('S3: no remove suffix matches the part', () {
      _expectRejected(
        'S3',
        'no suffix of [xis] matches',
        _fixtureWith(
          '    required_stems: [stamm]\n    stems:\n'
              '      stamm: {from: gen, remove: "is", display: {de: Stamm, en: Stem}}',
          '    required_stems: [stamm]\n    stems:\n'
              '      stamm: {from: gen, remove: "xis", display: {de: Stamm, en: Stem}}',
        ),
      );
    });

    test('S4: a required stem the item cannot build', () {
      _expectRejected(
        'S4',
        'requires the stem "kstamm", which it does not declare',
        _fixtureWith(
          '    required_stems: [stamm]',
          '    required_stems: [kstamm]',
        ),
      );
    });

    test('S5: an inheritance cycle', () {
      _expectRejected(
        'S5',
        'inheritance cycle',
        _fixtureWith(
          '  a-o-er-Endungen:\n    abstract: true\n'
              '    inherits_from: a-o-Endungen',
          '  a-o-er-Endungen:\n    abstract: true\n'
              '    inherits_from: a-o-er-Endungen',
        ),
      );
    });

    test('S5: an item composed from itself', () {
      _expectRejected(
        'S5',
        'composition cycle',
        _fixtureWith('type: esse-Typ', 'type: esse-Kompositum'),
      );
    });

    test('S6: an item type that no file declares', () {
      _expectRejected(
        'S6',
        'unknown type "i-Deklination-xy"',
        _fixtureWith('- type: i-Deklination-mf', '- type: i-Deklination-xy'),
      );
    });

    test('S9: two spellings that differ only in quantity', () {
      _expectRejected(
        'S9',
        'differs from another spelling only in quantity marks',
        _fixtureWith(
          '      nom.sg.m: "{stamm}us"',
          '      nom.sg.m: ["{stamm}us", "{stamm}ūs"]',
        ),
      );
    });

    test('S10: deponent in a tempus the file has no code for', () {
      _expectRejected(
        'S10',
        '"pqp" is no tempus code',
        _fixtureWith(
          '    deponent: [perf, plusq, fut2]',
          '    deponent: [pqp]',
        ),
      );
    });

    test('S10: deponent in a file without a genus_verbi axis', () {
      _expectRejected(
        'S10',
        'has no genus_verbi axis',
        _fixtureWith(
          '    translation: {de: Turm, en: tower}\n',
          '    translation: {de: Turm, en: tower}\n    deponent: all\n',
        ),
      );
    });

    test('S11: an ambiguous rule without a declared type', () {
      _expectRejected(
        'S11',
        'is ambiguous, so the item must give "type"',
        _fixtureWith(
          '- {suffix: "āre", types: [A-Konjugation]}',
          '- {suffix: "āre", types: [A-Konjugation, Unregelmäßig]}',
        ),
      );
    });

    test('S12: one type name in two data files', () {
      _expectRejected(
        'S12',
        'type "Perfekt-System" is also declared in',
        _fixtureWith(
          '  Pronomen:\n    class: pronomen\n'
              '    display: {de: Pronomen, en: Pronomen}',
          '  Perfekt-System: {abstract: true}',
        ),
      );
    });

    test('S12: a delegated code the delegating file does not declare', () {
      _expectRejected(
        'S12',
        'code "vok" is unknown in verbs',
        _fixtureWith(
          '      vok: {de: Vokativ, en: Vocative}\n  genus:',
          '  genus:',
        ),
      );
    });

    test('S12: a delegated code on a different axis in the two files', () {
      // "sg" then sits on "zahl" in the nouns file and on "numerus" in the
      // verbs file that delegates into it.
      _expectRejected(
        'S12',
        'code "sg" is axis numerus in verbs but zahl in nouns',
        _fixtureWithAll([
          (
            '      vok: {de: Vokativ, en: Vocative}\n  numerus:',
            '      vok: {de: Vokativ, en: Vocative}\n  zahl:',
          ),
          ('  tail: [kasus, numerus]', '  tail: [kasus, zahl]'),
        ]),
      );
    });

    test('S12: an item naming a type of another file', () {
      _expectRejected(
        'S12',
        'type "A-Konjugation" is declared in',
        _fixtureWith(
          '  - type: i-Deklination-n\n    translation: {de: Meer',
          '  - type: A-Konjugation\n    translation: {de: Meer',
        ),
      );
    });

    test('S12: an item naming a composing type of another file', () {
      _expectRejected(
        'S12',
        'type "esse-Kompositum" is declared in',
        _fixtureWith(
          '  - type: i-Deklination-mf\n    translation: {de: Turm',
          '  - type: esse-Kompositum\n    translation: {de: Turm',
        ),
      );
    });

    test('a source that holds two YAML documents', () {
      final sources = _fixture;
      _expectRejected('file', 'a data file is one YAML document', {
        ...sources,
        _nounsPath: '${sources[_nounsPath]}\n---\n${sources[_verbsPath]}',
      });
    });

    test('a top-level key outside the closed set', () {
      expect(
        () => parseGrammarFile(
          _oneItemSource.replaceFirst('items:', 'itemz:'),
          path: 'mini.yaml',
        ),
        throwsA(
          isA<SchemaError>()
              .having((e) => e.rule, 'rule', 'file')
              .having((e) => e.path, 'path', 'mini.yaml')
              .having((e) => e.message, 'message', contains('itemz')),
        ),
      );
    });

    test('shared: is a top-level key the loader accepts', () {
      final file = parseGrammarFile(
        _oneItemSource.replaceFirst(
          'items:',
          'shared:\n  ohne_pl: &ohne_pl [{numerus: pl}]\n\nitems:',
        ),
        path: 'mini.yaml',
      );
      expect(file.items, hasLength(1));
    });

    test('S14: a delegate target that is not a leaf', () {
      _expectRejected(
        'S14',
        'which is not a leaf',
        _fixtureWith(
          '{name: pos,  type: a-o-Endungen,',
          '{name: pos,  type: Adjektiv-a-o,',
        ),
      );
    });

    test('S14: a target stem the delegate does not bind', () {
      _expectRejected(
        'S14',
        'does not bind the stem "unbekannt"',
        _fixtureWith(
          '      nom.sg.m: "{stamm}us"',
          '      nom.sg.m: "{unbekannt}us"',
        ),
      );
    });

    test('S15: an absent pattern removes the keys it names', () {
      final engine = GrammarEngine(
        parseGrammarFiles(
          _fixtureWith(
            _posseParts,
            '    absent: [{modus: konj, tempus: praes}]\n$_posseParts',
          ),
        ),
      );
      final keys = engine.of('verbs', 'posse').forms.keys;
      expect(keys, contains('konj.impf.akt.1.sg'));
      expect(keys, isNot(contains('konj.praes.akt.1.sg')));
    });

    test('S15: an absent pattern that removes nothing', () {
      _expectRejected(
        'S15',
        'removes no key',
        _fixtureWith(_posseParts, '    absent: [{modus: sup}]\n$_posseParts'),
      );
    });

    test('S15: an absent pattern that removes an overridden key', () {
      _expectRejected(
        'S15',
        'removes the overridden key',
        _fixtureWith(
          _ferreParts,
          '    absent: [{modus: konj, tempus: impf}]\n$_ferreParts',
        ),
      );
    });

    const agereParts =
        '    parts: {infinitiv: agere, praesens_1sg: agō, perfekt_1sg: ēgī, '
        'supinum: āctum}';

    test('S25: an impersonal passive is neuter and has no person', () {
      final derivation = GrammarEngine(
        parseGrammarFiles(
          _fixtureWith(agereParts, '$agereParts\n    passiv: unpersönlich'),
        ),
      ).of('verbs', 'agere');
      expect(derivation.forms['ind.perf.pass.3.sg']!.variants, ['āctum est']);
      expect(derivation.forms['ind.praes.pass.3.sg'], isNotNull);
      expect(derivation.forms['ind.praes.pass.3.pl'], isNull);
      expect(derivation.forms['ind.perf.pass.1.sg'], isNull);
      expect(derivation.forms['part.perf.pass.sg.nom.m'], isNull);
      expect(derivation.internal['part.perf.pass.sg.nom.m'], isNotNull);
    });

    test('S25: a passiv value other than unpersönlich', () {
      _expectRejected(
        'S25',
        'is not "unpersönlich"',
        _fixtureWith(agereParts, '$agereParts\n    passiv: persönlich'),
      );
    });

    test('S25: a deponent with an impersonal passive', () {
      _expectRejected(
        'S25',
        'a deponent has no impersonal passive',
        _fixtureWith(
          '    parts: {infinitiv: hortārī, praesens_1sg: hortor}',
          '    parts: {infinitiv: hortārī, praesens_1sg: hortor}\n'
              '    passiv: unpersönlich',
        ),
      );
    });

    test('S16: a before entry that is not letters', () {
      _expectRejected(
        'S16',
        '"before" entry "1" is not letters',
        _fixtureWith('before: [s], replace: s', 'before: [1], replace: s'),
      );
    });

    test('S16: drop_next without a before list', () {
      _expectRejected(
        'S16',
        'rule d_ausfall: drop_next needs a "before" list',
        _fixtureWith(
          'before: consonant, replace: ""',
          'before: consonant, replace: drop_next',
        ),
      );
    });

    test('S16: an end with a digit', () {
      _expectRejected(
        'S16',
        'rule t_s: "end" must be letters',
        _fixtureWith('{end: t, before: [s]', '{end: t1, before: [s]'),
      );
    });

    test('S16: an end with a space', () {
      _expectRejected(
        'S16',
        'rule t_s: "end" must be letters',
        _fixtureWith('{end: t, before: [s]', '{end: "t s", before: [s]'),
      );
    });

    test('S16: a type that names an unknown rule', () {
      _expectRejected(
        'S16',
        'names no sandhi rule "d_unbekannt"',
        _fixtureWith('    sandhi: [d_angleich]', '    sandhi: [d_unbekannt]'),
      );
    });

    test('S20: a text without an English version', () {
      _expectRejected(
        'S20',
        'sandhi rule t_s explain: give a map of the languages [de, en]',
        _fixtureWith(
          'explain: {de: t wird vor s zu s, en: t becomes s before s}',
          'explain: {de: t wird vor s zu s}',
        ),
      );
    });

    test('S20: an empty English gloss', () {
      _expectRejected(
        'S20',
        'item turris translation: the "en" text is missing or empty',
        _fixtureWith('{de: Turm, en: tower}', '{de: Turm, en: " "}'),
      );
    });

    test('S20: a plain string where the languages belong', () {
      _expectRejected(
        'S20',
        'part nom: give a map of the languages [de, en]',
        _fixtureWith(
          '  nom:        {label: {de: Nominativ, en: Nominative}}',
          '  nom:        {label: Nominativ}',
        ),
      );
    });

    test('S20: two types with one display', () {
      _expectRejected(
        'S20',
        'types i-Deklination-mf and i-Deklination-n share the en display',
        _fixtureWith(
          'display: {de: i-Deklination-n, en: i-Deklination-n}',
          'display: {de: i-Deklination-n, en: i-Deklination-mf}',
        ),
      );
    });

    test('S20: an abstract type with a display', () {
      _expectRejected(
        'S20',
        'type a-o-Endungen is abstract, so it takes no "display"',
        _fixtureWith(
          '  a-o-Endungen:\n    abstract: true',
          '  a-o-Endungen:\n    abstract: true\n'
              '    display: {de: Endungen, en: endings}',
        ),
      );
    });

    test('S17: an override on an axis the file has no code for', () {
      _expectRejected(
        'S17',
        'override names the unknown code "futur"',
        _fixtureWith(
          'values: {fut: {de: Futur, en: Future}}',
          'values: {futur: {de: Futur, en: Future}}',
        ),
      );
    });

    test('S17: head and tail that do not cover every axis', () {
      _expectRejected(
        'S17',
        'must list every axis exactly once',
        _fixtureWith('  tail: [kasus, numerus]', '  tail: [kasus]'),
      );
    });

    test('S19: a concrete type without a class', () {
      _expectRejected(
        'S19',
        'type i-Deklination-mf has no "class"',
        _fixtureWith(
          '  i-Deklination-mf:\n    class: deklination',
          '  i-Deklination-mf:',
        ),
      );
    });

    test('S19: a type naming a class the file does not list', () {
      _expectRejected(
        'S19',
        'type i-Deklination-mf names the unknown class "verb"',
        _fixtureWith(
          '    class: deklination\n'
              '    display: {de: i-Deklination-mf, en: i-Deklination-mf}',
          '    class: verb\n'
              '    display: {de: i-Deklination-mf, en: i-Deklination-mf}',
        ),
      );
    });

    test('S19: a class on an abstract type', () {
      _expectRejected(
        'S19',
        'type a-o-Endungen is abstract, so it takes no "class"',
        _fixtureWith(
          '  a-o-Endungen:\n    abstract: true',
          '  a-o-Endungen:\n    abstract: true\n    class: deklination',
        ),
      );
    });

    test('S19: a class listed twice', () {
      _expectRejected(
        'S19',
        'class "deklination" is declared twice',
        _fixtureWith(
          'classes: [deklination, adjektiv, pronomen]',
          'classes: [deklination, adjektiv, pronomen, deklination]',
        ),
      );
    });

    // A new type is caught by the load, not by the first step that uses it.
    test('S19: a type added without a class', () {
      _expectRejected(
        'S19',
        'type Neu-Deklination has no "class"',
        _fixtureWith(
          '  i-Deklination-mf:',
          '  Neu-Deklination: {}\n\n  i-Deklination-mf:',
        ),
      );
    });
  });
}

/// The smallest file that loads, for the top-level key tests.
const _oneItemSource = '''
data_file_id: mini

axes:
  numerus:
    name: {de: Numerus, en: Number}
    values:
      sg: {de: Singular, en: Singular}
      pl: {de: Plural, en: Plural}

label:
  head: [numerus]
  tail: []
  merge_axis: numerus

parts:
  praesens_1sg: {label: {de: "1. Person Singular", en: "1st person singular"}}

defaults:
  given_part: praesens_1sg
  lemma_part: praesens_1sg

classes: [konjugation]

types:
  I-Konjugation:
    class: konjugation
    display: {de: I-Konjugation, en: 4th conjugation}
    required_stems: [wurzel]
    stems:
      wurzel: {from: praesens_1sg, remove: "iō", display: {de: Wortstock, en: Root}}
    forms:
      sg: "{wurzel}iō"
      pl: "{wurzel}īmus"

items:
  - type: I-Konjugation
    translation: {de: fassen, en: seize}
    parts: {praesens_1sg: capiō}
''';
