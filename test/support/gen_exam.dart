import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/languages/language.dart';

/// The language of the exam packs the tests draw and read.
final latin = Language.parse(File(latinAsset).readAsStringSync());

/// The codes of the `analyse` key [key] of [latin].
List<Object> codes(String key) => latin.analyse[key]!;

/// Draws valid `.exam` packs as the YAML data model of [examToYaml], and
/// counts in [reach] which features it drew.
final class ExamGen {
  final Random r;
  final reach = <String, int>{};
  ExamGen(this.r);

  static const reachKeys = [
    'empty hilfen',
    'one-token sentence',
    'non-contiguous clause',
    'empty clause',
    'punctuation',
    'enclitic',
    'compound passive',
    'infinitive passive',
    'compound passive bilden',
    'one-word PPP bilden',
    'participium coniunctum',
    'relative pronoun',
    'nested variant',
    'optional variant',
    'empty alternative',
    'choice in brackets',
    'wissen_mc with teilsatz',
    'task without points',
  ];

  void hit(String what) => reach[what] = (reach[what] ?? 0) + 1;

  T pick<T>(List<T> xs) => xs[r.nextInt(xs.length)];

  bool chance(double p) => r.nextDouble() < p;

  List<int> distinct(int n, int max) =>
      (List.generate(max, (i) => i + 1)..shuffle(r)).take(n).toList();

  static const _latin = ['lupus', 'ventus', 'aqua', 'silva', 'lūx', 'iter'];
  static const _german = ['der', 'Wolf', 'sieht', 'im', 'Wald', 'Licht'];
  static const _marks = [',', ':', '„', '“', '–'];
  static const _ends = ['.', '?', '!'];

  String phrase(List<String> pool) =>
      [for (var i = 0; i <= r.nextInt(3); i++) pick(pool)].join(' ');

  /// A well-formed variant string of nesting [depth] at most.
  String variant([int depth = 2]) => _seq(depth, 0);

  String _seq(int depth, int level) {
    final parts = <String>[];
    final count = 1 + r.nextInt(level == 0 ? 3 : 2);
    for (var i = 0; i < count; i++) {
      if (level >= depth || chance(0.6)) {
        parts.add(pick(_german));
        continue;
      }
      if (level > 0) hit('nested variant');
      if (chance(0.3)) {
        hit('optional variant');
        final inner = [
          for (var j = 0; j < (chance(0.2) ? 2 : 1); j++)
            _seq(depth, level + 1),
        ];
        if (inner.length > 1) hit('choice in brackets');
        parts.add('[${inner.join(' | ')}]');
      } else {
        final alternatives = [
          for (var j = 0; j <= 1 + r.nextInt(2); j++)
            chance(0.15) ? '' : _seq(depth, level + 1),
        ];
        if (alternatives.contains('')) hit('empty alternative');
        parts.add('(${alternatives.join(' | ')})');
      }
    }
    return parts.join(' ');
  }

  /// [reading] changed by [m] at a drawn word, or null when [reading] has
  /// too few words for [m].
  String? mutate(String reading, ReadingMutation m) {
    final words = reading.isEmpty ? <String>[] : reading.split(' ');
    switch (m) {
      case ReadingMutation.drop when words.isNotEmpty:
        words.removeAt(r.nextInt(words.length));
      case ReadingMutation.add:
        words.insert(r.nextInt(words.length + 1), pick(_german));
      case ReadingMutation.swap when words.length >= 2:
        final [i, j] = [for (final x in distinct(2, words.length)) x - 1];
        final first = words[i];
        words[i] = words[j];
        words[j] = first;
      case ReadingMutation.replace when words.isNotEmpty:
        words[r.nextInt(words.length)] = outsideWord;
      default:
        return null;
    }
    return words.join(' ');
  }

  List<String> variants(int least, int most) => [
    for (var i = 0; i < least + r.nextInt(most - least + 1); i++) variant(),
  ];

  Map<String, Object> features({bool verb = false}) {
    final f = <String, Object>{};
    if (!verb || chance(0.3)) {
      f['kasus'] = pick(codes('kasus'));
      f['numerus'] = pick(codes('numerus'));
      if (chance(0.8)) f['genus'] = pick(codes('genus'));
    }
    if (verb) {
      if (chance(0.8)) f['person'] = 1 + r.nextInt(3);
      f['numerus'] = pick(codes('numerus'));
      f['tempus'] = pick(codes('tempus'));
      f['modus'] = pick([
        for (final m in codes('modus'))
          if (m != 'part') m,
      ]);
      f['genus_verbi'] = pick(codes('genus_verbi'));
    }
    return f;
  }

  Map<String, Object> exam() {
    final sentenceNumbers = distinct(1 + r.nextInt(3), 40);
    final saetze = [for (final n in sentenceNumbers) sentence('s$n')];
    final words = [
      for (final s in saetze)
        for (final t in s['tokens'] as List<Map<String, Object>>)
          if (t.containsKey('lemma')) t,
    ];
    final lemmas = {for (final t in words) t['lemma'] as String}.toList()
      ..shuffle(r);
    final hilfen = [
      for (final lemma in lemmas.take(chance(0.3) ? 0 : r.nextInt(3) + 1))
        {
          'lemma': lemma,
          'angabe': phrase(_latin),
          'de': phrase(_german),
          'tokens': [
            for (final t in words)
              if (t['lemma'] == lemma) t['id'] as String,
          ]..shuffle(r),
        },
    ];
    if (hilfen.isEmpty) hit('empty hilfen');
    final pcs = [
      for (final s in saetze)
        for (final c in s['teilsaetze'] as List<Map<String, Object>>)
          if (c['art'] == 'pc') c,
    ];
    final taskNumbers = distinct(r.nextInt(7), 30);
    final aufgaben = [for (final n in taskNumbers) task(n, words, pcs)];
    final uebersetzungPunkte = r.nextInt(40);
    return {
      'schema': 1,
      'id': phrase(_latin),
      'titel': phrase(_german),
      'lektionen': {'von': 1 + r.nextInt(20), 'bis': 1 + r.nextInt(30)},
      'schwerpunkte': [for (var i = 0; i < r.nextInt(3); i++) 'L${i + 1}.1'],
      'schwerpunkt': phrase(_german),
      'thema': phrase(_german),
      'zeit_min': 10 + r.nextInt(50),
      'punkte_uebersetzung': uebersetzungPunkte,
      'punkte_gesamt': aufgaben.fold<int>(
        uebersetzungPunkte,
        (sum, t) => sum + (t['punkte'] as int),
      ),
      'uebersetzung': {'hilfen': hilfen, 'saetze': saetze},
      'aufgaben': aufgaben,
    };
  }

