// One-shot migration of the v1 vocabulary files to the schema-3.1 files in
// lib/data/v2/, plus the map that converts stored settings.
//
// Run from the repository root:
//   dart run tool/migrate_v2/migrate.dart
//
// The script stops on anything it does not know: an old form key or type that
// is in no map, an item that no hand-written item and no generated item covers,
// a derived principal part that disagrees with the old forms. Hand-written
// items live in items_nouns.yaml / items_verbs.yaml, the parts the old files
// cannot supply in parts.yaml, everything above `items:` in the two skeletons.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _toolDir = 'tool/migrate_v2';
const _outDir = 'lib/data/v2';
const _goldenFile = 'test/golden/legacy_v1.json';

const _oldFiles = {
  'nouns': 'lib/data/latin_nouns.yaml',
  'verbs': 'lib/data/latin_verbs.yaml',
};

const _genusCodes = ['m', 'f', 'n'];

// ------------------------------------------------------------------ maps

const _nounCases = {
  'nominative': 'nom',
  'genitive': 'gen',
  'dative': 'dat',
  'accusative': 'akk',
  'ablative': 'abl',
  'vocative': 'vok',
};

const _verbTempora = {
  'praesens': 'praes',
  'imperfekt': 'impf',
  'futur': 'fut',
  'perfekt': 'perf',
  'plusquamperfekt': 'plusq',
};

const _persons = {'first': '1', 'second': '2', 'third': '3'};
const _numeri = {'singular': 'sg', 'plural': 'pl'};

/// Old type -> new type. Every old type maps to exactly one new type.
const _typeMap = {
  'nouns': {
    'O-Deklination-maskulinum': 'O-Deklination-maskulinum',
    'O-Deklination-neutrum': 'O-Deklination-neutrum',
    'A-Deklination': 'A-Deklination',
    'E-Deklination': 'E-Deklination',
    'U-Deklination': 'U-Deklination',
    'Konsonantische-Deklination-mf': 'Konsonantische-Deklination-mf',
    'Konsonantische-Deklination-n': 'Konsonantische-Deklination-n',
    'Konsonantische-Deklination-i-mf': 'Konsonantische-Deklination-i-mf',
    'Konsonantische-Deklination-i-n': 'Konsonantische-Deklination-i-n',
    'Pronomen-personal': 'Pronomen-personal',
    'Pronomen-is-maskulinum': 'Pronomen-is',
    'Pronomen-is-femininum': 'Pronomen-is',
    'Pronomen-is-neutrum': 'Pronomen-is',
    'Pronomen-hic-maskulinum': 'Pronomen-hic',
    'Pronomen-hic-femininum': 'Pronomen-hic',
    'Pronomen-hic-neutrum': 'Pronomen-hic',
    'Pronomen-ille-maskulinum': 'Pronomen-ille',
    'Pronomen-ille-femininum': 'Pronomen-ille',
    'Pronomen-ille-neutrum': 'Pronomen-ille',
    'Pronomen-iste-maskulinum': 'Pronomen-iste',
    'Pronomen-iste-femininum': 'Pronomen-iste',
    'Pronomen-iste-neutrum': 'Pronomen-iste',
    'Pronomen-ipse-maskulinum': 'Pronomen-ipse',
    'Pronomen-ipse-femininum': 'Pronomen-ipse',
    'Pronomen-ipse-neutrum': 'Pronomen-ipse',
    'Pronomen-qui-maskulinum': 'Pronomen-qui',
    'Pronomen-qui-femininum': 'Pronomen-qui',
    'Pronomen-qui-neutrum': 'Pronomen-qui',
    'Pronomen-quis-maskulinum-femininum': 'Pronomen-quis',
    'Pronomen-quis-neutrum': 'Pronomen-quis',
    'Numerale-unus-maskulinum': 'Numerale-unus',
    'Numerale-unus-femininum': 'Numerale-unus',
    'Numerale-unus-neutrum': 'Numerale-unus',
    'Numerale-tres-maskulinum-femininum': 'Numerale-tres',
    'Numerale-tres-neutrum': 'Numerale-tres',
    'Numerale-milia': 'Numerale-milia',
  },
  'verbs': {
    'A-Konjugation': 'A-Konjugation',
    'E-Konjugation': 'E-Konjugation',
    'E-Konjugation (Stammperfekt)': 'E-Konjugation',
    'E-Konjugation (s-Perfekt)': 'E-Konjugation',
    'I-Konjugation': 'I-Konjugation',
    'I-Konjugation (Stammperfekt)': 'I-Konjugation',
    'K-Konjugation': 'Konsonantische',
    'Mischkonjugation': 'Mischkonjugation',
    'Unregelmäßig': 'Unregelmäßig',
  },
};

