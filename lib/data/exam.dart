import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'languages/language.dart';

/// The rules of lib/data/EXAM_SCHEMA.md, by the id an [ExamError] names.
enum ExamRule {
  yaml('E-yaml'),
  schema('E-schema'),
  field('E-field'),
  key('E-key'),
  type('E-type'),
  code('E-code'),
  empty('E-empty'),
  idShape('E-id-shape'),
  idTwice('E-id-twice'),
  refClauseToken('E-ref-clause-token'),
  refAlignment('E-ref-alignment'),
  refHilfe('E-ref-hilfe'),
  refBezug('E-ref-bezug'),
  refVerbform('E-ref-verbform'),
  refUebergeordnet('E-ref-uebergeordnet'),
  uebergeordnet('E-uebergeordnet'),
  refItemToken('E-ref-item-token'),
  refItemTeilsatz('E-ref-item-teilsatz'),
  tokenTwice('E-token-twice'),
  tokenNoClause('E-token-no-clause'),
  alignment('E-alignment'),
  hilfeLemma('E-hilfe-lemma'),
  hilfeTokens('E-hilfe-tokens'),
  variant('E-variant'),
  punctuation('E-punctuation'),
  laEmpty('E-la-empty'),
  oneForm('E-one-form'),
  sentenceEnd('E-sentence-end'),
  rolleNone('E-rolle-none'),
  bezugMissing('E-bezug-missing'),
  person('E-person'),
  verbformMissing('E-verbform-missing'),
  verbformBoth('E-verbform-both'),
  verbformPair('E-verbform-pair'),
  verbformEsse('E-verbform-esse'),
  verbformAgree('E-verbform-agree'),
  pc('E-pc'),
  pcRolle('E-pc-rolle'),
  sinnrichtung('E-sinnrichtung'),
  participle('E-participle'),
  participleKng('E-participle-kng'),
  participlePpp('E-participle-ppp'),
  pppKasusGenus('E-ppp-kasus-genus'),
  bildenForm('E-bilden-form'),
  merkmal('E-merkmal'),
  mcRichtig('E-mc-richtig'),
  mcSinnrichtung('E-mc-sinnrichtung'),
  ordnen('E-ordnen'),
  pointsTask('E-points-task'),
  pointsTotal('E-points-total');

  final String id;
  const ExamRule(this.id);
}

final class ExamError {
  final ExamRule rule;

  /// Where the rule breaks, e.g. `exam.uebersetzung.saetze[3].teilsaetze[1]`.
  final String path;
  final String detail;
  const ExamError(this.rule, this.path, this.detail);

  @override
  String toString() => '${rule.id} $path: $detail';
}

/// A pack that breaks a rule; nothing of it is usable.
final class ExamRejected implements Exception {
  final List<ExamError> errors;
  ExamRejected(this.errors) : assert(errors.isNotEmpty);

  @override
  String toString() => 'ExamRejected:\n${errors.join('\n')}';
}

extension ExamCode on Enum {
  /// The code a `.exam` file writes: the name in snake case.
  String get code =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}

/// The `analyse` of a word token: a code per key of the language, in the
/// language's order.
final class Analyse {
  final Codes codes;
  const Analyse(this.codes);
}

sealed class ExamToken {
  final String id;
  final String la;
  const ExamToken(this.id, this.la);
}

/// A punctuation mark: no lemma, no letters.
final class PunctuationToken extends ExamToken {
  const PunctuationToken(super.id, super.la);
}

final class WordToken extends ExamToken {
  final String lemma;
  final Analyse analyse;
  final String? rolle;
  final String? bezug;

  /// The PPP and the `esse` token of a compound passive form.
  final List<String>? verbform;

  const WordToken(
    super.id,
    super.la,
    this.lemma,
    this.analyse, {
    this.rolle,
    this.bezug,
    this.verbform,
  });
}

final class Alignment {
  final List<String> tokens;
  final String de;
  const Alignment(this.tokens, this.de);
}

final class Clause {
  final String id;
  final String art;
  final List<String> tokens;
  final String? uebergeordnet;
  final String? sinnrichtung;
  final List<String> de;
  final List<Alignment> ausrichtung;

  const Clause({
    required this.id,
    required this.art,
    required this.tokens,
    this.uebergeordnet,
    this.sinnrichtung,
    required this.de,
    required this.ausrichtung,
  });
}

final class ExamSentence {
  final String id;
  final List<ExamToken> tokens;
  final List<Clause> teilsaetze;
  final List<String> de;
  const ExamSentence(this.id, this.tokens, this.teilsaetze, this.de);
}

final class Hilfe {
  final String lemma;
  final String angabe;
  final String de;
  final List<String> tokens;
  const Hilfe(this.lemma, this.angabe, this.de, this.tokens);
}

