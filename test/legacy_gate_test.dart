// The v1 loader's output is frozen in test/golden/legacy_v1.json. Every form,
// type and label the old data gave must read the same through the engine.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/derivation.dart';

const _goldenPath = 'test/golden/legacy_v1.json';

/// The old items whose forms live inside a merged pronoun item. Their labels
/// gain the genus as a head: "maskulin: Nominativ Singular".
const _mergedPronounItems = {
  'nouns:is', 'nouns:ea', 'nouns:id',
  'nouns:hic', 'nouns:haec', 'nouns:hoc',
  'nouns:ille', 'nouns:illa', 'nouns:illud',
  'nouns:iste', 'nouns:ista', 'nouns:istud',
  'nouns:ipse', 'nouns:ipsa', 'nouns:ipsum',
  'nouns:qui', 'nouns:quae', 'nouns:quod',
  'nouns:quis', 'nouns:quid',
  'nouns:unus', 'nouns:una', 'nouns:unum',
  'nouns:tres', 'nouns:tria',
};

/// The imperative keys carry their tense, so their label names it too.
const _imperativeKeys = {'imp.praes.akt.2.sg', 'imp.praes.akt.2.pl'};

const _genusHead = {'m': 'maskulin', 'f': 'feminin', 'n': 'neutrum'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final golden =
      jsonDecode(File(_goldenPath).readAsStringSync()) as Map<String, dynamic>;
  final map =
      MigrationMap.parse(File('lib/data/migration_v2.yaml').readAsStringSync());

  test('the merged pronoun exceptions are exactly the suffixed items', () {
    expect(_mergedPronounItems, map.itemKeySuffix.keys.toSet());
  });

  for (final assetPath in golden.keys) {
    test('$assetPath: forms, types and labels read as in $_goldenPath',
        () async {
      final dataFileId = assetPath.contains('nouns') ? 'nouns' : 'verbs';
      final items = {
        for (final item in await loadPracticeItems(assetPath)) item.id: item,
      };
      final oldItems = (golden[assetPath] as Map<String, dynamic>)['items']
          as List<dynamic>;

      final failures = <String>[];
      int compared = 0;
      for (final raw in oldItems.cast<Map<String, dynamic>>()) {
        final oldId = raw['id'] as String;
        final item = items[map.itemIds[oldId] ?? oldId];
        if (item == null) {
          failures.add('$oldId: no item');
          continue;
        }

        final oldType = raw['type'] as String;
        if (item.type != map.types[dataFileId]![oldType]) {
          failures.add('$oldId: type ${item.type}, wanted '
              '${map.types[dataFileId]![oldType]}');
        }

        final suffix = map.itemKeySuffix[oldId];
        final oldKeys = (raw['formOrder'] as List).cast<String>();
        final oldForms = (raw['forms'] as List).cast<String>();
        final oldLabels = (raw['labels'] as List).cast<String>();
        for (int i = 0; i < oldKeys.length; i++) {
          final base = map.formKeys[dataFileId]![oldKeys[i]]!.first;
          final key = suffix == null ? base : '$base.$suffix';
          final index = item.formOrder.indexOf(key);
          if (index < 0) {
            failures.add('$oldId $key: not practised');
            continue;
          }
          compared++;

          if (norm(item.forms[index]) != norm(oldForms[i])) {
            failures.add('$oldId $key: ${item.forms[index]}, '
                'wanted ${oldForms[i]}');
          }

          final label = item.formLabels[index].displayName;
          final wantedLabel = suffix != null
              ? '${_genusHead[suffix]}: ${oldLabels[i]}'
              : _imperativeKeys.contains(key)
                  ? oldLabels[i].replaceFirst('Imperativ:', 'Imperativ Präsens:')
                  : oldLabels[i];
          if (label != wantedLabel) {
            failures.add('$oldId $key: label $label, wanted $wantedLabel');
          }
        }
      }

      expect(compared, greaterThan(0));
      expect(failures, isEmpty, reason: failures.take(30).join('\n'));
    });
  }
}