  Map<String, Object> sentence(String sid) {
    final n = 1 + r.nextInt(8);
    if (n == 1) hit('one-token sentence');
    final clauseCount = 1 + r.nextInt(min(3, n));
    final letters = ('abcdefgh'.split('')..shuffle(r)).take(clauseCount);
    final clauseIds = [for (final l in letters) '$sid$l'];
    final arts = [
      'haupt',
      for (var i = 1; i < clauseCount; i++) pick(latin.clauseArt),
    ];
    var pcCount = 0;
    for (var i = 0; i < arts.length; i++) {
      if (arts[i] != 'pc') continue;
      if (2 * (pcCount + 1) > n) {
        arts[i] = 'relativ';
      } else {
        pcCount++;
      }
    }
    final superordinate = [
      for (var c = 0; c < clauseCount; c++)
        arts[c] != 'haupt' || (clauseCount > 1 && chance(0.2)),
    ];
    final ids = [for (final x in distinct(n, 30)) '${sid}_$x'];
    final kinds = <_Kind>[];
    final pcClauses = [
      for (var i = 0; i < arts.length; i++)
        if (arts[i] == 'pc') i,
    ];
    final sinnrichtung = {
      for (final c in pcClauses) c: pick(latin.sinnrichtung),
    };
    final plainClauses = [
      for (var i = 0; i < arts.length; i++)
        if (arts[i] != 'pc') i,
    ];
    for (final c in pcClauses) {
      final noun = _Kind('noun', pick(plainClauses))..participleBezug = true;
      kinds.add(noun);
      kinds.add(_Kind('participle', c)..bezug = noun);
    }
    while (kinds.length < n) {
      final left = n - kinds.length;
      final kind = pick([
        'noun',
        'adj',
        'relpron',
        'pron',
        'verb',
        'enclitic',
        'punct',
        'conj',
        'adv',
        if (left >= 2) 'pair',
      ]);
      if (kind == 'pair') {
        final ppp = _Kind('ppp', r.nextInt(clauseCount));
        final esse = _Kind('esse', r.nextInt(clauseCount));
        ppp.pair = esse;
        esse.pair = ppp;
        kinds.addAll([ppp, esse]);
      } else {
        kinds.add(_Kind(kind, r.nextInt(clauseCount)));
      }
    }
    kinds.shuffle(r);
    for (final (i, k) in kinds.indexed) {
      k.id = ids[i];
    }
    final wordKinds = [
      for (final k in kinds)
        if (k.name != 'punct') k,
    ];
    bool dependent(_Kind k) => k.name == 'participle' || k.name == 'esse';
    final drawn = {
      for (final k in [
        ...kinds.where((k) => !dependent(k)),
        ...kinds.where(dependent),
      ])
        k: _token(
          k,
          wordKinds,
          sinnrichtung[k.clause],
          superordinate[k.clause],
        ),
    };
    final tokens = [for (final k in kinds) drawn[k]!];

    final teilsaetze = <Map<String, Object>>[];
    for (var c = 0; c < clauseCount; c++) {
      final positions = [
        for (var i = 0; i < n; i++)
          if (kinds[i].clause == c) i,
      ];
      if (positions.isEmpty) hit('empty clause');
      if (positions.isNotEmpty &&
          positions.last - positions.first + 1 != positions.length) {
        hit('non-contiguous clause');
      }
      final members = [for (final i in positions) kinds[i].id];
      if (chance(0.1)) members.shuffle(r);
      final aligned = [
        for (final i in positions)
          if (kinds[i].name != 'punct') kinds[i].id,
      ]..shuffle(r);
      final ausrichtung = <Map<String, Object>>[];
      while (aligned.isNotEmpty) {
        final take = min(aligned.length, 1 + r.nextInt(3));
        ausrichtung.add({
          'tokens': aligned.sublist(0, take),
          'de': chance(0.1) ? '' : variant(),
        });
        aligned.removeRange(0, take);
      }
      final others = [
        for (final id in clauseIds)
          if (id != clauseIds[c]) id,
      ];
      hit('clause ${arts[c]}');
      teilsaetze.add({
        'id': clauseIds[c],
        'art': arts[c],
        'tokens': members,
        if (superordinate[c])
          'uebergeordnet': others.isEmpty ? clauseIds[c] : pick(others),
        if (arts[c] == 'pc') 'sinnrichtung': sinnrichtung[c]!,
        'de': variants(0, 2),
        'ausrichtung': ausrichtung,
      });
    }
    return {
      'id': sid,
      'tokens': tokens,
      'teilsaetze': teilsaetze,
      'de': variants(1, 3),
    };
  }