enum ItemArt {
  bestimmen,
  stammformen,
  bilden,
  umformen,
  vokabel,
  ableitung,
  kurzantwort,
  wissenMc,
}

sealed class TaskItem {
  final int punkte;
  const TaskItem(this.punkte);
}

final class BestimmenItem extends TaskItem {
  final String token;

  /// Feature names of the token's analysis, `lemma` or `bezug`.
  final List<String> merkmale;
  const BestimmenItem(this.token, this.merkmale, super.punkte);
}

final class StammformenItem extends TaskItem {
  final String lemma;
  final List<String> stammformen;
  const StammformenItem(this.lemma, this.stammformen, super.punkte);
}

final class BildenItem extends TaskItem {
  final String lemma;
  final Codes merkmale;
  final String form;
  const BildenItem(this.lemma, this.merkmale, this.form, super.punkte);
}

final class UmformenItem extends TaskItem {
  final String vorgabe;
  final List<String> ziel;
  const UmformenItem(this.vorgabe, this.ziel, super.punkte);
}

final class VokabelItem extends TaskItem {
  final String la;
  final List<String> de;
  const VokabelItem(this.la, this.de, super.punkte);
}

final class AbleitungItem extends TaskItem {
  final String fremdwort;
  final String la;
  const AbleitungItem(this.fremdwort, this.la, super.punkte);
}

final class KurzantwortItem extends TaskItem {
  final String frage;

  /// Each inner list holds equivalent words; one of each must occur.
  final List<List<String>> stichwoerter;
  const KurzantwortItem(this.frage, this.stichwoerter, super.punkte);
}

final class WissenMcItem extends TaskItem {
  final String frage;
  final List<String> optionen;
  final String richtig;

  /// A pc clause whose sinnrichtung is [richtig].
  final String? teilsatz;
  const WissenMcItem(
    this.frage,
    this.optionen,
    this.richtig,
    this.teilsatz,
    super.punkte,
  );
}

sealed class ExamTask {
  final String id;
  final String titel;
  final int punkte;
  final String frage;

  /// Lines of the PDF solution.
  final List<String> loesung;
  const ExamTask(this.id, this.titel, this.punkte, this.frage, this.loesung);
}

/// A task of [art] whose items are all of the item class of [art].
final class ItemTask extends ExamTask {
  final ItemArt art;
  final List<TaskItem> items;
  const ItemTask(
    super.id,
    super.titel,
    super.punkte,
    super.frage,
    super.loesung,
    this.art,
    this.items,
  );
}

/// [elemente] in the right order.
final class OrdnenTask extends ExamTask {
  final List<String> elemente;
  const OrdnenTask(
    super.id,
    super.titel,
    super.punkte,
    super.frage,
    super.loesung,
    this.elemente,
  );
}

/// A task the student checks against [loesung] alone.
final class FreiTask extends ExamTask {
  const FreiTask(
    super.id,
    super.titel,
    super.punkte,
    super.frage,
    super.loesung,
  );
}

final class Exam {
  final String id;
  final String titel;
  final int von;
  final int bis;
  final List<String> schwerpunkte;
  final String schwerpunkt;
  final String thema;
  final int zeitMin;
  final int punkteUebersetzung;
  final int punkteGesamt;
  final List<Hilfe> hilfen;
  final List<ExamSentence> saetze;
  final List<ExamTask> aufgaben;

  const Exam({
    required this.id,
    required this.titel,
    required this.von,
    required this.bis,
    required this.schwerpunkte,
    required this.schwerpunkt,
    required this.thema,
    required this.zeitMin,
    required this.punkteUebersetzung,
    required this.punkteGesamt,
    required this.hilfen,
    required this.saetze,
    required this.aufgaben,
  });
}

/// Parses a `.exam` pack and checks every rule of EXAM_SCHEMA.md with the
/// codes and rule parameters of [language]; throws [ExamRejected] when the
/// pack breaks one.
Exam parseExam(String source, Language language) {
  final Object? yaml;
  try {
    yaml = loadYaml(source);
  } on YamlException catch (e) {
    throw ExamRejected([
      ExamError(ExamRule.yaml, 'line ${e.span!.start.line + 1}', e.message),
    ]);
  }
  final Exam exam;
  try {
    exam = _whole(_Map(yaml, 'exam', language), _exam);
  } on ExamError catch (e) {
    throw ExamRejected([e]);
  }
  final errors = _Checker(exam, language).run();
  if (errors.isNotEmpty) throw ExamRejected(errors);
  return exam;
}

/// The pack as YAML text that [parseExam] reads back to the same pack.
/// The text is JSON, which is YAML.
String serializeExam(Exam exam) =>
    const JsonEncoder.withIndent('  ').convert(examToYaml(exam));

