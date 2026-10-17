// Regenerate the golden: GOLDEN_UPDATE=1 flutter test test/explanation_golden_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';

import 'support/trace_fixtures.dart';

const _yamlFiles = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];
const _keys = ['explain.sandhiOtherType', 'explain.generatedOtherType'];
const _goldenPath = 'test/golden/explanation_other_type.txt';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('other-type explanation lines match the golden file', () async {
    final texts = await germanTexts();
    final lines = <String>[];
    final counts = {for (final key in _keys) key: 0};
    for (final file in _yamlFiles) {
      for (final item in await loadPracticeItems(file)) {
        for (final key in item.formOrder) {
          for (final line in explainForm(item, [key])) {
            if (!_keys.contains(line.key)) continue;
            lines.add(renderDe(texts, line));
            counts[line.key] = counts[line.key]! + 1;
          }
        }
      }
    }
    lines.sort();
    // ignore: avoid_print
    print('golden lines per key: $counts');
    final actual = '${lines.join('\n')}\n';

    final golden = File(_goldenPath);
    if (Platform.environment['GOLDEN_UPDATE'] == '1') {
      golden.writeAsStringSync(actual);
      return;
    }
    expect(golden.existsSync(), isTrue, reason: 'missing $_goldenPath');
    final expected = golden.readAsLinesSync();
    final shared = lines.length < expected.length
        ? lines.length
        : expected.length;
    for (var i = 0; i < shared; i++) {
      expect(lines[i], expected[i], reason: 'first differing line: ${i + 1}');
    }
    expect(lines.length, expected.length, reason: 'line count');
  });
}
