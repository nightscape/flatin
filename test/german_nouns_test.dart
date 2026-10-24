import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

const _path = 'lib/data/german_nouns.yaml';
final _yaml = File(_path).readAsStringSync();

GrammarEngine _engineOf(String yaml) =>
    GrammarEngine(parseGrammarFiles({_path: yaml}));

const _cases = ['nom', 'gen', 'dat', 'akk', 'abl', 'vok'];
final _keys = [
  for (final n in ['sg', 'pl'])
    for (final c in _cases) '$c.$n',
];

/// Latin lemma → the accepted German texts of each key, the shown one first.
const _pinned = {
  'servus': {
    'nom.sg': ['der Sklave (ist da)'],
    'gen.sg': ['(die Farbe) des Sklaven'],
    'dat.sg': ['(ich helfe) dem Sklaven'],
    'akk.sg': ['(ich sehe) den Sklaven'],
    'abl.sg': [
      'mit dem Sklaven',
      'von dem Sklaven',
      'durch den Sklaven',
      'vom Sklaven',
    ],
    'vok.sg': ['(o) Sklave!'],
    'nom.pl': ['die Sklaven (sind da)'],
    'gen.pl': ['(die Farbe) der Sklaven'],
    'dat.pl': ['(ich helfe) den Sklaven'],
    'akk.pl': ['(ich sehe) die Sklaven'],
    'abl.pl': ['mit den Sklaven', 'von den Sklaven', 'durch die Sklaven'],
    'vok.pl': ['(o) Sklaven!'],
  },
  'Rōmānus': {
    'nom.sg': ['der Römer (ist da)'],
    'gen.sg': ['(die Farbe) des Römers'],
    'dat.sg': ['(ich helfe) dem Römer'],
    'akk.sg': ['(ich sehe) den Römer'],
    'abl.sg': [
      'mit dem Römer',
      'von dem Römer',
      'durch den Römer',
      'vom Römer',
    ],
    'vok.sg': ['(o) Römer!'],
    'nom.pl': ['die Römer (sind da)'],
    'gen.pl': ['(die Farbe) der Römer'],
    'dat.pl': ['(ich helfe) den Römern'],
    'akk.pl': ['(ich sehe) die Römer'],
    'abl.pl': ['mit den Römern', 'von den Römern', 'durch die Römer'],
    'vok.pl': ['(o) Römer!'],
  },
  'rosa': {
    'nom.sg': ['die Rose (ist da)'],
    'gen.sg': ['(die Farbe) der Rose'],
    'dat.sg': ['(ich helfe) der Rose'],
    'akk.sg': ['(ich sehe) die Rose'],
    'abl.sg': ['mit der Rose', 'von der Rose', 'durch die Rose'],
    'vok.sg': ['(o) Rose!'],
    'nom.pl': ['die Rosen (sind da)'],
    'gen.pl': ['(die Farbe) der Rosen'],
    'dat.pl': ['(ich helfe) den Rosen'],
    'akk.pl': ['(ich sehe) die Rosen'],
    'abl.pl': ['mit den Rosen', 'von den Rosen', 'durch die Rosen'],
    'vok.pl': ['(o) Rosen!'],
  },
  'vīlla': {
    'nom.sg': ['das Haus (ist da)'],
    'gen.sg': ['(die Farbe) des Hauses'],
    'dat.sg': ['(ich helfe) dem Haus'],
    'akk.sg': ['(ich sehe) das Haus'],
    'abl.sg': ['mit dem Haus', 'von dem Haus', 'durch das Haus', 'vom Haus'],
    'vok.sg': ['(o) Haus!'],
    'nom.pl': ['die Häuser (sind da)'],
    'gen.pl': ['(die Farbe) der Häuser'],
    'dat.pl': ['(ich helfe) den Häusern'],
    'akk.pl': ['(ich sehe) die Häuser'],
    'abl.pl': ['mit den Häusern', 'von den Häusern', 'durch die Häuser'],
    'vok.pl': ['(o) Häuser!'],
  },
  'cor': {
    'nom.sg': ['das Herz (ist da)'],
    'gen.sg': ['(die Farbe) des Herzens'],
    'dat.sg': ['(ich helfe) dem Herzen'],
    'akk.sg': ['(ich sehe) das Herz'],
    'abl.sg': [
      'mit dem Herzen',
      'von dem Herzen',
      'durch das Herz',
      'vom Herzen',
    ],
    'vok.sg': ['(o) Herz!'],
    'nom.pl': ['die Herzen (sind da)'],
    'gen.pl': ['(die Farbe) der Herzen'],
    'dat.pl': ['(ich helfe) den Herzen'],
    'akk.pl': ['(ich sehe) die Herzen'],
    'abl.pl': ['mit den Herzen', 'von den Herzen', 'durch die Herzen'],
    'vok.pl': ['(o) Herzen!'],
  },
  'Rōma': {
    'nom.sg': ['Rom (ist da)'],
    'gen.sg': ['(die Farbe) Roms'],
    'dat.sg': ['(ich helfe) Rom'],
    'akk.sg': ['(ich sehe) Rom'],
    'abl.sg': ['mit Rom', 'von Rom', 'durch Rom'],
    'vok.sg': ['(o) Rom!'],
  },
};