  Map<String, Object> _token(
    _Kind k,
    List<_Kind> wordKinds,
    String? sinnrichtung,
    bool subordinate,
  ) {
    if (k.name == 'punct') {
      hit('punctuation');
      return {
        'id': k.id,
        'la': pick([..._marks, if (!subordinate) ..._ends]),
      };
    }
    String other() =>
        (wordKinds.length > 1 ? pick([...wordKinds]..remove(k)) : k).id;
    final t = <String, Object>{'id': k.id, 'la': pick(_latin)};
    void word(String lemma, String wortart, Map<String, Object> f) {
      t['lemma'] = lemma;
      t['analyse'] = {'wortart': wortart, ...f};
    }

    switch (k.name) {
      case 'noun':
        final f = features();
        if (k.participleBezug) f['genus'] ??= pick(codes('genus'));
        if (chance(0.1)) f['funktion'] = pick(codes('funktion'));
        word(pick(['lupus', 'silva', 'iter']), 'subst', f);
        k.features = f;
        if (chance(0.7)) {
          t['rolle'] = pick([
            'subjekt',
            'objekt',
            'adverbiale',
            'praedikatsnomen',
            'anrede',
          ]);
        }
        if (chance(0.1)) t['bezug'] = other();
      case 'adj':
        word('magnus', 'adj', features());
        t['rolle'] = pick(['attribut', 'praedikativum']);
        t['bezug'] = other();
      case 'relpron':
        hit('relative pronoun');
        word('quī', 'pron', {...features(), 'pronomen': 'relativ'});
        t['rolle'] = pick(['subjekt', 'objekt']);
        t['bezug'] = other();
      case 'pron':
        final pronomen = pick([
          for (final p in codes('pronomen'))
            if (p != 'relativ') p,
        ]);
        word('is', 'pron', {
          ...features(),
          if (pronomen == 'personal') 'person': 1 + r.nextInt(3),
          'pronomen': pronomen,
        });
      case 'verb':
        final f = features(verb: true);
        if (f['genus_verbi'] == 'pass') {
          f['tempus'] = pick(['praes', 'impf', 'fut']);
        }
        word(pick(['vidēre', 'ire']), 'verb', f);
        t['rolle'] = 'praedikat';
      case 'enclitic':
        hit('enclitic');
        t['la'] = '-ne';
        word('-ne', 'partikel', {});
      case 'conj':
        word('et', pick(['konjunktion', 'subjunktion']), {});
      case 'adv':
        word('saepe', pick(['adv', 'praep']), {});
        if (chance(0.5)) t['rolle'] = 'adverbiale';
      case 'participle':
        hit('participium coniunctum');
        final b = k.bezug!;
        word('laudāre', 'verb', {
          for (final key in ['kasus', 'numerus', 'genus'])
            if (b.features.containsKey(key)) key: b.features[key]!,
          'tempus': 'perf',
          'modus': 'part',
          'genus_verbi': 'pass',
        });
        t['rolle'] = sinnrichtung == 'attributiv' ? 'attribut' : 'adverbiale';
        t['bezug'] = b.id;
      case 'ppp' || 'esse':
        final ppp = k.name == 'ppp' ? k : k.pair!;
        if (k.name == 'ppp') {
          hit('compound passive');
          final infinitive = chance(0.25);
          if (infinitive) hit('infinitive passive');
          k.features = {
            'kasus': pick(codes('kasus')),
            'numerus': pick(codes('numerus')),
            'genus': pick(codes('genus')),
            if (!infinitive) 'person': 1 + r.nextInt(3),
            'tempus': infinitive ? 'perf' : pick(['perf', 'plusq', 'fut2']),
            'modus': infinitive ? 'inf' : pick(['ind', 'konj']),
            'genus_verbi': 'pass',
          };
          word('portāre', 'verb', k.features);
        } else {
          word('esse', 'verb', _esseFeatures(ppp));
        }
        t['rolle'] = 'praedikat';
        t['verbform'] = [ppp.id, ppp.pair!.id];
    }
    return t;
  }

  Map<String, Object> _esseFeatures(_Kind ppp) {
    final p = ppp.features;
    if (p['modus'] == 'inf') {
      return {'tempus': 'praes', 'modus': 'inf', 'genus_verbi': 'akt'};
    }
    return {
      'numerus': ?p['numerus'],
      'person': ?p['person'],
      'tempus': const {
        'perf': 'praes',
        'plusq': 'impf',
        'fut2': 'fut',
      }[p['tempus']]!,
      'modus': p['modus']!,
      'genus_verbi': 'akt',
    };
  }

  Map<String, Object> task(
    int number,
    List<Map<String, Object>> words,
    List<Map<String, Object>> pcs,
  ) {
    final arts = [
      for (final a in ItemArt.values)
        if (a != ItemArt.bestimmen || words.isNotEmpty) a.code,
      'ordnen',
      'frei',
    ];
    final art = pick(arts);
    hit('task $art');
    final head = <String, Object>{
      'id': '${pick('abcdefgh'.split(''))}$number',
      'titel': phrase(_german),
      'art': art,
      'frage': phrase(_german),
      'loesung': [for (var i = 0; i < r.nextInt(3); i++) phrase(_german)],
    };
    if (art == 'ordnen' || art == 'frei') {
      if (art == 'ordnen') {
        head['elemente'] = [
          for (var i = 0; i < 3 + r.nextInt(3); i++) phrase(_german),
        ];
      }
      return {...head, 'punkte': r.nextInt(5)};
    }
    final items = [
      for (var i = 0; i <= r.nextInt(3); i++)
        {
          ...item(ItemArt.values.byName(_camel(art)), words, pcs),
          'punkte': r.nextInt(4),
        },
    ];
    final sum = items.fold(0, (s, i) => s + (i['punkte'] as int));
    if (sum == 0) hit('task without points');
    return {...head, 'items': items, 'punkte': sum};
  }

