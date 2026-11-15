import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';

import 'support/grammar_breaker.dart';

const _verbsPath = 'lib/data/latin_verbs.yaml';

/// The shipped verbs file with one drawn look-alike set renamed, and the
/// set name that is gone.
(String, String) _verbsWithoutOneSet(Random r) {
  final tree = grammarTree(File(_verbsPath).readAsStringSync());
  final sets = tree['look_alikes'] as Map<String, dynamic>;
  final names = [...sets.keys]..sort();
  final gone = names[r.nextInt(names.length)];
  sets['${gone}_${r.nextInt(1000)}'] = sets.remove(gone);
  return (grammarSource(tree), gone);
}

String _verbsWithOtherId(Random r) {
  final tree = grammarTree(File(_verbsPath).readAsStringSync());
  tree['data_file_id'] = 'other_${r.nextInt(1000)}';
  return grammarSource(tree);
}

void _serve(String verbs) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final path = utf8.decode(message!.buffer.asUint8List());
        final text = path == _verbsPath ? verbs : File(path).readAsStringSync();
        return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    resetPracticeDataForTest();
  });

  group('a course whose verbs file lacks a look-alike set a kind asks for '
      'fails its load, naming the set', () {
    for (var seed = 0; seed < 10; seed++) {
      test('seed $seed', () async {
        final (verbs, gone) = _verbsWithoutOneSet(Random(seed));
        _serve(verbs);
        resetPracticeDataForTest();
        await expectLater(
          loadAllPracticeItems(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('"$gone"'),
            ),
          ),
        );
      });
    }
  });

  group('a course whose verbs file declares another data_file_id fails its '
      'load, naming the file and the id', () {
    for (var seed = 0; seed < 10; seed++) {
      test('seed $seed', () async {
        _serve(_verbsWithOtherId(Random(seed)));
        resetPracticeDataForTest();
        await expectLater(
          loadAllPracticeItems(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains(_verbsPath),
                contains('data_file_id "other_'),
                contains('names it "verbs"'),
              ),
            ),
          ),
        );
      });
    }
  });
}