/// The case frame of each key, the shown one first.
const _frames = {
  'nom.sg': ['(ist da)'],
  'gen.sg': ['(die Farbe)'],
  'dat.sg': ['(ich helfe)'],
  'akk.sg': ['(ich sehe)'],
  'abl.sg': ['mit', 'von'],
  'vok.sg': ['(o)'],
  'nom.pl': ['(sind da)'],
  'gen.pl': ['(die Farbe)'],
  'dat.pl': ['(ich helfe)'],
  'akk.pl': ['(ich sehe)'],
  'abl.pl': ['mit', 'von'],
  'vok.pl': ['(o)'],
};

/// [text] without its bracketed frame before the article.
String _unframed(String text) => text.replaceFirst(RegExp(r'^\(.*?\) '), '');

/// German noun id → the texts of each key, for a noun without a Latin item.
const _pinnedGermanOnly = {
  'eltern': {
    'nom.pl': ['die Eltern (sind da)'],
    'gen.pl': ['(die Farbe) der Eltern'],
    'dat.pl': ['(ich helfe) den Eltern'],
    'akk.pl': ['(ich sehe) die Eltern'],
    'abl.pl': ['mit den Eltern', 'von den Eltern', 'durch die Eltern'],
    'vok.pl': ['(o) Eltern!'],
  },
};

/// The Latin items whose German noun has no plural.
const _noPlural = {
  'Rōma',
  'Capitōlium',
  'Tartarus',
  'arēna',
  'cibus',
  'frūmentum',
  'sapientia',
  'amor',
  'salūs',
  'clāmor',
  'perniciēs',
  'fidēs',
  'laus',
  'iniūria',
  'pulvis',
  'mors',
  'odium',
  'ferrum',
  'Cicerō',
  'scientia',
  'studium',
  'Caesar',
  'cōnspectus',
  'gemitus',
  'silentium',
  'pecūnia',
};

const _spikeLemmas = {
  'servus',
  'nūntius',
  'templum',
  'Rōmānus',
  'dōnum',
  'vīlla',
  'rosa',
  'fīlia',
  'cor',
  'Rōma',
};

/// `<Latin lemma> <kind>` → what Random(207) builds over the whole case
/// bundle: the shown text, then the right answer or the accepted set.
const _seededBuilds = {
  'rosa latDeWahl': 'rosae → (o) Rosen!',
  'rosa deLatWahl': '(o) Rosen! → rosae',
  'rosa deLatTippen': '(o) Rosen! → rosae',
  'Rōmānus latDeWahl': 'Rōmānī → (o) Römer!',
  'Rōmānus deLatWahl': '(o) Römer! → Rōmānī',
  'Rōmānus deLatTippen': '(o) Römer! → Rōmānī | Rōmāne',
  'dōnum latDeWahl': 'dōna → (o) Geschenke!',
  'dōnum deLatWahl': '(o) Geschenke! → dōna',
  'dōnum deLatTippen': '(o) Geschenke! → dōna',
  'fīlia latDeWahl': 'fīliae → (o) Töchter!',
  'fīlia deLatWahl': '(o) Töchter! → fīliae',
  'fīlia deLatTippen': '(o) Töchter! → fīliae',
  'servus latDeWahl': 'servī → (o) Sklaven!',
  'servus deLatWahl': '(o) Sklaven! → servī',
  'servus deLatTippen': '(o) Sklaven! → servī',
  'templum latDeWahl': 'templa → (o) Tempel!',
  'templum deLatWahl': '(o) Tempel! → templa',
  'templum deLatTippen': '(o) Tempel! → templa | templum',
  'vīlla latDeWahl': 'vīllae → (o) Häuser!',
  'vīlla deLatWahl': '(o) Häuser! → vīllae',
  'vīlla deLatTippen': '(o) Häuser! → vīllae',
  'nūntius latDeWahl': 'nūntiī → (o) Boten!',
  'nūntius deLatWahl': '(o) Boten! → nūntiī',
  'nūntius deLatTippen': '(o) Boten! → nūntiī',
  'cor latDeWahl': 'corda → (o) Herzen!',
  'cor deLatWahl': '(o) Herzen! → corda',
  'cor deLatTippen': '(o) Herzen! → corda',
  'Rōma latDeWahl': 'Rōmae → (ich helfe) Rom',
  'Rōma deLatWahl': '(ich helfe) Rom → Rōmae',
  'Rōma deLatTippen': '(ich helfe) Rom → Rōmae',
};