/// The pack as the plain YAML data model: maps, lists, strings and ints.
Map<String, Object> examToYaml(Exam e) => {
  'schema': 1,
  'id': e.id,
  'titel': e.titel,
  'lektionen': {'von': e.von, 'bis': e.bis},
  'schwerpunkte': e.schwerpunkte,
  'schwerpunkt': e.schwerpunkt,
  'thema': e.thema,
  'zeit_min': e.zeitMin,
  'punkte_uebersetzung': e.punkteUebersetzung,
  'punkte_gesamt': e.punkteGesamt,
  'uebersetzung': {
    'hilfen': [
      for (final h in e.hilfen)
        {'lemma': h.lemma, 'angabe': h.angabe, 'de': h.de, 'tokens': h.tokens},
    ],
    'saetze': [for (final s in e.saetze) _sentenceToYaml(s)],
  },
  'aufgaben': [for (final t in e.aufgaben) _taskToYaml(t)],
};

Map<String, Object> _sentenceToYaml(ExamSentence s) => {
  'id': s.id,
  'tokens': [
    for (final t in s.tokens)
      switch (t) {
        PunctuationToken() => {'id': t.id, 'la': t.la},
        WordToken() => {
          'id': t.id,
          'la': t.la,
          'lemma': t.lemma,
          'analyse': t.analyse.codes,
          'rolle': ?t.rolle,
          'bezug': ?t.bezug,
          'verbform': ?t.verbform,
        },
      },
  ],
  'teilsaetze': [
    for (final c in s.teilsaetze)
      {
        'id': c.id,
        'art': c.art,
        'tokens': c.tokens,
        'uebergeordnet': ?c.uebergeordnet,
        'sinnrichtung': ?c.sinnrichtung,
        'de': c.de,
        'ausrichtung': [
          for (final a in c.ausrichtung) {'tokens': a.tokens, 'de': a.de},
        ],
      },
  ],
  'de': s.de,
};

Map<String, Object> _taskToYaml(ExamTask t) => {
  'id': t.id,
  'titel': t.titel,
  'punkte': t.punkte,
  'art': switch (t) {
    ItemTask() => t.art.code,
    OrdnenTask() => 'ordnen',
    FreiTask() => 'frei',
  },
  'frage': t.frage,
  if (t is ItemTask) 'items': [for (final i in t.items) _itemToYaml(i)],
  if (t is OrdnenTask) 'elemente': t.elemente,
  'loesung': t.loesung,
};

Map<String, Object> _itemToYaml(TaskItem i) => {
  ...switch (i) {
    BestimmenItem() => {'token': i.token, 'merkmale': i.merkmale},
    StammformenItem() => {'lemma': i.lemma, 'stammformen': i.stammformen},
    BildenItem() => {'lemma': i.lemma, 'merkmale': i.merkmale, 'form': i.form},
    UmformenItem() => {'vorgabe': i.vorgabe, 'ziel': i.ziel},
    VokabelItem() => {'la': i.la, 'de': i.de},
    AbleitungItem() => {'fremdwort': i.fremdwort, 'la': i.la},
    KurzantwortItem() => {'frage': i.frage, 'stichwoerter': i.stichwoerter},
    WissenMcItem() => {
      'frage': i.frage,
      'teilsatz': ?i.teilsatz,
      'optionen': i.optionen,
      'richtig': i.richtig,
    },
  },
  'punkte': i.punkte,
};

/// The readings of a variant string: `(a | b)` is a choice, `[x]` is
/// optional, groups nest, and `|` stands only inside a group. Throws a
/// [FormatException] on bad syntax.
List<String> expand(String variant) {
  final (readings, end) = _sequence(variant, 0, null);
  assert(end == variant.length);
  return [for (final r in readings) _normalize(r)];
}

/// Whether [answer] is one of the readings of [variant].
bool variantAccepts(String variant, String answer) =>
    expand(variant).contains(_normalize(answer));

String _normalize(String s) => s
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r' (?=[,.;:!?“])'), '')
    .replaceAll('„ ', '„')
    .trim();

(List<String>, int) _sequence(String s, int start, String? close) {
  final done = <String>[];
  var current = [''];
  var i = start;
  while (i < s.length) {
    final c = s[i];
    if (c == '(' || c == '[') {
      final (inner, next) = _sequence(s, i + 1, c == '(' ? ')' : ']');
      final options = c == '[' ? [...inner, ''] : inner;
      current = [
        for (final a in current)
          for (final b in options) a + b,
      ];
      i = next;
      continue;
    }
    if (c == ')' || c == ']') {
      if (c != close) throw FormatException('unexpected "$c"', s, i);
      return ([...done, ...current], i + 1);
    }
    if (c == '|') {
      if (close == null) throw FormatException('"|" outside a group', s, i);
      done.addAll(current);
      current = [''];
    } else {
      current = [for (final a in current) a + c];
    }
    i++;
  }
  if (close != null) throw FormatException('missing "$close"', s, i);
  return ([...done, ...current], i);
}

