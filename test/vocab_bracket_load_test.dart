import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';

import 'support/grammar_breaker.dart';

const _vocabPath = 'lib/data/latin_vocab.yaml';

/// The shipped vocab file with a bracket text appended to one drawn spelling
/// (first or variant) of one drawn item's lemma part, and that spelling.
(String, String) vocabWithBracketSpelling(Random r) {
  final tree = grammarTree(File(_vocabPath).readAsStringSync());
  final items = tree['items'] as List;
  final spec = items[r.nextInt(items.length)] as Map;
  final parts = spec['parts'] as Map<String, dynamic>;
  final part = parts.keys.single;
  final spellings = [
    for (final s in parts[part] is List ? parts[part] as List : [parts[part]])
      '$s',
  ];
  if (r.nextBool()) spellings.add('${spellings[0]}x');
  final at = r.nextInt(spellings.length);
  spellings[at] =
      '${spellings[at]}${['(', ')', ' (note)', '(a)'][r.nextInt(4)]}';
  parts[part] = spellings;
  return (grammarSource(tree), spellings[at]);
}

void _serve(String vocab) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final path = utf8.decode(message!.buffer.asUint8List());
        final text = path == _vocabPath ? vocab : File(path).readAsStringSync();
        return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    resetPracticeData();
  });

  for (var seed = 0; seed < 10; seed++) {
    test('the course load refuses a vocab lemma spelling with a bracket, '
        'seed $seed', () async {
      final (vocab, spelling) = vocabWithBracketSpelling(Random(seed));
      _serve(vocab);
      resetPracticeData();
      await expectLater(
        loadAllPracticeItems(),
        throwsA(
          isA<SchemaError>()
              .having((e) => e.rule, 'rule', 'S3')
              .having((e) => e.message, 'message', contains(spelling)),
        ),
      );
    });
  }
}