/// Old item id -> the genus its forms take in the merged item (Q3).
const _keySuffix = {
  'nouns:is': 'm',
  'nouns:ea': 'f',
  'nouns:id': 'n',
  'nouns:hic': 'm',
  'nouns:haec': 'f',
  'nouns:hoc': 'n',
  'nouns:ille': 'm',
  'nouns:illa': 'f',
  'nouns:illud': 'n',
  'nouns:iste': 'm',
  'nouns:ista': 'f',
  'nouns:istud': 'n',
  'nouns:ipse': 'm',
  'nouns:ipsa': 'f',
  'nouns:ipsum': 'n',
  'nouns:qui': 'm',
  'nouns:quae': 'f',
  'nouns:quod': 'n',
  'nouns:quis': 'm',
  'nouns:quid': 'n',
  'nouns:unus': 'm',
  'nouns:una': 'f',
  'nouns:unum': 'n',
  'nouns:tres': 'm',
  'nouns:tria': 'n',
};

// ------------------------------------------------------------------ text

const _macrons = {
  'ā': 'a',
  'ē': 'e',
  'ī': 'i',
  'ō': 'o',
  'ū': 'u',
  'ȳ': 'y',
  'ă': 'a',
  'ĕ': 'e',
  'ĭ': 'i',
  'ŏ': 'o',
  'ŭ': 'u',
};

String norm(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_macrons[char] ?? char);
  }
  return buffer.toString();
}

bool hasMacron(String text) => text.runes.any(
  (r) => _macrons.containsKey(String.fromCharCode(r)),
);

Never fail(String message) {
  stderr.writeln('migrate: $message');
  exit(1);
}

// ------------------------------------------------------------------ model

class NewItem {
  NewItem({
    required this.lemma,
    required this.translation,
    required this.type,
    required this.parts,
    this.id,
    this.forms = const {},
    this.deponent,
    this.explicitType = true,
  });

  final String? id;
  final String lemma;
  final String translation;
  final String type;
  final Map<String, Object> parts;
  final Map<String, Object> forms;
  final Object? deponent;
  bool explicitType;
}

// ------------------------------------------------------------------ main

