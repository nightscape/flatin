import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';

/// Serves [yaml] under [path] so a malformed index can be loaded at all.
void _serve(String path, String yaml) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
    if (utf8.decode(message!.buffer.asUint8List()) != path) return null;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(yaml)));
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('a word list entry that is no headword is a load error', () async {
    _serve('bad.yaml', '''
- lesson: "Lektion 1"
  words: ["is, ea, id"]
''');

    expect(
      loadLessonData(['bad.yaml']),
      throwsA(isStateError.having((e) => e.message, 'message',
          allOf(contains('bad.yaml'), contains('Lektion 1'),
              contains('is, ea, id')))),
    );
  });

  test('a question mark marks a gloss, not a headword', () async {
    _serve('bad.yaml', '''
- lesson: "Lektion 1"
  words: ["quis?"]
''');

    expect(loadLessonData(['bad.yaml']), throwsStateError);
  });

  test('the shipped index lists headwords only', () async {
    final lessons = await loadLessonData(lessonDataAssets);

    for (final entry in lessons.lessonWords.entries) {
      for (final word in entry.value) {
        expect(word, isNot(contains(',')), reason: entry.key);
        expect(word, isNot(contains('?')), reason: entry.key);
      }
    }
  });
}