  Map<String, Object> item(
    ItemArt art,
    List<Map<String, Object>> words,
    List<Map<String, Object>> pcs,
  ) => switch (art) {
    ItemArt.bestimmen => () {
      final t = pick(words);
      final annotated = [
        'lemma',
        ...(t['analyse'] as Map<String, Object>).keys,
        if (t.containsKey('bezug')) 'bezug',
      ]..shuffle(r);
      return {
        'token': t['id']!,
        'merkmale': annotated.take(1 + r.nextInt(annotated.length)).toList(),
      };
    }(),
    ItemArt.stammformen => {
      'lemma': pick(_latin),
      'stammformen': [for (var i = 0; i < 4; i++) pick(_latin)],
    },
    ItemArt.bilden => () {
      if (chance(0.15)) {
        hit('one-word PPP bilden');
        return pppBilden(pick(_latin));
      }
      final merkmale = features(verb: chance(0.5));
      final compound =
          merkmale['genus_verbi'] == 'pass' &&
          const ['perf', 'plusq', 'fut2'].contains(merkmale['tempus']);
      if (compound) hit('compound passive bilden');
      return {
        'lemma': pick(_latin),
        'merkmale': merkmale,
        'form': compound ? '${pick(_latin)} ${pick(_latin)}' : phrase(_latin),
      };
    }(),
    ItemArt.umformen => {'vorgabe': phrase(_latin), 'ziel': variants(1, 2)},
    ItemArt.vokabel => {'la': pick(_latin), 'de': variants(1, 2)},
    ItemArt.ableitung => {'fremdwort': pick(_german), 'la': pick(_latin)},
    ItemArt.kurzantwort => {
      'frage': phrase(_german),
      'stichwoerter': [
        for (var i = 0; i <= r.nextInt(2); i++)
          [for (var j = 0; j <= r.nextInt(3); j++) pick(_german)],
      ],
    },
    ItemArt.wissenMc => () {
      final optionen = {
        for (var i = 0; i <= r.nextInt(3); i++) pick(_german),
      }.toList();
      if (pcs.isNotEmpty && chance(0.5)) {
        hit('wissen_mc with teilsatz');
        final c = pick(pcs);
        final richtig = c['sinnrichtung'] as String;
        return {
          'frage': phrase(_german),
          'teilsatz': c['id']!,
          'optionen': [...optionen, richtig]..shuffle(r),
          'richtig': richtig,
        };
      }
      return {
        'frage': phrase(_german),
        'optionen': optionen,
        'richtig': pick(optionen),
      };
    }(),
  };
}

/// The ways [ExamGen.mutate] turns a reading into a nearby text.
enum ReadingMutation { drop, add, swap, replace }

/// A word [ExamGen.variant] never draws.
const outsideWord = 'Fuchs';

/// A `bilden` item of a PPP: `modus: part`, so its form is one word.
Map<String, Object> pppBilden(String form) => {
  'lemma': 'portāre',
  'merkmale': {
    'kasus': 'nom',
    'numerus': 'sg',
    'genus': 'm',
    'tempus': 'perf',
    'modus': 'part',
    'genus_verbi': 'pass',
  },
  'form': form,
};

String _camel(String code) =>
    code.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());

final class _Kind {
  final String name;
  final int clause;
  late final String id;
  _Kind? bezug;
  _Kind? pair;
  bool participleBezug = false;
  Map<String, Object> features = {};
  _Kind(this.name, this.clause);
}

typedef _Site = ({Map<String, dynamic> node, String path, String sid});

