import 'exam.dart' show ExamError, ExamRejected, ExamRule;

typedef _Names = Map<String, String>;

const _head = {
  'schema': 'schema',
  'id': 'id',
  'kurs': 'course',
  'titel': 'title',
  'lektionen': 'lessons',
  'schwerpunkte': 'topics',
  'schwerpunkt': 'focus',
  'thema': 'theme',
  'zeit_min': 'time_min',
  'punkte_uebersetzung': 'points_translation',
  'punkte_gesamt': 'points_total',
  'uebersetzung': 'translation',
  'aufgaben': 'tasks',
};
const _lessons = {'von': 'from', 'bis': 'to'};
const _translation = {'hilfen': 'glosses', 'saetze': 'sentences'};
const _gloss = {
  'lemma': 'lemma',
  'angabe': 'grammar',
  'de': 'meaning',
  'tokens': 'tokens',
};
const _sentence = {
  'id': 'id',
  'tokens': 'tokens',
  'teilsaetze': 'clauses',
  'de': 'meaning',
};
const _token = {
  'id': 'id',
  'la': 'text',
  'lemma': 'lemma',
  'analyse': 'analysis',
  'rolle': 'role',
  'bezug': 'head',
  'verbform': 'verb_form',
};
const _clause = {
  'id': 'id',
  'art': 'type',
  'tokens': 'tokens',
  'uebergeordnet': 'parent',
  'sinnrichtung': 'sense',
  'de': 'meaning',
  'ausrichtung': 'alignment',
};
const _alignment = {'tokens': 'tokens', 'de': 'meaning'};
const _task = {
  'id': 'id',
  'titel': 'title',
  'punkte': 'points',
  'art': 'type',
  'frage': 'prompt',
  'loesung': 'solution',
  'elemente': 'elements',
  'items': 'items',
};

/// The `art` values of a task and the key names of its items.
const Map<String, (String, _Names?)> _taskTypes = {
  'bestimmen': (
    'analyze',
    {'token': 'token', 'merkmale': 'features', 'punkte': 'points'},
  ),
  'stammformen': (
    'principal_parts',
    {'lemma': 'lemma', 'stammformen': 'principal_parts', 'punkte': 'points'},
  ),
  'bilden': (
    'form',
    {
      'lemma': 'lemma',
      'merkmale': 'features',
      'form': 'form',
      'punkte': 'points',
    },
  ),
  'umformen': (
    'transform',
    {'vorgabe': 'given', 'ziel': 'target', 'punkte': 'points'},
  ),
  'vokabel': ('vocab', {'la': 'prompt', 'de': 'answer', 'punkte': 'points'}),
  'ableitung': (
    'derivation',
    {'fremdwort': 'loanword', 'la': 'source', 'punkte': 'points'},
  ),
  'kurzantwort': (
    'short_answer',
    {'frage': 'prompt', 'stichwoerter': 'keywords', 'punkte': 'points'},
  ),
  'wissen_mc': (
    'multiple_choice',
    {
      'frage': 'prompt',
      'teilsatz': 'clause',
      'optionen': 'options',
      'richtig': 'correct',
      'punkte': 'points',
    },
  ),
  'ordnen': ('order', null),
  'frei': ('free', null),
};

/// [pack], a schema 1 pack (German keys), as a schema 2 pack (English keys).
///
/// A value of the wrong shape is passed on unchanged for the loader to
/// refuse under its English path. Throws [ExamRejected] for a key that
/// schema 1 does not have.
Map<String, Object?> convertSchema1(Map pack) =>
    _map(pack, 'exam', _head, {
          'schema': (_, _) => 2,
          'lektionen': (v, p) => _map(v, p, _lessons, {}),
          'uebersetzung': (v, p) => _map(v, p, _translation, {
            'hilfen': (v, p) => _list(v, p, (v, p) => _map(v, p, _gloss, {})),
            'saetze': (v, p) => _list(v, p, _convertSentence),
          }),
          'aufgaben': (v, p) => _list(v, p, _convertTask),
        })
        as Map<String, Object?>;

typedef _Convert = Object? Function(Object? value, String path);

Object? _map(
  Object? node,
  String path,
  _Names names,
  Map<String, _Convert> inner,
) {
  if (node is! Map) return node;
  return {
    for (final MapEntry(:key, :value) in node.entries)
      names[key] ?? _unknown(path, key):
          inner[key]?.call(value, '$path.${names[key]}') ?? value,
  };
}

Never _unknown(String path, Object? key) => throw ExamRejected([
  ExamError(ExamRule.key, '$path.$key', 'unknown field'),
]);

Object? _list(Object? node, String path, _Convert convert) => node is! List
    ? node
    : [for (final (i, v) in node.indexed) convert(v, '$path[$i]')];

Object? _convertSentence(Object? node, String path) =>
    _map(node, path, _sentence, {
      'tokens': (v, p) => _list(v, p, _convertToken),
      'teilsaetze': (v, p) => _list(v, p, _convertClause),
    });

Object? _convertToken(Object? node, String path) =>
    _map(node, path, _token, {});

Object? _convertClause(Object? node, String path) => _map(node, path, _clause, {
  'ausrichtung': (v, p) => _list(v, p, (v, p) => _map(v, p, _alignment, {})),
});

Object? _convertTask(Object? node, String path) {
  final art = node is Map ? node['art'] : null;
  final (type, itemNames) = _taskTypes[art] ?? (null, null);
  final task = _map(node, path, _task, {
    if (type != null) 'art': (_, _) => type,
    if (itemNames != null)
      'items': (v, p) => _list(v, p, (v, p) => _map(v, p, itemNames, {})),
  });
  if (task is Map && art == 'vokabel') task['direction'] = 'la-de';
  return task;
}