void main() {
  final mapping = <String, Map<String, Object>>{};
  final itemIds = <String, String>{};
  final offered = <String, List<String>>{};

  for (final fileId in _oldFiles.keys) {
    final old = loadYaml(File(_oldFiles[fileId]!).readAsStringSync()) as YamlMap;
    final skeleton = File('$_toolDir/skeleton_$fileId.yaml').readAsStringSync();
    final handDoc =
        loadYaml(File('$_toolDir/items_$fileId.yaml').readAsStringSync())
            as YamlMap;
    final partsDoc =
        loadYaml(File('$_toolDir/parts.yaml').readAsStringSync()) as YamlMap;
    final extra = (partsDoc[fileId] as YamlMap?) ?? YamlMap();

    final oldKeys = (old['form_labels'] as YamlMap).keys.cast<String>().toList();
    final oldItems = _oldItems(fileId, old);

    _inventory(fileId, oldKeys, oldItems);

    // Hand-written items, by the old item they replace.
    final hand = <NewItem>[];
    final handOf = <String, NewItem>{};
    for (final spec in (handDoc['items'] as YamlList).cast<YamlMap>()) {
      final item = _handItem(spec);
      hand.add(item);
      for (final oldId in (spec['_old_ids'] as YamlList?) ?? const []) {
        handOf['$oldId'] = item;
      }
    }

    final inference = _parseInference(skeleton);
    final emitted = <NewItem>[];
    final seenHand = <NewItem>{};
    final newOf = <String, NewItem>{};

    for (final old in oldItems) {
      final spec = old.spec;
      final newType = _typeMap[fileId]![old.type];
      if (newType == null) fail('unknown old type "${old.type}" in $fileId');
      final oldId = old.id;

      final handItem = handOf[oldId];
      if (handItem != null) {
        if (handItem.type != newType) {
          fail('$oldId maps to $newType but its item says ${handItem.type}');
        }
        if (seenHand.add(handItem)) emitted.add(handItem);
        newOf[oldId] = handItem;
        continue;
      }

      final item = fileId == 'nouns'
          ? _nounItem(old, newType, extra[oldId] as YamlMap?)
          : _verbItem(spec, newType, extra[oldId] as YamlMap?);
      _checkAgainstOld(fileId, old, item);
      emitted.add(item);
      newOf[oldId] = item;
    }

    for (final item in hand) {
      if (!seenHand.contains(item)) emitted.add(item);
    }

    for (final item in emitted) {
      item.explicitType = _infer(inference, item.parts) != item.type;
    }

    for (final entry in handOf.entries) {
      if (!oldItems.any((o) => o.id == entry.key)) {
        fail('${entry.key} is claimed by a hand item but is in no old file');
      }
    }

    // New ids, and the ids that change.
    for (final old in oldItems) {
      final oldId = old.id;
      final item = newOf[oldId] ?? fail('no new item for $oldId');
      final newId = '$fileId:${item.id ?? norm(item.lemma)}';
      if (newId != oldId) itemIds[oldId] = newId;
    }

    File('$_outDir/latin_$fileId.yaml').writeAsStringSync(
      '$skeleton\n${_emitItems(emitted)}',
    );
    stdout.writeln('$fileId: ${emitted.length} items written');

    mapping[fileId] = {
      'form_keys': _formKeys(fileId, oldKeys, hand),
      'types': {
        for (final e in _typeMap[fileId]!.entries) e.key: e.value,
      },
    };
    offered[fileId] = (old['form_order'] as YamlList).cast<String>().toList();
  }

  _writeMigrationMap(mapping, itemIds, offered);
}

// ------------------------------------------------------------- inventory

typedef _Old = ({
  String id,
  String type,
  YamlMap spec,
  Map<String, String> forms,
});

/// The old items, with the id and the type the app resolves for them. Both
/// come from the legacy golden, because an old item may leave its type to the
/// old inference rules.
List<_Old> _oldItems(String fileId, YamlMap old) {
  final golden = (jsonDecode(File(_goldenFile).readAsStringSync())
      as Map<String, dynamic>)[_oldFiles[fileId]!] as Map<String, dynamic>;
  final goldenItems = (golden['items'] as List).cast<Map<String, dynamic>>();
  final specs = (old['items'] as YamlList).cast<YamlMap>();
  if (goldenItems.length != specs.length) {
    fail('$fileId: ${specs.length} items, golden has ${goldenItems.length}');
  }
  return [
    for (var i = 0; i < specs.length; i++)
      () {
        final spec = specs[i];
        final lemma = '${spec['base_form'] ?? spec['word']}';
        if (norm(lemma) != norm('${goldenItems[i]['lemma']}')) {
          fail('$fileId item $i: $lemma is not ${goldenItems[i]['lemma']}');
        }
        final order = (goldenItems[i]['formOrder'] as List).cast<String>();
        final forms = (goldenItems[i]['forms'] as List).cast<String>();
        return (
          id: '${goldenItems[i]['id']}',
          type: '${goldenItems[i]['type']}',
          spec: spec,
          forms: {
            for (var k = 0; k < order.length; k++) order[k]: forms[k],
          },
        );
      }(),
  ];
}

