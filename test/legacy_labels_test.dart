// The v1 loader's output is frozen in test/golden/legacy_v1.json. Until the
// data files are rewritten, every label, id and form must still read the same.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

const _goldenPath = 'test/golden/legacy_v1.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final golden =
      jsonDecode(File(_goldenPath).readAsStringSync()) as Map<String, dynamic>;

  for (final assetPath in golden.keys) {
    test('$assetPath: labels and ids read as in $_goldenPath', () async {
      final expected = golden[assetPath] as Map<String, dynamic>;
      final items = await loadPracticeItems(assetPath);
      expect(items.length, expected['itemCount']);

      final expectedItems = expected['items'] as List<dynamic>;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final want = expectedItems[i] as Map<String, dynamic>;
        final reason = '$assetPath item $i (${want['lemma']})';

        expect(item.lemma, want['lemma'], reason: reason);
        expect(item.id, want['id'], reason: reason);
        expect(item.type, want['type'], reason: reason);
        expect(item.formOrder, want['formOrder'], reason: reason);
        expect(item.forms, want['forms'], reason: reason);
        expect(
          [for (final label in item.formLabels) label.displayName],
          want['labels'],
          reason: reason,
        );
      }
    });
  }
}