final _kinds = [
  for (final kind in [
    ExerciseKind.latDeWahl,
    ExerciseKind.deLatWahl,
    ExerciseKind.deLatTippen,
  ])
    generatorFor(kind, exerciseGenerators),
];

String _outcome(Exercise e) => switch (e.answer) {
  ChoiceAnswer(:final right) when e.kind == ExerciseKind.latDeWahl =>
    '${e.questionParams['form']} → ${right.text}',
  ChoiceAnswer(:final right) => '${e.questionParams['german']} → ${right.text}',
  TypedAnswer(:final accepted) =>
    '${e.questionParams['german']} → ${accepted.join(' | ')}',
  _ => throw StateError('unexpected answer ${e.answer}'),
};

void main() {
  late GrammarGermanForms german;
  late List<PracticeItem> nouns;
  late List<PracticeItem> spike;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    german = GrammarGermanForms(
      File('lib/data/german_verbs.yaml').readAsStringSync(),
      await loadGrammarFile('verbs'),
      nouns: (yaml: _yaml, latin: await loadGrammarFile('nouns')),
    );
    nouns = [
      for (final item in await loadPracticeItems('lib/data/latin_nouns.yaml'))
        if (german.germanNounOf.containsKey(item.id)) item,
    ];
    spike = [
      for (final item in nouns)
        if (_spikeLemmas.contains(item.lemma)) item,
    ];
  });

  PracticeItem latin(String lemma) =>
      nouns.singleWhere((i) => i.lemma == lemma);

  test('the ten spike nouns have a German noun', () {
    expect({for (final i in spike) i.lemma}, _spikeLemmas);
  });

  group('case frames', () {
    for (final key in _keys) {
      test('$key shows its frame and accepts the pinned texts', () {
        expect(
          _engineOf(_yaml).of('german_nouns', 'rahmen').forms[key]!.variants,
          _frames[key],
        );
        for (final MapEntry(key: lemma, value: texts) in _pinned.entries) {
          if (!texts.containsKey(key)) continue;
          final item = latin(lemma);
          expect(german.render(item, key), contains(_frames[key]!.first));
          expect(german.accepted(item, key), texts[key], reason: lemma);
        }
      });
    }

    test('the ablative takes mit and von with the dative, durch with the '
        'accusative, and vom for dem', () {
      for (final item in nouns) {
        for (final n in ['sg', 'pl']) {
          if (!german.covers(item, 'abl.$n')) continue;
          final dative = _unframed(german.render(item, 'dat.$n'));
          final accusative = _unframed(german.render(item, 'akk.$n'));
          expect(german.accepted(item, 'abl.$n'), [
            'mit $dative',
            'von $dative',
            'durch $accusative',
            if (dative.startsWith('dem ')) 'vom ${dative.substring(4)}',
          ], reason: '${item.lemma} abl.$n');
        }
      }
    });

    test('the genitive frame noun is no German noun of the data', () {
      final frames = _engineOf(_yaml).of('german_nouns', 'rahmen').forms;
      final frameNouns = {
        for (final key in ['gen.sg', 'gen.pl'])
          RegExp(
            r'^\((?:der|die|das) (\S+)\)$',
          ).firstMatch(frames[key]!.variants.single)!.group(1)!,
      };
      final file = parseGrammarFile(_yaml, path: _path);
      expect([
        for (final item in file.items)
          if (item.parts['nominativ']!.any(frameNouns.contains)) item.id,
      ], isEmpty);
    });
  });

  test('a plural-only noun has every plural case and no singular', () {
    final engine = _engineOf(_yaml);
    for (final MapEntry(key: id, value: texts) in _pinnedGermanOnly.entries) {
      final forms = engine.of('german_nouns', id).forms;
      expect(
        {
          for (final key in _keys)
            if (forms[key] != null) key: forms[key]!.variants,
        },
        texts,
        reason: id,
      );
    }
  });

  test('a German noun covers every case unless it lacks the plural', () {
    for (final item in nouns) {
      expect(
        [
          for (final key in _keys)
            if (german.covers(item, key)) key,
        ],
        _noPlural.contains(item.lemma)
            ? _keys.where((k) => k.endsWith('.sg')).toList()
            : _keys,
        reason: item.lemma,
      );
    }
  });

  group('engine points', () {
    test('the vom variant is absent where the vom slot has no form', () {
      for (final (lemma, key) in [
        ('rosa', 'abl.sg'),
        ('fīlia', 'abl.sg'),
        ('servus', 'abl.pl'),
        ('vīlla', 'abl.pl'),
      ]) {
        final accepted = german.accepted(latin(lemma), key);
        expect(accepted.length, 3, reason: '$lemma $key');
        expect(accepted.any((t) => t.startsWith('vom ')), isFalse);
      }
    });

    test('the dative plural takes one n at the plural seam', () {
      expect(
        {
          for (final item in spike)
            if (german.covers(item, 'dat.pl'))
              item.lemma: german.render(item, 'dat.pl'),
        },
        {
          'servus': '(ich helfe) den Sklaven',
          'nūntius': '(ich helfe) den Boten',
          'templum': '(ich helfe) den Tempeln',
          'Rōmānus': '(ich helfe) den Römern',
          'dōnum': '(ich helfe) den Geschenken',
          'vīlla': '(ich helfe) den Häusern',
          'rosa': '(ich helfe) den Rosen',
          'fīlia': '(ich helfe) den Töchtern',
          'cor': '(ich helfe) den Herzen',
        },
      );
    });

    test('the dative plural adds n only to a plural in neither n nor s', () {
      final engine = _engineOf('''
$_yaml  - type: Neutrum
    translation: {de: Kino, en: cinema}
    parts: {nominativ: Kino, genitiv: Kinos, plural: Kinos}
''');
      expect(
        {
          for (final id in ['kino', 'rose', 'geschenk'])
            id: engine.of('german_nouns', id).forms['dat.pl']!.variants,
        },
        {
          'kino': ['(ich helfe) den Kinos'],
          'rose': ['(ich helfe) den Rosen'],
          'geschenk': ['(ich helfe) den Geschenken'],
        },
      );
    });

    test('the dative plural names the rule of its own ending', () {
      final engine = _engineOf('''
$_yaml  - type: Neutrum
    translation: {de: Kino, en: cinema}
    parts: {nominativ: Kino, genitiv: Kinos, plural: Kinos}
''');
      expect(
        {
          for (final id in ['kino', 'rose', 'geschenk'])
            id: (engine.of('german_nouns', id).stems['dpl']! as StemFromDefault)
                .sandhiRule
                ?.id,
        },
        {'kino': 's_dativ', 'rose': 'n_dativ', 'geschenk': null},
      );
    });

    test('the plural of Rat is Ratschläge', () {
      final consilium = latin('cōnsilium');
      expect(german.accepted(consilium, 'nom.pl'), [
        'die Ratschläge (sind da)',
      ]);
      expect(german.render(consilium, 'dat.pl'), '(ich helfe) den Ratschlägen');
    });

    test('the plural of Seemann is Seeleute', () {
      expect(
        german.render(latin('nauta'), 'dat.pl'),
        '(ich helfe) den Seeleuten',
      );
    });

    test('dux is an Anführer', () {
      expect(
        german.render(latin('dux'), 'gen.sg'),
        '(die Farbe) des Anführers',
      );
    });

    test('a noun without plural has no dative plural', () {
      final rom = latin('Rōma');
      expect(german.covers(rom, 'dat.pl'), isFalse);
      expect(() => german.accepted(rom, 'dat.pl'), throwsArgumentError);
    });
  });

  test('A2, A3 and A7 build the pinned exercise with Random(207)', () {
    final built = <String, String>{};
    for (final word in spike) {
      final ctx = ExerciseContext(
        unlocked: {word.type},
        pool: spike,
        german: german,
      );
      for (final kind in _kinds) {
        final name = '${word.lemma} ${kind.kind.name}';
        try {
          built[name] = _outcome(kind.build(word, word.type, ctx, Random(207)));
        } on CannotBuild {
          built[name] = 'CannotBuild';
        }
      }
    }
    expect(built, _seededBuilds);
  });

  test('a German noun id used twice fails the parse', () {
    expect(
      () => _engineOf('''
$_yaml  - id: rose
    type: Femininum
    translation: {de: Rose, en: rose}
    parts: {nominativ: Rose, plural: Rosen}
'''),
      throwsA(
        isA<SchemaError>().having(
          (e) => e.toString(),
          'message',
          contains('two items share the id "rose"'),
        ),
      ),
    );
  });
}