void _inventory(String fileId, List<String> keys, List<_Old> items) {
  final types = <String, int>{};
  for (final item in items) {
    types[item.type] = (types[item.type] ?? 0) + 1;
  }
  stdout.writeln('--- $fileId: ${items.length} items, ${keys.length} '
      'form keys, ${types.length} types');
  for (final key in keys) {
    final mapped = _newKey(fileId, key);
    stdout.writeln('    key  $key -> $mapped');
  }
  for (final entry in types.entries) {
    final mapped = _typeMap[fileId]![entry.key];
    if (mapped == null) fail('unknown old type "${entry.key}"');
    stdout.writeln('    type ${entry.key} (${entry.value}) -> $mapped');
  }
}

String _newKey(String fileId, String oldKey) {
  final parts = oldKey.split('_');
  if (fileId == 'nouns') {
    final kasus = _nounCases[parts.first];
    final numerus = _numeri[parts.last];
    if (kasus == null || numerus == null || parts.length != 2) {
      fail('unknown old noun key "$oldKey"');
    }
    return '$kasus.$numerus';
  }
  if (parts.first == 'imperativ' && parts.length == 2) {
    return 'imp.praes.akt.2.${_numeri[parts.last]}';
  }
  final tempus = _verbTempora[parts.first];
  if (tempus == null || parts.length != 4) fail('unknown old verb key "$oldKey"');
  final person = _persons[parts[1]];
  final numerus = _numeri[parts.last];
  if (person == null || numerus == null) fail('unknown old verb key "$oldKey"');
  return 'ind.$tempus.akt.$person.$numerus';
}

// ------------------------------------------------------------------ items

NewItem _handItem(YamlMap spec) {
  final parts = <String, Object>{
    for (final e in (spec['parts'] as YamlMap).entries)
      '${e.key}': _scalarOrList(e.value),
  };
  final lemmaPart = spec['parts'].containsKey('infinitiv') ? 'infinitiv' : 'nom';
  final lemma = parts[lemmaPart];
  return NewItem(
    id: spec['id'] as String?,
    lemma: lemma is List ? '${lemma.first}' : '$lemma',
    translation: '${spec['translation']}',
    type: '${spec['type']}',
    parts: parts,
    forms: {
      for (final e in ((spec['forms'] as YamlMap?) ?? YamlMap()).entries)
        '${e.key}': _scalarOrList(e.value),
    },
    deponent: spec['deponent'] == null ? null : _scalarOrList(spec['deponent']),
  );
}

Object _scalarOrList(dynamic value) =>
    value is YamlList ? [for (final v in value) '$v'] : '$value';

NewItem _nounItem(_Old old, String type, YamlMap? extra) {
  final spec = old.spec;
  final parts = <String, Object>{
    // `word` carries the macrons the golden's forms do not.
    'nom': '${spec['word_form'] == null || spec['word_form'] == 'nominative_singular' ? spec['word'] : old.forms['nominative_singular']}',
  };
  if (type.startsWith('Konsonantische')) {
    final gen = old.forms['genitive_singular'];
    if (gen == null) fail('${spec['word']} needs a genitive');
    parts['gen'] = gen;
  }
  for (final e in ((extra?['parts'] as YamlMap?) ?? YamlMap()).entries) {
    parts['${e.key}'] = '${e.value}';
  }
  return NewItem(
    lemma: '${parts['nom']}',
    translation: '${spec['translation']}',
    type: type,
    parts: parts,
  );
}

const _presentEndings = {
  'A-Konjugation': ['are', 'ō'],
  'E-Konjugation': ['ere', 'eō'],
  'I-Konjugation': ['ire', 'iō'],
  'Konsonantische': ['ere', 'ō'],
  'Mischkonjugation': ['ere', 'iō'],
};

