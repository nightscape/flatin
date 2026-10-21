import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_translate.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
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
    'gen.sg': ['(das Haus) des Sklaven'],
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
    'gen.pl': ['(das Haus) der Sklaven'],
    'dat.pl': ['(ich helfe) den Sklaven'],
    'akk.pl': ['(ich sehe) die Sklaven'],
    'abl.pl': ['mit den Sklaven', 'von den Sklaven', 'durch die Sklaven'],
    'vok.pl': ['(o) Sklaven!'],
  },
  'rosa': {
    'nom.sg': ['die Rose (ist da)'],
    'gen.sg': ['(das Haus) der Rose'],
    'dat.sg': ['(ich helfe) der Rose'],
    'akk.sg': ['(ich sehe) die Rose'],
    'abl.sg': ['mit der Rose', 'von der Rose', 'durch die Rose'],
    'vok.sg': ['(o) Rose!'],
    'nom.pl': ['die Rosen (sind da)'],
    'gen.pl': ['(das Haus) der Rosen'],
    'dat.pl': ['(ich helfe) den Rosen'],
    'akk.pl': ['(ich sehe) die Rosen'],
    'abl.pl': ['mit den Rosen', 'von den Rosen', 'durch die Rosen'],
    'vok.pl': ['(o) Rosen!'],
  },
  'vīlla': {
    'nom.sg': ['das Haus (ist da)'],
    'gen.sg': ['(das Haus) des Hauses'],
    'dat.sg': ['(ich helfe) dem Haus'],
    'akk.sg': ['(ich sehe) das Haus'],
    'abl.sg': ['mit dem Haus', 'von dem Haus', 'durch das Haus', 'vom Haus'],
    'vok.sg': ['(o) Haus!'],
    'nom.pl': ['die Häuser (sind da)'],
    'gen.pl': ['(das Haus) der Häuser'],
    'dat.pl': ['(ich helfe) den Häusern'],
    'akk.pl': ['(ich sehe) die Häuser'],
    'abl.pl': ['mit den Häusern', 'von den Häusern', 'durch die Häuser'],
    'vok.pl': ['(o) Häuser!'],
  },
  'cor': {
    'nom.sg': ['das Herz (ist da)'],
    'gen.sg': ['(das Haus) des Herzens'],
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
    'gen.pl': ['(das Haus) der Herzen'],
    'dat.pl': ['(ich helfe) den Herzen'],
    'akk.pl': ['(ich sehe) die Herzen'],
    'abl.pl': ['mit den Herzen', 'von den Herzen', 'durch die Herzen'],
    'vok.pl': ['(o) Herzen!'],
  },
  'Rōma': {
    'nom.sg': ['Rom (ist da)'],
    'gen.sg': ['(das Haus) Roms'],
    'dat.sg': ['(ich helfe) Rom'],
    'akk.sg': ['(ich sehe) Rom'],
    'abl.sg': ['mit Rom', 'von Rom', 'durch Rom'],
    'vok.sg': ['(o) Rom!'],
  },
};

/// German noun id → the texts of each key, for a noun without a Latin item.
const _pinnedGermanOnly = {
  'eltern': {
    'nom.pl': ['die Eltern (sind da)'],
    'gen.pl': ['(das Haus) der Eltern'],
    'dat.pl': ['(ich helfe) den Eltern'],
    'akk.pl': ['(ich sehe) die Eltern'],
    'abl.pl': ['mit den Eltern', 'von den Eltern', 'durch die Eltern'],
    'vok.pl': ['(o) Eltern!'],
  },
};

/// The Latin items whose German noun has no plural.
const _singularOnly = {'Rōma'};

/// `<Latin lemma> <kind>` → what Random(207) builds over the whole case
/// bundle: the shown text, then the right answer or the accepted set.
const _seed207 = {
  'servus latDeWahl': 'serve → (o) Sklave!',
  'servus deLatWahl': '(o) Sklave! → serve',
  'servus deLatTippen': '(o) Sklave! → serve',
  'nūntius latDeWahl': 'nūntie → (o) Bote!',
  'nūntius deLatWahl': '(o) Bote! → nūntie',
  'nūntius deLatTippen': '(o) Bote! → nūntie',
  'templum latDeWahl': 'CannotBuild',
  'templum deLatWahl': '(o) Tempel! → templum',
  'templum deLatTippen': '(o) Tempel! → templum | templa',
  'Rōmānus latDeWahl': 'Rōmāne → (o) Römer!',
  'Rōmānus deLatWahl': '(o) Römer! → Rōmāne',
  'Rōmānus deLatTippen': '(o) Römer! → Rōmāne | Rōmānī',
  'dōnum latDeWahl': 'dōnum → (o) Geschenk!',
  'dōnum deLatWahl': '(o) Geschenk! → dōnum',
  'dōnum deLatTippen': '(o) Geschenk! → dōnum',
  'vīlla latDeWahl': 'CannotBuild',
  'vīlla deLatWahl': '(o) Haus! → vīlla',
  'vīlla deLatTippen': '(o) Haus! → vīlla',
  'rosa latDeWahl': 'CannotBuild',
  'rosa deLatWahl': '(o) Rose! → rosa',
  'rosa deLatTippen': '(o) Rose! → rosa',
  'fīlia latDeWahl': 'CannotBuild',
  'fīlia deLatWahl': '(o) Tochter! → fīlia',
  'fīlia deLatTippen': '(o) Tochter! → fīlia',
  'cor latDeWahl': 'cor → (o) Herz!',
  'cor deLatWahl': '(o) Herz! → cor',
  'cor deLatTippen': '(o) Herz! → cor',
  'Rōma latDeWahl': 'CannotBuild',
  'Rōma deLatWahl': 'mit Rom → Rōmā',
  'Rōma deLatTippen': 'mit Rom → Rōmā',
};

const _kinds = [
  LatDeChoiceGenerator(),
  DeLatChoiceGenerator(),
  DeLatTypeGenerator(),
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
  });

  PracticeItem latin(String lemma) =>
      nouns.singleWhere((i) => i.lemma == lemma);

  test('ten Latin nouns have a German noun', () {
    expect(
      {for (final i in nouns) i.lemma},
      {
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
      },
    );
  });

  test('every case of the pinned nouns shows and accepts its German text', () {
    for (final MapEntry(key: lemma, value: texts) in _pinned.entries) {
      final item = latin(lemma);
      expect(
        {
          for (final key in _keys)
            if (german.covers(item, key)) key: german.accepted(item, key),
        },
        texts,
        reason: lemma,
      );
    }
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
        _singularOnly.contains(item.lemma)
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
          for (final item in nouns)
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

    test('a noun without plural has no dative plural', () {
      final rom = latin('Rōma');
      expect(german.covers(rom, 'dat.pl'), isFalse);
      expect(() => german.accepted(rom, 'dat.pl'), throwsArgumentError);
    });
  });

  test('A2, A3 and A7 build the pinned exercise with Random(207)', () {
    final built = <String, String>{};
    for (final word in nouns) {
      final ctx = ExerciseContext(
        unlocked: {word.type},
        pool: nouns,
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
    expect(built, _seed207);
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