/// A YAML map of the pack at [path]; [_whole] refuses the keys that its
/// builder did not read.
final class _Map {
  final YamlMap _map;
  final String path;
  final Language language;
  final _read = <String>{};

  _Map(Object? node, this.path, this.language)
    : _map = _cast<YamlMap>(node, path);

  bool has(String key) => _map.containsKey(key);

  T req<T>(String key) {
    if (!_map.containsKey(key)) {
      throw ExamError(ExamRule.field, path, '"$key" is missing');
    }
    return opt<T>(key) ??
        (throw ExamError(ExamRule.field, '$path.$key', 'has no value'));
  }

  /// A field without a value counts as absent.
  T? opt<T>(String key) {
    _read.add(key);
    final value = _map[key];
    return value == null ? null : _cast<T>(value, '$path.$key');
  }

  T map<T>(String key, T Function(_Map) build) =>
      _whole(_Map(req<YamlMap>(key), '$path.$key', language), build);

  List<T> maps<T>(String key, T Function(_Map) build) => [
    for (final (i, m) in req<YamlList>(key).indexed)
      _whole(_Map(m, '$path.$key[$i]', language), build),
  ];

  List<T> list<T>(String key) => [
    for (final (i, v) in req<YamlList>(key).indexed)
      _cast<T>(v, '$path.$key[$i]'),
  ];

  List<T> nonEmpty<T>(String key) {
    final values = list<T>(key);
    if (values.isEmpty) {
      throw ExamError(ExamRule.empty, '$path.$key', 'the list is empty');
    }
    return values;
  }

  Object code(String key, List<Object> codes) =>
      optCode(key, codes) ?? req<Object>(key);

  /// A value of the type of [codes] that is one of them.
  Object? optCode(String key, List<Object> codes) {
    final Object? value = codes.firstOrNull is int
        ? opt<int>(key)
        : opt<String>(key);
    if (value != null && !codes.contains(value)) {
      throw ExamError(
        ExamRule.code,
        '$path.$key',
        '$value is not one of $codes',
      );
    }
    return value;
  }
}

T _whole<T>(_Map m, T Function(_Map) build) {
  final value = build(m);
  for (final key in m._map.keys) {
    if (!m._read.contains(key)) {
      throw ExamError(ExamRule.key, '${m.path}.$key', 'unknown field');
    }
  }
  return value;
}

T _cast<T>(Object? value, String path) {
  if (value is! T) {
    throw ExamError(ExamRule.type, path, '${value.runtimeType} is not $T');
  }
  return value;
}

Exam _exam(_Map m) {
  if (m.req<Object>('schema') != 1) {
    throw ExamError(ExamRule.schema, '${m.path}.schema', 'schema is not 1');
  }
  final (von, bis) = m.map(
    'lektionen',
    (l) => (l.req<int>('von'), l.req<int>('bis')),
  );
  final (hilfen, saetze) = m.map(
    'uebersetzung',
    (u) => (u.maps('hilfen', _hilfe), u.maps('saetze', _sentence)),
  );
  return Exam(
    id: m.req('id'),
    titel: m.req('titel'),
    von: von,
    bis: bis,
    schwerpunkte: m.list('schwerpunkte'),
    schwerpunkt: m.req('schwerpunkt'),
    thema: m.req('thema'),
    zeitMin: m.req('zeit_min'),
    punkteUebersetzung: m.req('punkte_uebersetzung'),
    punkteGesamt: m.req('punkte_gesamt'),
    hilfen: hilfen,
    saetze: saetze,
    aufgaben: m.maps('aufgaben', _task),
  );
}

Hilfe _hilfe(_Map m) =>
    Hilfe(m.req('lemma'), m.req('angabe'), m.req('de'), m.list('tokens'));

ExamSentence _sentence(_Map m) => ExamSentence(
  m.req('id'),
  m.maps('tokens', _token),
  m.maps('teilsaetze', _clause),
  m.nonEmpty('de'),
);

final _letterOrDigit = RegExp(r'[\p{L}\p{N}_]', unicode: true);

ExamToken _token(_Map m) {
  final String id = m.req('id');
  final String la = m.req('la');
  if (!m.has('lemma')) {
    if (m._map.length != 2 || _letterOrDigit.hasMatch(la)) {
      throw ExamError(
        ExamRule.punctuation,
        m.path,
        'a token without lemma has only id and la, and no letters',
      );
    }
    return PunctuationToken(id, la);
  }
  return WordToken(
    id,
    la,
    m.req('lemma'),
    m.map('analyse', _analyse),
    rolle: m.optCode('rolle', m.language.rolle) as String?,
    bezug: m.opt('bezug'),
    verbform: m.opt<YamlList>('verbform') == null ? null : m.list('verbform'),
  );
}