const _perfectDefault = {
  'A-Konjugation': 'āvī',
  'E-Konjugation': 'uī',
  'I-Konjugation': 'īvī',
};

NewItem _verbItem(YamlMap spec, String type, YamlMap? extra) {
  final infinitiv = '${spec['base_form']}';
  final rule = _presentEndings[type];
  if (rule == null) fail('no present rule for $type');
  if (!norm(infinitiv).endsWith(rule[0])) {
    fail('$infinitiv does not end in -${rule[0]} for $type');
  }
  final root = infinitiv.substring(0, infinitiv.length - rule[0].length);
  final parts = <String, Object>{
    'infinitiv': infinitiv,
    'praesens_1sg': '$root${rule[1]}',
  };
  for (final e in ((extra?['parts'] as YamlMap?) ?? YamlMap()).entries) {
    parts['${e.key}'] = _scalarOrList(e.value);
  }
  return NewItem(
    lemma: infinitiv,
    translation: '${spec['translation']}',
    type: type,
    parts: parts,
    forms: {
      for (final e in ((extra?['forms'] as YamlMap?) ?? YamlMap()).entries)
        '${e.key}': _scalarOrList(e.value),
    },
    deponent: extra?['deponent'] == null
        ? null
        : _scalarOrList(extra!['deponent']),
  );
}

/// The old forms are the only check on the derived parts: the first person of
/// the present and of the perfect must come out as the old file spells them.
void _checkAgainstOld(String fileId, _Old old, NewItem item) {
  if (fileId != 'verbs') return;
  final oldId = old.id;
  final forms = old.forms;
  final oldPresent = forms['praesens_first_person_singular'];
  if (oldPresent != null &&
      norm(oldPresent) != norm('${item.parts['praesens_1sg']}')) {
    fail('$oldId: present ${item.parts['praesens_1sg']} vs old $oldPresent');
  }
  if (item.deponent != null) return;
  final perfect = item.parts['perfekt_1sg'] ??
      (_perfectDefault[item.type] == null
          ? fail('$oldId: ${item.type} needs perfekt_1sg in parts.yaml')
          : '${item.parts['infinitiv']}'.substring(
                0,
                '${item.parts['infinitiv']}'.length - 3,
              ) +
              _perfectDefault[item.type]!);
  final oldPerfect = forms['perfekt_first_person_singular'];
  if (oldPerfect != null && norm(oldPerfect) != norm('$perfect')) {
    fail('$oldId: perfect $perfect vs old $oldPerfect — add it to parts.yaml');
  }
}

// -------------------------------------------------------------- inference

typedef _Rule = ({String part, String suffix, int minLength, List<String> types});

List<_Rule> _parseInference(String skeleton) {
  final doc = loadYaml(skeleton) as YamlMap;
  final rules = <_Rule>[];
  for (final part in (doc['type_inference'] as YamlMap).entries) {
    for (final rule in (part.value as YamlList).cast<YamlMap>()) {
      rules.add((
        part: '${part.key}',
        suffix: '${rule['suffix']}',
        minLength: (rule['min_length'] as int?) ?? 0,
        types: [for (final t in rule['types'] as YamlList) '$t'],
      ));
    }
  }
  return rules;
}

/// S11, as far as the migration needs it: the first matching rule wins, and an
/// ambiguous rule infers nothing.
String? _infer(List<_Rule> rules, Map<String, Object> parts) {
  for (final rule in rules) {
    final value = parts[rule.part];
    if (value == null) continue;
    final spelling = value is List ? '${value.first}' : '$value';
    if (spelling.length < rule.minLength) continue;
    final matches = hasMacron(rule.suffix)
        ? spelling.endsWith(rule.suffix)
        : norm(spelling).endsWith(norm(rule.suffix));
    if (!matches) continue;
    return rule.types.length == 1 ? rule.types.single : null;
  }
  return null;
}

