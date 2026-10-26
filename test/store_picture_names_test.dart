import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every store picture name is well formed and its number is unique', () {
    final step = RegExp(r'the screen looks like "([^"]*)"');
    final names = [
      for (final feature in Directory('test/features').listSync())
        if (feature is File && feature.path.endsWith('.feature'))
          for (final m in step.allMatches(feature.readAsStringSync()))
            m.group(1)!,
    ];
    expect(names, isNotEmpty);
    final format = RegExp(r'^store-(\d{4})-[a-z0-9-]+\.png$');
    final numbers = <String>[];
    for (final name in names) {
      final match = format.firstMatch(name);
      expect(match, isNotNull, reason: '$name is not store-NNNN-<slug>.png');
      numbers.add(match!.group(1)!);
    }
    expect(numbers.toSet().length, numbers.length, reason: '$names');
  });
}