/// Breaks [rule] in [exam], a mutable copy of a valid pack, and returns the
/// path its error names, or null when the pack has no place for the break.
String? breakRule(ExamRule rule, Map<String, dynamic> exam, Random r) {
  T pick<T>(List<T> xs) => xs[r.nextInt(xs.length)];
  final saetze = <_Site>[];
  final tokens = <_Site>[];
  final clauses = <_Site>[];
  for (final (i, s) in (exam['uebersetzung']['saetze'] as List).indexed) {
    final path = 'exam.uebersetzung.saetze[$i]';
    final sid = s['id'] as String;
    saetze.add((node: s, path: path, sid: sid));
    for (final (j, t) in (s['tokens'] as List).indexed) {
      tokens.add((node: t, path: '$path.tokens[$j]', sid: sid));
    }
    for (final (k, c) in (s['teilsaetze'] as List).indexed) {
      clauses.add((node: c, path: '$path.teilsaetze[$k]', sid: sid));
    }
  }
  final clauseOf = {
    for (final c in clauses)
      for (final id in c.node['tokens'] as List) id: c.node,
  };
  final hilfen = [
    for (final (i, h) in (exam['uebersetzung']['hilfen'] as List).indexed)
      (
        node: h as Map<String, dynamic>,
        path: 'exam.uebersetzung.hilfen[$i]',
        sid: '',
      ),
  ];
  final tasks = [
    for (final (i, t) in (exam['aufgaben'] as List).indexed)
      (node: t as Map<String, dynamic>, path: 'exam.aufgaben[$i]', sid: ''),
  ];
  List<_Site> items(String art) => [
    for (final t in tasks)
      if (t.node['art'] == art)
        for (final (j, item) in (t.node['items'] as List).indexed)
          (
            node: item as Map<String, dynamic>,
            path: '${t.path}.items[$j]',
            sid: '',
          ),
  ];
  final words = [
    for (final t in tokens)
      if (t.node.containsKey('lemma')) t,
  ];
  final marks = [
    for (final t in tokens)
      if (!t.node.containsKey('lemma')) t,
  ];
  bool isParticiple(_Site t) => t.node['analyse']?['modus'] == 'part';
  final participles = words.where(isParticiple).toList();
  final pcs = [
    for (final c in clauses)
      if (c.node['art'] == 'pc') c,
  ];
  List<String> members(_Site c) => (c.node['tokens'] as List).cast<String>();
  String add(List list, Object? value) {
    list.add(value);
    return '[${list.length - 1}]';
  }

  String? from<T>(List<T> sites, String Function(T) f) =>
      sites.isEmpty ? null : f(pick(sites));

  switch (rule) {
    case ExamRule.yaml:
      throw ArgumentError.value(rule, 'rule', 'breaks the text: breakYaml');
    case ExamRule.schema:
      exam['schema'] = 2;
      return 'exam.schema';
    case ExamRule.field:
      switch (r.nextInt(3)) {
        case 0:
          exam.remove('thema');
          return 'exam';
        case 1:
          final t = pick(tokens);
          t.node.remove('la');
          return t.path;
      }
      final required = <(Map<String, dynamic>, String, String)>[
        for (final key in ['schema', 'id', 'titel', 'lektionen', 'zeit_min'])
          (exam, key, 'exam'),
        for (final key in ['schwerpunkte', 'uebersetzung', 'aufgaben'])
          (exam, key, 'exam'),
        for (final key in ['hilfen', 'saetze'])
          (exam['uebersetzung'], key, 'exam.uebersetzung'),
        for (final key in ['von', 'bis'])
          (exam['lektionen'], key, 'exam.lektionen'),
        for (final s in saetze)
          for (final key in ['id', 'tokens', 'teilsaetze', 'de'])
            (s.node, key, s.path),
        for (final t in tokens)
          for (final key in ['id', 'la', 'lemma', 'analyse'])
            if (t.node.containsKey(key)) (t.node, key, t.path),
        for (final t in words)
          (t.node['analyse'], 'wortart', '${t.path}.analyse'),
        for (final c in clauses)
          for (final key in ['id', 'art', 'tokens', 'de', 'ausrichtung'])
            (c.node, key, c.path),
        for (final h in hilfen)
          for (final key in h.node.keys) (h.node, key, h.path),
        for (final t in tasks)
          for (final key in t.node.keys) (t.node, key, t.path),
        for (final t in tasks)
          for (final (j, i) in (t.node['items'] as List? ?? []).indexed)
            for (final key in (i as Map<String, dynamic>).keys)
              if (key != 'teilsatz') (i, key, '${t.path}.items[$j]'),
      ];
      final (node, key, path) = pick(required);
      node[key] = null;
      return '$path.$key';
    case ExamRule.key:
      final c = pick(clauses);
      c.node['extra'] = 'x';
      return '${c.path}.extra';
    case ExamRule.type:
      if (r.nextBool()) {
        final s = pick(saetze);
        s.node['id'] = 7;
        return '${s.path}.id';
      }
      final lists = <(List, String)>[
        (exam['schwerpunkte'], 'exam.schwerpunkte'),
        for (final s in saetze) ...[
          (s.node['de'], '${s.path}.de'),
          (s.node['tokens'], '${s.path}.tokens'),
        ],
        for (final c in clauses) ...[
          (c.node['tokens'], '${c.path}.tokens'),
          (c.node['de'], '${c.path}.de'),
        ],
        for (final h in hilfen) (h.node['tokens'], '${h.path}.tokens'),
        for (final t in tasks) (t.node['loesung'], '${t.path}.loesung'),
      ];
      final (list, path) = pick(lists);
      return '$path${add(list, null)}';
    case ExamRule.code:
      final sites = <(Map, String, String, List<Object>)>[
        for (final c in clauses) ...[
          (c.node, 'art', c.path, latin.clauseArt),
          if (c.node.containsKey('sinnrichtung'))
            (c.node, 'sinnrichtung', c.path, latin.sinnrichtung),
        ],
        for (final t in words) ...[
          if (t.node.containsKey('rolle'))
            (t.node, 'rolle', t.path, latin.rolle),
          for (final key in (t.node['analyse'] as Map).keys)
            (t.node['analyse'], key, '${t.path}.analyse', codes(key)),
        ],
        for (final i in items('bilden'))
          for (final key in (i.node['merkmale'] as Map).keys)
            (i.node['merkmale'], key, '${i.path}.merkmale', codes(key)),
      ];
      final (node, key, path, valid) = pick(sites);
      node[key] = valid.first is int ? valid.length + 1 : '${node[key]}_x';
      assert(!valid.contains(node[key]));
      return '$path.$key';
    case ExamRule.empty:
      final s = pick(saetze);
      s.node['de'] = [];
      return '${s.path}.de';
    case ExamRule.idShape:
      final c = pick(clauses);
      c.node['id'] = '${c.node['id']}x';
      return '${c.path}.id';
    case ExamRule.idTwice:
      if (tasks.length < 2) return null;
      final second = 1 + r.nextInt(tasks.length - 1);
      tasks[second].node['id'] = tasks[r.nextInt(second)].node['id'];
      return '${tasks[second].path}.id';
    case ExamRule.refClauseToken:
      final c = pick(clauses);
      return '${c.path}.tokens${add(c.node['tokens'], '${c.sid}_999')}';
    case ExamRule.refAlignment:
      final entries = [
        for (final c in clauses)
          for (final (j, a) in (c.node['ausrichtung'] as List).indexed)
            (
              node: a as Map<String, dynamic>,
              path: '${c.path}.ausrichtung[$j]',
              sid: c.sid,
            ),
      ];
      return from(
        entries,
        (a) => '${a.path}.tokens${add(a.node['tokens'], '${a.sid}_999')}',
      );
    case ExamRule.refHilfe:
      return from(
        hilfen,
        (h) => '${h.path}.tokens${add(h.node['tokens'], 's999_1')}',
      );
    case ExamRule.refBezug:
      return from(words, (t) {
        t.node['bezug'] = '${t.sid}_999';
        return '${t.path}.bezug';
      });
    case ExamRule.refVerbform:
      return from(
        [
          for (final t in words)
            if (t.node.containsKey('verbform')) t,
        ],
        (t) {
          t.node['verbform'][1] = '${t.sid}_999';
          return '${t.path}.verbform[1]';
        },
      );
    case ExamRule.refUebergeordnet:
      final c = pick(clauses);
      c.node['uebergeordnet'] = '${c.sid}z';
      return '${c.path}.uebergeordnet';
    case ExamRule.uebergeordnet:
      return from(
        [
          for (final c in clauses)
            if (c.node['art'] != 'haupt') c,
        ],
        (c) {
          c.node.remove('uebergeordnet');
          return c.path;
        },
      );
    case ExamRule.refItemToken:
      return from(items('bestimmen'), (i) {
        i.node['token'] = 's999_1';
        return '${i.path}.token';
      });
    case ExamRule.refItemTeilsatz:
      return from(items('wissen_mc'), (i) {
        i.node['teilsatz'] = 's999a';
        return '${i.path}.teilsatz';
      });
    case ExamRule.tokenTwice:
      final s = pick(saetze);
      final own = [
        for (final c in clauses)
          if (c.sid == s.sid) c,
      ];
      final holders = [
        for (final c in own)
          if (members(c).isNotEmpty) c,
      ];
      if (holders.isEmpty) return null;
      final a = pick(holders);
      final b = pick(own);
      (b.node['tokens'] as List).add(pick(members(a)));
      return own.indexOf(a) > own.indexOf(b) ? a.path : b.path;
    case ExamRule.tokenNoClause:
      final t = pick(tokens);
      final id = t.node['id'];
      for (final c in clauses) {
        (c.node['tokens'] as List).remove(id);
        for (final a in c.node['ausrichtung'] as List) {
          (a['tokens'] as List).remove(id);
        }
      }
      return t.path;
    case ExamRule.alignment:
      return from(
        [
          for (final c in clauses)
            if ((c.node['ausrichtung'] as List).isNotEmpty) c,
        ],
        (c) {
          (c.node['ausrichtung'] as List).removeAt(0);
          return '${c.path}.ausrichtung';
        },
      );
    case ExamRule.hilfeLemma:
      final pairs = [
        for (final h in hilfen)
          for (final t in words)
            if (t.node['lemma'] != h.node['lemma']) (h, t),
      ];
      return from(
        pairs,
        (p) =>
            '${p.$1.path}.tokens${add(p.$1.node['tokens'], p.$2.node['id'])}',
      );
    case ExamRule.hilfeTokens:
      return from(
        [
          for (final h in hilfen)
            if ((h.node['tokens'] as List).isNotEmpty) h,
        ],
        (h) {
          (h.node['tokens'] as List).removeLast();
          return '${h.path}.tokens';
        },
      );
    case ExamRule.variant:
      final sites = <(List, int, String)>[
        for (final s in saetze) (s.node['de'] as List, 0, '${s.path}.de[0]'),
        for (final c in clauses)
          for (final (j, _) in (c.node['ausrichtung'] as List).indexed)
            ([c.node['ausrichtung'][j]], -1, '${c.path}.ausrichtung[$j].de'),
        for (final i in items('umformen'))
          (i.node['ziel'] as List, 0, '${i.path}.ziel[0]'),
        for (final i in items('vokabel'))
          (i.node['de'] as List, 0, '${i.path}.de[0]'),
      ];
      final (list, index, path) = pick(sites);
      final bad = pick(['a | b', '(a', 'a)', '(a]', '[a)', ']', 'x (a | b']);
      if (index < 0) {
        list.single['de'] = bad;
      } else {
        list[index] = bad;
      }
      return path;
    case ExamRule.punctuation:
      return from(marks, (t) {
        if (r.nextBool()) {
          t.node['rolle'] = 'objekt';
        } else {
          t.node['la'] = '${t.node['la']}a';
        }
        return t.path;
      });
    case ExamRule.laEmpty:
      final t = pick(tokens);
      t.node['la'] = '';
      return t.path;
    case ExamRule.oneForm:
      final t = pick(tokens);
      t.node['la'] = '${t.node['la']} ${t.node['la']}';
      return t.path;
    case ExamRule.sentenceEnd:
      return from(
        [
          for (final t in marks)
            if (clauseOf[t.node['id']]?.containsKey('uebergeordnet') ?? false)
              t,
        ],
        (t) {
          t.node['la'] = pick(['.', '?', '!']);
          return t.path;
        },
      );
    case ExamRule.rolleNone:
      return from(
        [
          for (final t in words)
            if (const [
              'partikel',
              'konjunktion',
              'subjunktion',
            ].contains(t.node['analyse']['wortart']))
              t,
        ],
        (t) {
          t.node['rolle'] = 'objekt';
          return t.path;
        },
      );
    case ExamRule.verbformMissing:
      final ppps = [
        for (final t in words)
          if (t.node['verbform']?[0] == t.node['id']) t,
      ];
      final verbs = [
        for (final t in words)
          if (t.node['analyse']['wortart'] == 'verb' &&
              !t.node.containsKey('verbform') &&
              !isParticiple(t))
            t,
      ];
      if (ppps.isNotEmpty && (verbs.isEmpty || r.nextBool())) {
        final t = pick(ppps);
        t.node.remove('verbform');
        return t.path;
      }
      return from(verbs, (t) {
        t.node['analyse']['genus_verbi'] = 'pass';
        t.node['analyse']['tempus'] = pick(['perf', 'plusq', 'fut2']);
        return t.path;
      });
    case ExamRule.verbformBoth:
      final byId = {for (final t in words) t.node['id']: t};
      return from(
        [
          for (final t in words)
            if (t.node['verbform']?[0] == t.node['id']) t,
        ],
        (ppp) {
          final pair = [...ppp.node['verbform'] as List];
          final esse = byId[pair[1]]!;
          final thirds = [
            for (final t in words)
              if (t.sid == ppp.sid && !pair.contains(t.node['id'])) t,
          ];
          switch (r.nextInt(7)) {
            case 0:
              esse.node['rolle'] = 'subjekt';
              return '${esse.path}.verbform';
            case 1:
              esse.node.remove('verbform');
            case 2:
              ppp.node['verbform'] = [...pair.reversed];
            case 3 when thirds.isNotEmpty:
              final third = pick(thirds);
              third.node['verbform'] = pair;
              return '${third.path}.verbform';
            case 4:
              ppp.node['verbform'] = [pair[0]];
            case 5:
              for (final t in [ppp, esse]) {
                t.node['verbform'] = [...pair, pick(pair)];
              }
            default:
              for (final t in [ppp, esse]) {
                t.node['verbform'] = [pair[1], pair[1]];
              }
          }
          return '${ppp.path}.verbform';
        },
      );
    case ExamRule.bezugMissing:
      return from(
        [
          for (final t in words)
            if (!isParticiple(t)) t,
        ],
        (t) {
          t.node['rolle'] = 'attribut';
          t.node.remove('bezug');
          return t.path;
        },
      );
    case ExamRule.verbformPair:
      return from(
        [
          for (final t in words)
            if (t.node['verbform']?[0] == t.node['id']) t,
        ],
        (t) {
          switch (r.nextInt(3)) {
            case 0:
              t.node['analyse']['genus_verbi'] = 'akt';
            case 1:
              t.node['lemma'] = 'esse';
            default:
              words
                      .firstWhere((e) => e.node['id'] == t.node['verbform'][1])
                      .node['lemma'] =
                  'ire';
          }
          return '${t.path}.verbform';
        },
      );
    case ExamRule.verbformEsse:
      return from(
        [
          for (final t in words)
            if (t.node['verbform']?[1] == t.node['id']) t,
        ],
        (t) {
          if (r.nextBool()) {
            t.node['analyse']['genus_verbi'] = 'pass';
          } else {
            t.node['analyse'].remove('genus_verbi');
          }
          return '${t.path}.verbform';
        },
      );
    case ExamRule.pppKasusGenus:
      return from(
        [
          for (final t in words)
            if (t.node['analyse']['genus_verbi'] == 'pass' &&
                const [
                  'perf',
                  'plusq',
                  'fut2',
                ].contains(t.node['analyse']['tempus']))
              t,
        ],
        (t) {
          final a = t.node['analyse'];
          for (final key in pick([
            ['kasus'],
            ['genus'],
            ['kasus', 'genus'],
          ])) {
            a.remove(key);
          }
          return t.path;
        },
      );
    case ExamRule.participlePpp:
      return from(participles, (t) {
        final a = t.node['analyse'];
        if (r.nextBool()) {
          a['tempus'] = pick(['praes', 'fut']);
        } else {
          a['genus_verbi'] = 'akt';
        }
        return t.path;
      });
    case ExamRule.bildenForm:
      return from(items('bilden'), (i) {
        i.node['merkmale'] = {
          ...i.node['merkmale'] as Map,
          'tempus': pick(['perf', 'plusq', 'fut2']),
          'modus': pick(['ind', 'konj', 'inf']),
          'genus_verbi': 'pass',
        };
        i.node['form'] = pick(['ductus', 'ductus est iam']);
        return '${i.path}.form';
      });
    case ExamRule.verbformAgree:
      return from(
        [
          for (final t in words)
            if (t.node['verbform']?[1] == t.node['id']) t,
        ],
        (t) {
          final a = t.node['analyse'];
          final finite = a['modus'] != 'inf';
          T other<T>(T value, List<T> all) => pick([
            for (final x in all)
              if (x != value) x,
          ]);
          switch (pick([
            'modus',
            'tempus',
            if (finite && a['numerus'] != null) 'numerus',
            if (finite && a['person'] != null) 'person',
          ])) {
            case 'modus':
              a['modus'] = a['modus'] == 'ind' ? 'konj' : 'ind';
            case 'tempus':
              a['tempus'] = other(a['tempus'], codes('tempus'));
            case 'numerus':
              a['numerus'] = a['numerus'] == 'sg' ? 'pl' : 'sg';
            case 'person':
              a['person'] = other(a['person'], [1, 2, 3]);
          }
          return '${t.path}.verbform';
        },
      );
    case ExamRule.pc:
      return from(pcs, (c) {
        switch (r.nextInt(3)) {
          case 0:
            c.node.remove('sinnrichtung');
          case 1:
            c.node.remove('uebergeordnet');
          default:
            participles
                    .firstWhere((t) => members(c).contains(t.node['id']))
                    .node['analyse']['modus'] =
                'ind';
        }
        return c.path;
      });
    case ExamRule.pcRolle:
      return from(pcs, (c) {
        final p = participles.firstWhere(
          (t) => members(c).contains(t.node['id']),
        );
        p.node['rolle'] = 'objekt';
        return c.path;
      });
    case ExamRule.sinnrichtung:
      return from(clauses.where((c) => c.node['art'] != 'pc').toList(), (c) {
        c.node['sinnrichtung'] = 'kausal';
        return '${c.path}.sinnrichtung';
      });
    case ExamRule.participle:
      return from(participles, (t) {
        switch (r.nextInt(4)) {
          case 0:
            t.node['bezug'] = t.node['id'];
          case 1:
            t.node.remove('bezug');
          case 2:
            t.node['verbform'] = [t.node['id'], t.node['id']];
          default:
            final c = pcs.firstWhere((c) => members(c).contains(t.node['id']));
            c.node['art'] = 'relativ';
            c.node.remove('sinnrichtung');
        }
        return t.path;
      });
    case ExamRule.person:
      return from(
        [
          for (final t in words)
            if (t.node['analyse']['pronomen'] == 'personal' || isParticiple(t))
              t,
        ],
        (t) {
          final a = t.node['analyse'];
          if (isParticiple(t)) {
            a['person'] = 1 + r.nextInt(3);
          } else {
            a.remove('person');
          }
          return t.path;
        },
      );
    case ExamRule.participleKng:
      return from(participles, (t) {
        final a = t.node['analyse'];
        a['kasus'] = a['kasus'] == 'nom' ? 'gen' : 'nom';
        return t.path;
      });
    case ExamRule.merkmal:
      final wordById = {for (final t in words) t.node['id']: t};
      final sites = [
        for (final i in items('bestimmen'))
          for (final m in ['kasus', 'person', 'tempus', 'pronomen', 'funktion'])
            if (!(wordById[i.node['token']]!.node['analyse'] as Map)
                .containsKey(m))
              (i, m),
      ];
      return from(
        sites,
        (s) => '${s.$1.path}.merkmale${add(s.$1.node['merkmale'], s.$2)}',
      );
    case ExamRule.mcRichtig:
      return from(items('wissen_mc'), (i) {
        i.node['richtig'] = 'keine';
        return '${i.path}.richtig';
      });
    case ExamRule.mcSinnrichtung:
      if (pcs.isEmpty) return null;
      return from(items('wissen_mc'), (i) {
        final c = pick(pcs);
        final wrong = pick([
          for (final s in latin.sinnrichtung)
            if (s != c.node['sinnrichtung']) s,
        ]);
        i.node['teilsatz'] = c.node['id'];
        i.node['richtig'] = wrong;
        (i.node['optionen'] as List).add(wrong);
        return '${i.path}.richtig';
      });
    case ExamRule.ordnen:
      return from(
        [
          for (final t in tasks)
            if (t.node['art'] == 'ordnen') t,
        ],
        (t) {
          t.node['elemente'] = (t.node['elemente'] as List).take(2).toList();
          return '${t.path}.elemente';
        },
      );
    case ExamRule.pointsTask:
      return from(
        [
          for (final t in tasks)
            if (t.node.containsKey('items')) t,
        ],
        (t) {
          t.node['items'][0]['punkte'] += 1;
          return '${t.path}.punkte';
        },
      );
    case ExamRule.pointsTotal:
      exam['punkte_gesamt'] += 1;
      return 'exam.punkte_gesamt';
  }
}