Analyse _analyse(_Map m) {
  final language = m.language;
  return Analyse({
    for (final MapEntry(:key, :value) in language.analyse.entries)
      key: ?(key == language.wordClass
          ? m.code(key, value)
          : m.optCode(key, value)),
  });
}

Codes _features(_Map m) => {
  for (final key in m.language.form)
    key: ?m.optCode(key, m.language.analyse[key]!),
};

Clause _clause(_Map m) => Clause(
  id: m.req('id'),
  art: m.code('art', m.language.clauseArt) as String,
  tokens: m.list('tokens'),
  uebergeordnet: m.opt('uebergeordnet'),
  sinnrichtung: m.optCode('sinnrichtung', m.language.sinnrichtung) as String?,
  de: m.list('de'),
  ausrichtung: m.maps(
    'ausrichtung',
    (a) => Alignment(a.list('tokens'), a.req('de')),
  ),
);

ExamTask _task(_Map m) {
  final String id = m.req('id');
  final String titel = m.req('titel');
  final int punkte = m.req('punkte');
  final String frage = m.req('frage');
  final List<String> loesung = m.list('loesung');
  final String art = m.req('art');
  if (art == 'ordnen') {
    return OrdnenTask(id, titel, punkte, frage, loesung, m.list('elemente'));
  }
  if (art == 'frei') return FreiTask(id, titel, punkte, frage, loesung);
  final itemArt =
      ItemArt.values.where((a) => a.code == art).firstOrNull ??
      (throw ExamError(
        ExamRule.code,
        '${m.path}.art',
        '$art is not one of ${ItemArt.values}',
      ));
  final items = m.maps('items', (i) => _item(i, itemArt));
  if (items.isEmpty) {
    throw ExamError(ExamRule.empty, '${m.path}.items', 'the list is empty');
  }
  return ItemTask(id, titel, punkte, frage, loesung, itemArt, items);
}

TaskItem _item(_Map m, ItemArt art) {
  final int punkte = m.req('punkte');
  return switch (art) {
    ItemArt.bestimmen => BestimmenItem(
      m.req('token'),
      m.list('merkmale'),
      punkte,
    ),
    ItemArt.stammformen => StammformenItem(
      m.req('lemma'),
      _stammformen(m),
      punkte,
    ),
    ItemArt.bilden => BildenItem(
      m.req('lemma'),
      m.map('merkmale', _features),
      m.req('form'),
      punkte,
    ),
    ItemArt.umformen => UmformenItem(
      m.req('vorgabe'),
      m.nonEmpty('ziel'),
      punkte,
    ),
    ItemArt.vokabel => VokabelItem(m.req('la'), m.nonEmpty('de'), punkte),
    ItemArt.ableitung => AbleitungItem(m.req('fremdwort'), m.req('la'), punkte),
    ItemArt.kurzantwort => KurzantwortItem(
      m.req('frage'),
      _stichwoerter(m),
      punkte,
    ),
    ItemArt.wissenMc => WissenMcItem(
      m.req('frage'),
      m.nonEmpty('optionen'),
      m.req('richtig'),
      m.opt('teilsatz'),
      punkte,
    ),
  };
}

List<String> _stammformen(_Map m) {
  final forms = m.list<String>('stammformen');
  if (forms.length != 4) {
    throw ExamError(ExamRule.type, '${m.path}.stammformen', 'not 4 forms');
  }
  return forms;
}

List<List<String>> _stichwoerter(_Map m) => [
  for (final (i, group) in m.nonEmpty<YamlList>('stichwoerter').indexed)
    if (group.isEmpty)
      throw ExamError(ExamRule.empty, '${m.path}.stichwoerter[$i]', 'empty')
    else
      [
        for (final (j, w) in group.indexed)
          _cast<String>(w, '${m.path}.stichwoerter[$i][$j]'),
      ],
];

final _sentenceId = RegExp(r'^s\d+$');
final _taskId = RegExp(r'^[a-z]\d+$');

final _space = RegExp(r'\s');
const _sentenceEnds = {'.', '?', '!'};
final _word = RegExp(r'\S+');

final class _Checker {
  final Exam exam;
  final ExamRules rules;
  final String wordClass;
  final errors = <ExamError>[];
  final tokens = <String, ExamToken>{};
  final clauseOf = <String, Clause>{};
  final clauses = <String, Clause>{};

