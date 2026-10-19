import 'package:yaml/yaml.dart';

import 'lesson_data.dart' show normalizeDiacritics;

/// The tables of `lib/data/migration_v2.yaml`.
///
/// `formKeys` and `types` are keyed by data file id, then by the old entry.
/// One old form key can stand for several new ones: the gender merge moved the
/// genus into the key of the merged pronouns and numerals.
class MigrationMap {
  final Map<String, Map<String, List<String>>> formKeys;
  final Map<String, Map<String, String>> types;

  /// Old item id -> new item id, for the ids that change.
  final Map<String, String> itemIds;

  /// Old item id -> the genus its forms take inside its merged item.
  final Map<String, String> itemKeySuffix;

  /// Per data file, the old form keys the old settings screen offered. A
  /// file's `form_labels` holds more, and a key that was never offered was
  /// never switched off.
  final Map<String, List<String>> v0FormUniverse;

  MigrationMap({
    required this.formKeys,
    required this.types,
    required this.itemIds,
    required this.itemKeySuffix,
    required this.v0FormUniverse,
  });

  factory MigrationMap.parse(String yamlSource) {
    final doc = loadYaml(yamlSource) as YamlMap;
    return MigrationMap(
      formKeys: {
        for (final file in (doc['form_keys'] as YamlMap).entries)
          '${file.key}': {
            for (final entry in (file.value as YamlMap).entries)
              '${entry.key}': entry.value is YamlList
                  ? [for (final k in entry.value as YamlList) '$k']
                  : ['${entry.value}'],
          },
      },
      types: {
        for (final file in (doc['types'] as YamlMap).entries)
          '${file.key}': {
            for (final entry in (file.value as YamlMap).entries)
              '${entry.key}': '${entry.value}',
          },
      },
      itemIds: {
        for (final entry in (doc['item_ids'] as YamlMap).entries)
          '${entry.key}': '${entry.value}',
      },
      itemKeySuffix: {
        for (final entry in (doc['item_key_suffix'] as YamlMap).entries)
          '${entry.key}': '${entry.value}',
      },
      v0FormUniverse: {
        for (final file in (doc['v0_form_universe'] as YamlMap).entries)
          '${file.key}': [for (final k in file.value as YamlList) '$k'],
      },
    );
  }

  /// The new word of every old word whose item is renamed or merged away.
  Map<String, String> get wordMap {
    final old = {...itemIds.keys, ...itemKeySuffix.keys};
    return {for (final id in old) _word(id): _word(itemIds[id] ?? id)};
  }

  static String _word(String itemId) => itemId.split(':').last;
}

/// The format `Settings.toJson` writes and `convertSettingsV3` produces.
const settingsVersionField = 'settingsVersion';
const settingsVersion = 3;

/// Reads stored settings of any older format against the v2 data.
///
/// The caller stores the result as it is: the version field tells a later run
/// that this JSON is already converted, and the "all old entries were
/// disabled" rule gives a different answer when it runs twice.
///
/// A `selectedWords` set of the oldest format is passed through: only the
/// caller knows the lesson words it is the complement of.
Map<String, dynamic> convertSettingsV2(
  Map<String, dynamic> json,
  MigrationMap map,
) {
  if (_versionOf(json) >= 2) return json;

  final isV0 = !json.containsKey('disabledForms');
  final disabledForms = <String, Set<String>>{};
  final disabledTypes = <String, Set<String>>{};
  for (final file in map.formKeys.keys) {
    disabledForms[file] = isV0
        ? _complement(map.v0FormUniverse[file]!, json['enabledForms'], file)
        : _stored(json['disabledForms'], file);
    disabledTypes[file] = isV0
        ? _complement(map.types[file]!.keys, json['enabledTypes'], file)
        : _stored(json['disabledTypes'], file);
  }

  final newForms = <String, List<String>>{};
  final newTypes = <String, List<String>>{};
  for (final file in map.formKeys.keys) {
    newForms[file] = _convert({
      for (final e in map.formKeys[file]!.entries)
        for (final newKey in e.value) newKey: e.key,
    }, disabledForms[file]!);
    newTypes[file] = _convert(
      map.types[file]!.map((old, now) => MapEntry(now, old)),
      disabledTypes[file]!,
      several: map.types[file]!,
    );
  }

  final words = _words(json['deselectedWords']);
  final deselected = _convert(
    {for (final e in map.wordMap.entries) e.value: e.key},
    words,
    several: map.wordMap,
  )..addAll(words.where((w) => !map.wordMap.containsKey(w)));

  return {
      ...json,
      settingsVersionField: 2,
      'disabledForms': newForms,
      'disabledTypes': newTypes,
      'deselectedWords': deselected,
    }
    ..remove('enabledForms')
    ..remove('enabledTypes');
}

/// Reads the word sets of the v2 format, which dropped the macrons, against
/// the exact lemmas of [lemmas].
///
/// One stored word stands for every lemma that spells it the same without
/// macrons: hīc and hic were one entry and become two, both keeping what the
/// learner said. A stored word no lemma matches is kept as it is.
Map<String, dynamic> convertSettingsV3(
  Map<String, dynamic> json,
  Iterable<String> lemmas,
) {
  if (_versionOf(json) >= 3) return json;
  final byNormalized = <String, Set<String>>{};
  for (final lemma in lemmas) {
    byNormalized.putIfAbsent(normalizeDiacritics(lemma), () => {}).add(lemma);
  }
  List<String> exact(dynamic stored) => [
    for (final word in _words(stored)) ...byNormalized[word] ?? {word},
  ];

  return {
    ...json,
    settingsVersionField: 3,
    'deselectedWords': exact(json['deselectedWords']),
    'forcedOnWords': exact(json['forcedOnWords']),
  };
}

int _versionOf(Map<String, dynamic> json) =>
    json[settingsVersionField] as int? ?? 0;

/// The new entries that stay disabled. [oneOld] names one old entry per new
/// entry; where [several] maps more than one old entry to the same new one,
/// all of them must have been disabled.
List<String> _convert(
  Map<String, String> oneOld,
  Set<String> disabled, {
  Map<String, String>? several,
}) {
  final result = <String>[];
  for (final entry in oneOld.entries) {
    final olds = several == null
        ? [entry.value]
        : [
            for (final e in several.entries)
              if (e.value == entry.key) e.key,
          ];
    if (olds.every(disabled.contains)) result.add(entry.key);
  }
  return result;
}

Set<String> _complement(
  Iterable<String> universe,
  dynamic storedEnabled,
  String file,
) {
  final enabled = (storedEnabled as Map<String, dynamic>?)?[file];
  if (enabled == null) return {};
  final kept = Set<String>.from(enabled as List);
  return universe.where((e) => !kept.contains(e)).toSet();
}

Set<String> _stored(dynamic stored, String file) {
  final entries = (stored as Map<String, dynamic>?)?[file];
  return entries == null ? {} : Set<String>.from(entries as List);
}

Set<String> _words(dynamic stored) =>
    stored == null ? {} : Set<String>.from(stored as List);