/// Writes one optional key that [exam] lacks without a value, which leaves
/// the same pack; returns the key.
String nullOptional(Map<String, dynamic> exam, Random r) {
  const features = [
    'kasus',
    'numerus',
    'genus',
    'person',
    'tempus',
    'modus',
    'genus_verbi',
  ];
  final sites = <String, List<Map>>{};
  void add(Map node, List<String> keys) {
    for (final key in keys) {
      if (!node.containsKey(key)) (sites[key] ??= []).add(node);
    }
  }

  for (final s in exam['uebersetzung']['saetze'] as List) {
    for (final t in s['tokens'] as List) {
      if (!t.containsKey('lemma')) continue;
      add(t, ['rolle', 'bezug', 'verbform']);
      add(t['analyse'], [...features, 'pronomen', 'funktion']);
    }
    for (final c in s['teilsaetze'] as List) {
      add(c, ['uebergeordnet', 'sinnrichtung']);
    }
  }
  for (final t in exam['aufgaben'] as List) {
    for (final i in t['items'] as List? ?? const []) {
      if (t['art'] == 'wissen_mc') add(i, ['teilsatz']);
      if (t['art'] == 'bilden') add(i['merkmale'], features);
    }
  }
  final key = sites.keys.elementAt(r.nextInt(sites.length));
  final nodes = sites[key]!;
  nodes[r.nextInt(nodes.length)][key] = null;
  return key;
}