  _Checker(this.exam, Language language)
    : rules = language.rules,
      wordClass = language.wordClass {
    for (final s in exam.saetze) {
      for (final t in s.tokens) {
        tokens[t.id] = t;
      }
      for (final c in s.teilsaetze) {
        clauses[c.id] = c;
        for (final t in c.tokens) {
          clauseOf[t] = c;
        }
      }
    }
  }

  void error(ExamRule rule, String path, String detail) =>
      errors.add(ExamError(rule, path, detail));

  bool isParticiple(Codes f) =>
      rules.participle != null && matches(f, rules.participle!.isA);

  /// A compound form: a perfect passive that is not a participle.
  bool isCompound(Codes f) =>
      rules.compound != null &&
      rules.compound!.perfectPassive(f) &&
      !isParticiple(f);

  void variant(String s, String path) {
    try {
      expand(s);
    } on FormatException catch (e) {
      error(ExamRule.variant, path, e.message);
    }
  }

  List<ExamError> run() {
    ids();
    for (final (i, h) in exam.hilfen.indexed) {
      hilfe(h, 'exam.uebersetzung.hilfen[$i]');
    }
    for (final (i, s) in exam.saetze.indexed) {
      sentence(s, 'exam.uebersetzung.saetze[$i]');
    }
    var total = exam.punkteUebersetzung;
    for (final (i, t) in exam.aufgaben.indexed) {
      total += t.punkte;
      task(t, 'exam.aufgaben[$i]');
    }
    if (total != exam.punkteGesamt) {
      error(
        ExamRule.pointsTotal,
        'exam.punkte_gesamt',
        'the parts sum to $total, not ${exam.punkteGesamt}',
      );
    }
    return errors;
  }

  void ids() {
    final seen = <String>{};
    void id(String id, RegExp shape, String path) {
      if (!shape.hasMatch(id)) {
        error(ExamRule.idShape, '$path.id', '"$id" does not match $shape');
      }
      if (!seen.add(id)) error(ExamRule.idTwice, '$path.id', '"$id" is twice');
    }

    for (final (i, s) in exam.saetze.indexed) {
      final path = 'exam.uebersetzung.saetze[$i]';
      id(s.id, _sentenceId, path);
      final sid = RegExp.escape(s.id);
      for (final (j, t) in s.tokens.indexed) {
        id(t.id, RegExp('^${sid}_\\d+\$'), '$path.tokens[$j]');
      }
      for (final (j, c) in s.teilsaetze.indexed) {
        id(c.id, RegExp('^$sid[a-z]\$'), '$path.teilsaetze[$j]');
      }
    }
    for (final (i, t) in exam.aufgaben.indexed) {
      id(t.id, _taskId, 'exam.aufgaben[$i]');
    }
  }

  void hilfe(Hilfe h, String path) {
    for (final (j, id) in h.tokens.indexed) {
      final t = tokens[id];
      if (t == null) {
        error(ExamRule.refHilfe, '$path.tokens[$j]', 'no token "$id"');
      } else if (t is! WordToken || t.lemma != h.lemma) {
        error(
          ExamRule.hilfeLemma,
          '$path.tokens[$j]',
          '"$id" has another lemma',
        );
      }
    }
    final want = {
      for (final t in tokens.values)
        if (t is WordToken && t.lemma == h.lemma) t.id,
    };
    if (want.length != h.tokens.toSet().length || !want.containsAll(h.tokens)) {
      error(
        ExamRule.hilfeTokens,
        '$path.tokens',
        'not every token of the lemma',
      );
    }
  }

  void sentence(ExamSentence s, String path) {
    final own = {for (final t in s.tokens) t.id};
    final ownClauses = {for (final c in s.teilsaetze) c.id};
    final seen = <String, int>{};
    for (final (k, c) in s.teilsaetze.indexed) {
      final cpath = '$path.teilsaetze[$k]';
      clause(c, cpath, ownClauses);
      for (final (j, id) in c.tokens.indexed) {
        if (!own.contains(id)) {
          error(
            ExamRule.refClauseToken,
            '$cpath.tokens[$j]',
            'no token "$id" in the sentence',
          );
        }
        seen[id] = (seen[id] ?? 0) + 1;
        if (seen[id] == 2) {
          error(ExamRule.tokenTwice, cpath, '"$id" lies in a second clause');
        }
      }
    }
    for (final (j, t) in s.tokens.indexed) {
      if (!seen.containsKey(t.id)) {
        error(ExamRule.tokenNoClause, '$path.tokens[$j]', 'in no clause');
      }
      final tpath = '$path.tokens[$j]';
      if (t.la.isEmpty) error(ExamRule.laEmpty, tpath, 'la is empty');
      if (_space.hasMatch(t.la)) {
        error(ExamRule.oneForm, tpath, 'la holds more than one form');
      }
      if (_sentenceEnds.contains(t.la) &&
          clauseOf[t.id]?.uebergeordnet != null) {
        error(
          ExamRule.sentenceEnd,
          tpath,
          'a sentence end in a subordinate clause',
        );
      }
      if (t is WordToken) token(t, tpath, own);
    }
    for (final (j, v) in s.de.indexed) {
      variant(v, '$path.de[$j]');
    }
  }

