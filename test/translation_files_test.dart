import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_keys.dart';

final _literalText = RegExp(
  r"""\b(?:Text|title|label|hintText|tooltip|semanticsLabel)\s*[(:]\s*(?:const\s+)?(?:'((?:[^'\\$\n]|\\.|\$\{[^}]*\}|\$\w+)*)'|"((?:[^"\\$\n]|\\.|\$\{[^}]*\}|\$\w+)*)")""",
);
final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');

void main() {
  test('every translation file holds the same keys', () {
    final de = translationKeys('de');
    final en = translationKeys('en');

    expect(de.difference(en), isEmpty, reason: 'only in de.json');
    expect(en.difference(de), isEmpty, reason: 'only in en.json');
  });

  test('no widget text in lib/ bypasses the translation files', () {
    final literals = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File ||
          !file.path.endsWith('.dart') ||
          file.path.endsWith('.g.dart')) {
        continue;
      }
      for (final match in _literalText.allMatches(file.readAsStringSync())) {
        final text = match.group(1) ?? match.group(2)!;
        if (text.replaceAll(_interpolation, '').contains(RegExp(r'[A-Za-z]'))) {
          literals.add('${file.path}: ${match.group(0)}');
        }
      }
    }

    expect(literals, isEmpty);
  });
}