/// [data] as block-style YAML with one scalar per line; strings are written
/// JSON-quoted, which YAML reads as double-quoted scalars.
String blockYaml(Object data) => _block(data, '').join('\n');

String? _inline(Object? value) => switch (value) {
  String() => jsonEncode(value),
  int() || null => '$value',
  Map(isEmpty: true) => '{}',
  List(isEmpty: true) => '[]',
  _ => null,
};

List<String> _block(Object? data, String indent) {
  List<String> entry(String head, Object? value) => switch (_inline(value)) {
    final s? => ['$indent$head $s'],
    null => ['$indent$head', ..._block(value, '$indent  ')],
  };
  return switch (data) {
    Map() => [for (final e in data.entries) ...entry('${e.key}:', e.value)],
    List() => [for (final v in data) ...entry('-', v)],
    _ => throw ArgumentError.value(data),
  };
}

/// Breaks the YAML syntax of [blockYaml] text: a duplicate key, a line
/// starting with the reserved `@`, or a tab in the indentation. Returns the
/// broken text and the path its error names.
(String, String) breakYaml(String text, Random r) {
  final lines = text.split('\n');
  final scalarKey = RegExp(r'^ *[a-z_]+: .');
  final kind = r.nextInt(3);
  final candidates = [
    for (final (i, l) in lines.indexed)
      if (switch (kind) {
        0 => scalarKey.hasMatch(l),
        1 => true,
        _ => l.startsWith(' '),
      })
        i,
  ];
  final i = candidates[r.nextInt(candidates.length)];
  final indent = RegExp('^ *').stringMatch(lines[i])!;
  switch (kind) {
    case 0:
      lines.insert(i + 1, lines[i]);
      return (lines.join('\n'), 'line ${i + 2}');
    case 1:
      lines.insert(i, '$indent@');
      return (lines.join('\n'), 'line ${i + 1}');
    default:
      lines[i] = '\t${lines[i].substring(indent.length)}';
      return (lines.join('\n'), 'line ${i + 1}');
  }
}
