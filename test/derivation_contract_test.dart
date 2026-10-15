import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';

const _yamlFiles = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];

Set<String> _leafKeys(Map<String, dynamic> json, [String prefix = '']) {
  final keys = <String>{};
  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      keys.addAll(_leafKeys(value, path));
    } else {
      keys.add(path);
    }
  });
  return keys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Derivation contract', () {
    for (final assetPath in _yamlFiles) {
      test('$assetPath: forms cover formOrder with the item\'s own values',
          () async {
        final items = await loadPracticeItems(assetPath);
        expect(items, isNotEmpty);

        for (final item in items) {
          final label = item.word ?? item.baseForm ?? item.translation;

          expect(
            item.derivation.forms.keys.toList(),
            item.formOrder,
            reason: '$label: derivation keys must equal formOrder',
          );
          expect(item.derivation.type, item.type, reason: label);

          for (int i = 0; i < item.formOrder.length; i++) {
            final key = item.formOrder[i];
            expect(
              item.derivation.forms[key]!.result,
              item.forms[i],
              reason: '$label / $key: trace must match the answer',
            );
          }
        }
      });

      test('$assetPath: filterForms returns the keys of the kept rows',
          () async {
        final items = await loadPracticeItems(assetPath);

        for (final item in items) {
          final label = item.word ?? item.baseForm ?? item.translation;

          expect(
            item.filterForms(item.formOrder.toSet()).keys,
            item.formOrder,
            reason: '$label: all forms enabled',
          );

          final someKeys = item.formOrder.take(2).toSet();
          final filtered = item.filterForms(someKeys);
          expect(filtered.keys, someKeys.toList(), reason: label);
          expect(filtered.forms.length, filtered.keys.length, reason: label);
          expect(filtered.labels.length, filtered.keys.length, reason: label);
        }
      });
    }
  });

  group('describeLabels', () {
    test('merges labels that share tense and number', () {
      expect(
        describeLabels([
          FormLabel(name: 'Dativ', number: 'Plural'),
          FormLabel(name: 'Ablativ', number: 'Plural'),
        ]),
        'Dativ/Ablativ Plural',
      );
    });

    test('keeps tenses apart', () {
      expect(
        describeLabels([
          FormLabel(name: '3. Person', number: 'Singular', tense: 'Präsens'),
          FormLabel(name: '3. Person', number: 'Singular', tense: 'Perfekt'),
        ]),
        'Präsens: 3. Person Singular, Perfekt: 3. Person Singular',
      );
    });

    test('a single label reads like its displayName', () {
      final label = FormLabel(name: 'Genitiv', number: 'Plural');
      expect(describeLabels([label]), label.displayName);
    });
  });

  test('de.json and en.json have the same keys', () {
    Set<String> keysOf(String path) => _leafKeys(
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
        );

    final de = keysOf('assets/flutter_i18n/de.json');
    final en = keysOf('assets/flutter_i18n/en.json');

    expect(de.difference(en), isEmpty, reason: 'keys missing in en.json');
    expect(en.difference(de), isEmpty, reason: 'keys missing in de.json');
    expect(de, contains('explain.diag.noMatch'));
  });
}
