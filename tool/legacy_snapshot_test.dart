// Generator for test/golden/legacy_v1.json: the forms, keys, labels, types and
// ids the v1 loader produces. L0b and L6 compare the new engine against it.
// Run with `flutter test tool/legacy_snapshot_test.dart`; deleted in L6.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/fsrs_card.dart';

const _yamlFiles = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];
const _goldenPath = 'test/golden/legacy_v1.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes $_goldenPath', () async {
    final snapshot = <String, dynamic>{};
    for (final assetPath in _yamlFiles) {
      final items = await loadPracticeItems(assetPath);
      expect(items, isNotEmpty, reason: '$assetPath has no items');
      snapshot[assetPath] = {
        'itemCount': items.length,
        'items': [
          for (final item in items)
            {
              'id': PracticeItemCard.generateItemId(item),
              'lemma': item.lemma,
              'type': item.type,
              'formOrder': item.formOrder,
              'forms': item.forms,
              'labels': [
                for (final label in item.formLabels) label.displayName,
              ],
            },
        ],
      };
    }

    File(_goldenPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(snapshot)}\n',
    );
    stdout.writeln(
      'wrote $_goldenPath: '
      '${_yamlFiles.map((f) => '$f=${snapshot[f]['itemCount']}').join(' ')}',
    );
  });
}