  void clause(Clause c, String path, Set<String> siblings) {
    if (rules.participle case final p? when c.art == p.clause) {
      final participles = [
        for (final id in c.tokens)
          if (tokens[id] case WordToken t when isParticiple(t.analyse.codes)) t,
      ];
      if (c.sinnrichtung == null ||
          c.uebergeordnet == null ||
          participles.length != 1) {
        error(
          ExamRule.pc,
          path,
          'needs sinnrichtung, uebergeordnet and one participle',
        );
      } else if (participles.single.rolle !=
          (p.rolleBySinnrichtung[c.sinnrichtung] ?? p.otherRolle)) {
        error(
          ExamRule.pcRolle,
          path,
          'the participle role does not fit the sinnrichtung',
        );
      }
    } else if (c.sinnrichtung != null) {
      error(
        ExamRule.sinnrichtung,
        '$path.sinnrichtung',
        'only a pc clause has one',
      );
    }
    if (c.uebergeordnet case final u? when !siblings.contains(u)) {
      error(
        ExamRule.refUebergeordnet,
        '$path.uebergeordnet',
        'no clause "$u" in the sentence',
      );
    }
    if (c.art != rules.mainClause && c.uebergeordnet == null) {
      error(ExamRule.uebergeordnet, path, 'a subordinate clause needs one');
    }
    for (final (j, v) in c.de.indexed) {
      variant(v, '$path.de[$j]');
    }
    final aligned = <String>[];
    for (final (j, a) in c.ausrichtung.indexed) {
      variant(a.de, '$path.ausrichtung[$j].de');
      for (final (n, id) in a.tokens.indexed) {
        if (!c.tokens.contains(id)) {
          error(
            ExamRule.refAlignment,
            '$path.ausrichtung[$j].tokens[$n]',
            '"$id" is outside the clause',
          );
        }
        aligned.add(id);
      }
    }
    final want = [
      for (final id in c.tokens)
        if (tokens[id] is WordToken) id,
    ];
    if (!_sameMultiset(aligned, want)) {
      error(
        ExamRule.alignment,
        '$path.ausrichtung',
        'does not cover each word once',
      );
    }
  }

  void token(WordToken t, String path, Set<String> own) {
    if (t.bezug case final b? when !own.contains(b)) {
      error(ExamRule.refBezug, '$path.bezug', 'no token "$b" in the sentence');
    }
    for (final (j, id) in (t.verbform ?? const <String>[]).indexed) {
      if (!own.contains(id)) {
        error(
          ExamRule.refVerbform,
          '$path.verbform[$j]',
          'no token "$id" in the sentence',
        );
      }
    }
    final f = t.analyse.codes;
    final withRolle = {...f, 'rolle': ?t.rolle};
    if (rules.needsBezug.any((want) => matches(withRolle, want)) &&
        t.bezug == null) {
      error(
        ExamRule.bezugMissing,
        path,
        'an attribute, praedikativum or relative pronoun needs bezug',
      );
    }
    if (rules.noRole.contains(f[wordClass]) && t.rolle != null) {
      error(ExamRule.rolleNone, path, '${f[wordClass]} has no rolle');
    }
    if (rules.compound case final c?) {
      if (matches(f, c.verb) && isCompound(f) && t.verbform == null) {
        error(
          ExamRule.verbformMissing,
          path,
          'a compound passive needs verbform',
        );
      }
      if (c.perfectPassive(f) && !c.marks.every(f.containsKey)) {
        error(ExamRule.pppKasusGenus, path, 'a PPP has kasus and genus');
      }
    }
    if (rules.person case final p?
        when matches(f, p.neededBy) && !f.containsKey(p.key) ||
            isParticiple(f) && f.containsKey(p.key)) {
      error(
        ExamRule.person,
        path,
        'a personal pronoun has person, a participle has none',
      );
    }
    if ((rules.compound, t.verbform) case (
      final c?,
      final pair?,
    ) when pair.every(own.contains)) {
      verbform(c, t, pair, '$path.verbform');
    }
    if (rules.participle case final p? when isParticiple(f)) {
      participle(p, t, path);
    }
  }

