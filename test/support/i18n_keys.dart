import 'dart:convert';
import 'dart:io';

/// The dotted key of every string in a translation file.
Set<String> translationKeys(String code) => translationTexts(code).keys.toSet();

/// Every string of a translation file by its dotted key.
Map<String, String> translationTexts(String code) {
  final json =
      jsonDecode(File('assets/flutter_i18n/$code.json').readAsStringSync())
          as Map<String, dynamic>;
  final texts = <String, String>{};
  void walk(String prefix, Map<String, dynamic> node) {
    node.forEach((name, value) {
      final key = prefix.isEmpty ? name : '$prefix.$name';
      if (value is Map<String, dynamic>) {
        walk(key, value);
      } else {
        texts[key] = value as String;
      }
    });
  }

  walk('', json);
  return texts;
}
