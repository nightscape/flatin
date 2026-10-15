import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:yaml/yaml.dart';

const _oldPaths = {
  'nouns': 'lib/data/latin_nouns.yaml',
  'verbs': 'lib/data/latin_verbs.yaml',
};
const _newPaths = {
  'nouns': 'lib/data/v2/latin_nouns.yaml',
  'verbs': 'lib/data/v2/latin_verbs.yaml',
};

/// One item of the legacy golden.
typedef LegacyItem = ({String id, String type, List<String> keys});

Map<String, List<LegacyItem>> _legacy() {
  final golden =
      jsonDecode(File('test/golden/legacy_v1.json').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final file in _oldPaths.keys)
      file: [
        for (final item
            in (golden[_oldPaths[file]!]['items'] as List)
                .cast<Map<String, dynamic>>())
          (
            id: item['id'] as String,
            type: item['type'] as String,
            keys: (item['formOrder'] as List).cast<String>(),
          ),
      ],
  };
}

List<String> _oldFormKeys(String file) {
  final old = loadYaml(File(_oldPaths[file]!).readAsStringSync()) as YamlMap;
  return (old['form_labels'] as YamlMap).keys.cast<String>().toList();
}

void main() {
  final legacy = _legacy();
  final map =
      MigrationMap.parse(File('lib/data/migration_v2.yaml').readAsStringSync());
  final files = {
    for (final file in parseGrammarFiles({
      for (final e in _newPaths.entries) e.value: File(e.value).readAsStringSync(),
    }))
      file.dataFileId: file,
  };

  test('the new files parse and hold every item once', () {
    expect(files.keys, unorderedEquals(['nouns', 'verbs']));
    for (final file in files.values) {
      final ids = file.items.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length, reason: '${file.path} ids');
      expect(ids, isNotEmpty);
    }
  });

  test('every old form key and type is mapped, and no new one twice', () {
    for (final entry in legacy.entries) {
      final formKeys = map.formKeys[entry.key]!;
      final types = map.types[entry.key]!;
      // `form_labels` is wider than both the keys the items fill and the keys
      // the old settings screen offered; everything in it must be mapped.
      for (final key in _oldFormKeys(entry.key)) {
        expect(formKeys, contains(key), reason: '${entry.key} $key');
      }
      for (final item in entry.value) {
        for (final key in item.keys) {
          expect(formKeys, contains(key), reason: '${item.id} $key');
        }
        expect(types, contains(item.type), reason: item.id);
      }
      final newKeys = [for (final keys in formKeys.values) ...keys];
      expect(newKeys.toSet().length, newKeys.length,
          reason: '${entry.key}: a new form key is mapped twice');
    }
  });

  test('the v0 key universe is what the old settings screen offered', () {
    for (final file in _oldPaths.keys) {
      final old = loadYaml(File(_oldPaths[file]!).readAsStringSync()) as YamlMap;
      expect(map.v0FormUniverse[file], (old['form_order'] as YamlList).toList(),
          reason: file);
      for (final key in map.v0FormUniverse[file]!) {
        expect(map.formKeys[file], contains(key), reason: '$file $key');
      }
    }
    // The vocative is the case in point: offered by no old screen, practised
    // in v2.
    expect(map.v0FormUniverse['nouns'], isNot(contains('vocative_singular')));
    expect(map.formKeys['nouns'], contains('vocative_singular'));
  });

  test('every old (item, key) is a key of its new item', () {
    for (final entry in legacy.entries) {
      final file = files[entry.key]!;
      final suffixes = map.itemKeySuffix;
      for (final item in entry.value) {
        final newId = (map.itemIds[item.id] ?? item.id).split(':').last;
        final keys = file.keysByItem[newId];
        expect(keys, isNotNull, reason: 'no new item for ${item.id}');
        final suffix = suffixes[item.id];
        for (final old in item.keys) {
          final base = map.formKeys[entry.key]![old]!.first;
          final key = suffix == null ? base : '$base.$suffix';
          expect(keys!.has(key), isTrue, reason: '${item.id}: $old -> $key');
        }
      }
    }
  });

  test('every item keeps its mapped type', () {
    for (final entry in legacy.entries) {
      final file = files[entry.key]!;
      for (final item in entry.value) {
        final newId = (map.itemIds[item.id] ?? item.id).split(':').last;
        expect(file.item(newId).typeName, map.types[entry.key]![item.type],
            reason: item.id);
      }
    }
  });

  test('item_ids holds the renamed nouns and the gender merge', () {
    expect(map.itemIds['nouns:regis'], 'nouns:rex');
    expect(map.itemIds['nouns:ea'], 'nouns:is');
    expect(map.itemIds['nouns:id'], 'nouns:is');
    expect(map.itemIds, isNot(contains('nouns:is')));
    expect(map.itemKeySuffix['nouns:is'], 'm');
    expect(map.itemKeySuffix['nouns:ea'], 'f');
    expect(map.itemKeySuffix['nouns:id'], 'n');
    expect(map.itemIds['nouns:tria'], 'nouns:tres');
  });

  test('the additions of the last vocabulary round are there', () {
    final nouns = files['nouns']!;
    expect(nouns.item('idem').lemma, 'īdem');
    expect(nouns.item('duo').lemma, 'duo');
    expect(files['verbs']!.item('esse').lemma, 'esse');
  });

  test('templates carry macrons', () {
    for (final file in files.values) {
      final templates = [
        for (final type in file.types.values)
          for (final forms in type.forms.values)
            for (final template in forms) template.ending,
      ];
      expect(templates.where((e) => e.contains(RegExp('[āēīōū]'))), isNotEmpty,
          reason: file.path);
    }
    expect(
      files['nouns']!.types['A-Deklination']!.forms['abl.sg']!.single.ending,
      'ā',
    );
  });
}