  void verbform(CompoundRule c, WordToken t, List<String> pair, String path) {
    final members = [for (final id in pair) tokens[id]!];
    if (pair.length != 2 ||
        !pair.contains(t.id) ||
        members.any(
          (m) =>
              m is! WordToken ||
              m.rolle != c.rolle ||
              !_sameList(m.verbform, pair),
        )) {
      error(
        ExamRule.verbformBoth,
        path,
        'not the same pair in both tokens, both praedikat',
      );
      return;
    }
    final [ppp as WordToken, aux as WordToken] = members;
    if (aux.lemma != c.aux ||
        ppp.lemma == c.aux ||
        !matches(ppp.analyse.codes, c.passive)) {
      error(ExamRule.verbformPair, path, 'not a PPP and an esse token');
      return;
    }
    final p = ppp.analyse.codes;
    final e = aux.analyse.codes;
    if (!matches(e, c.auxForm)) {
      error(ExamRule.verbformEsse, path, 'the esse token is not active');
    }
    final agrees = matches(p, c.infinitive)
        ? matches(e, c.infinitiveAux)
        : e[c.tense] == c.tenseMap[p[c.tense]] &&
              c.agrees.every((key) => e[key] == p[key]);
    if (!agrees) {
      error(ExamRule.verbformAgree, path, 'the PPP and esse do not agree');
    }
  }

  void participle(ParticipleRule rule, WordToken t, String path) {
    final p = t.analyse.codes;
    if (!matches(p, rule.form)) {
      error(ExamRule.participlePpp, path, 'a participle is perf pass');
    }
    final c = clauseOf[t.id];
    if (c == null) return;
    final b = tokens[t.bezug];
    if (t.verbform != null ||
        b == null ||
        c.art != rule.clause ||
        c.tokens.contains(b.id)) {
      error(
        ExamRule.participle,
        path,
        'needs a bezug outside its pc clause and no verbform',
      );
      return;
    }
    final f = b is WordToken ? b.analyse.codes : const <String, Object>{};
    if (rule.agrees.any((key) => p[key] != f[key])) {
      error(ExamRule.participleKng, path, 'KNG differs from its bezug');
    }
  }

  void task(ExamTask t, String path) {
    switch (t) {
      case OrdnenTask(:final elemente) when elemente.length < 3:
        error(ExamRule.ordnen, '$path.elemente', 'fewer than 3 elements');
      case OrdnenTask() || FreiTask():
        break;
      case ItemTask(:final items):
        final sum = items.fold(0, (s, i) => s + i.punkte);
        if (sum != t.punkte) {
          error(
            ExamRule.pointsTask,
            '$path.punkte',
            'the items sum to $sum, not ${t.punkte}',
          );
        }
        for (final (j, i) in items.indexed) {
          item(i, '$path.items[$j]');
        }
    }
  }

  void item(TaskItem i, String path) {
    switch (i) {
      case BestimmenItem(:final token, :final merkmale):
        final t = tokens[token];
        if (t == null) {
          error(ExamRule.refItemToken, '$path.token', 'no token "$token"');
          return;
        }
        for (final (j, m) in merkmale.indexed) {
          final annotated =
              t is WordToken &&
              (m == 'lemma' ||
                  (m == 'bezug'
                      ? t.bezug != null
                      : t.analyse.codes.containsKey(m)));
          if (!annotated) {
            error(
              ExamRule.merkmal,
              '$path.merkmale[$j]',
              '"$m" is not annotated',
            );
          }
        }
      case WissenMcItem(:final optionen, :final richtig, :final teilsatz):
        if (!optionen.contains(richtig)) {
          error(ExamRule.mcRichtig, '$path.richtig', 'not one of the optionen');
        }
        if (teilsatz != null) {
          final c = clauses[teilsatz];
          if (c == null) {
            error(
              ExamRule.refItemTeilsatz,
              '$path.teilsatz',
              'no clause "$teilsatz"',
            );
          } else if (c.sinnrichtung != richtig) {
            error(
              ExamRule.mcSinnrichtung,
              '$path.richtig',
              'not the sinnrichtung of $teilsatz',
            );
          }
        }
      case UmformenItem(:final ziel):
        for (final (j, v) in ziel.indexed) {
          variant(v, '$path.ziel[$j]');
        }
      case VokabelItem(:final de):
        for (final (j, v) in de.indexed) {
          variant(v, '$path.de[$j]');
        }
      case BildenItem(:final merkmale, :final form):
        if (isCompound(merkmale) && _word.allMatches(form).length != 2) {
          error(
            ExamRule.bildenForm,
            '$path.form',
            'a compound passive is two words',
          );
        }
      case StammformenItem() || AbleitungItem() || KurzantwortItem():
        break;
    }
  }
}

bool _sameList(List<String>? a, List<String> b) =>
    a != null &&
    a.length == b.length &&
    a.indexed.every((e) => b[e.$1] == e.$2);

bool _sameMultiset(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  for (var i = 0; i < sa.length; i++) {
    if (sa[i] != sb[i]) return false;
  }
  return true;
}