// ---------------------------------------------------------------- output

String _emitItems(List<NewItem> items) {
  final out = StringBuffer('items:\n');
  for (final item in items) {
    var first = true;
    void line(String text) {
      out.writeln('${first ? '  - ' : '    '}$text');
      first = false;
    }

    if (item.id != null) line('id: ${item.id}');
    if (item.explicitType) line('type: ${item.type}');
    line('translation: ${_quote(item.translation)}');
    line('parts: {${[
      for (final e in item.parts.entries) '${e.key}: ${_value(e.value)}',
    ].join(', ')}}');
    if (item.deponent != null) line('deponent: ${_value(item.deponent!)}');
    if (item.forms.isNotEmpty) {
      line('forms:');
      for (final e in item.forms.entries) {
        out.writeln('      ${e.key}: ${_value(e.value)}');
      }
    }
  }
  return out.toString();
}

String _quote(String text) => '"${text.replaceAll('"', r'\"')}"';

String _value(Object value) => value is List
    ? '[${value.map((v) => _quote('$v')).join(', ')}]'
    : _quote('$value');

/// Old form key -> the new keys that carry it. A key of a gender-merged item
/// carries the genus, so one old key can stand for up to four new ones.
Map<String, Object> _formKeys(
  String fileId,
  List<String> oldKeys,
  List<NewItem> hand,
) {
  final handKeys = {for (final item in hand) ...item.forms.keys};
  final map = <String, Object>{};
  for (final oldKey in oldKeys) {
    final base = _newKey(fileId, oldKey);
    final keys = [
      base,
      for (final genus in _genusCodes)
        if (handKeys.contains('$base.$genus')) '$base.$genus',
    ];
    map[oldKey] = keys.length == 1 ? base : keys;
  }
  return map;
}

void _writeMigrationMap(
  Map<String, Map<String, Object>> mapping,
  Map<String, String> itemIds,
  Map<String, List<String>> offered,
) {
  final out = StringBuffer()
    ..writeln('# How stored settings of the v1 data are read against the v2')
    ..writeln('# data. `form_keys` and `types` are keyed by data file, and a')
    ..writeln('# form key may stand for several new keys because the gender')
    ..writeln('# merge moved the genus into the key. `item_ids` lists only the')
    ..writeln('# items whose id changes; `item_key_suffix` gives the genus an')
    ..writeln("# old item's forms take inside its merged item.")
    ..writeln('#')
    ..writeln('# `v0_form_universe` is the old `form_order`: the keys the old')
    ..writeln('# settings screen offered. The oldest stored format lists what')
    ..writeln('# was switched ON, so its complement may only be taken against')
    ..writeln('# these keys — a key the screen never showed was never off.')
    ..writeln('#')
    ..writeln('# Written by tool/migrate_v2/migrate.dart.');
  for (final table in ['form_keys', 'types']) {
    out.writeln('\n$table:');
    for (final fileId in mapping.keys) {
      out.writeln('  $fileId:');
      for (final entry in (mapping[fileId]![table]! as Map).entries) {
        out.writeln('    ${_quote('${entry.key}')}: '
            '${_value(entry.value as Object)}');
      }
    }
  }
  out.writeln('\nitem_ids:');
  for (final entry in itemIds.entries) {
    out.writeln('  ${_quote(entry.key)}: ${_quote(entry.value)}');
  }
  out.writeln('\nv0_form_universe:');
  for (final entry in offered.entries) {
    out.writeln('  ${entry.key}:');
    for (final key in entry.value) {
      out.writeln('    - ${_quote(key)}');
    }
  }
  out.writeln('\nitem_key_suffix:');
  for (final entry in _keySuffix.entries) {
    out.writeln('  ${_quote(entry.key)}: ${_quote(entry.value)}');
  }
  File('lib/data/migration_v2.yaml').writeAsStringSync(out.toString());
  stdout.writeln('migration_v2.yaml: ${itemIds.length} changed ids');
}
