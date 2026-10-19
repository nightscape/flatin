import 'dart:convert';
import 'dart:io';

/// The dotted key of every string in a translation file.
Set<String> translationKeys(String code) {
  final json =
      jsonDecode(File('assets/flutter_i18n/$code.json').readAsStringSync())
          as Map<String, dynamic>;
  final keys = <String>{};
  void walk(String prefix, Map<String, dynamic> node) {
    node.forEach((name, value) {
      final key = prefix.isEmpty ? name : '$prefix.$name';
      if (value is Map<String, dynamic>) {
        walk(key, value);
      } else {
        keys.add(key);
      }
    });
  }

  walk('', json);
  return keys;
}
