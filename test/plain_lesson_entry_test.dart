import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';

import 'support/latin_course.dart';

/// Each lesson file of the course with one `{word, note}` entry written as
/// the plain string of its word key, and that key.
List<(String path, String text, String key)> plainFormsOfNotedEntries() => [
  for (final path in latinCourse.books)
    for (final m in RegExp(
      r'\{word: "([^"]+)", note: "([^"]+)"\}',
    ).allMatches(File(path).readAsStringSync()))
      (
        path,
        File(path).readAsStringSync().replaceFirst(
          m.group(0)!,
          '"${m.group(1)} (${m.group(2)})"',
        ),
        '${m.group(1)} (${m.group(2)})',
      ),
];

void _serve(String servedPath, String text) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final path = utf8.decode(message!.buffer.asUint8List());
        final body = path == servedPath ? text : File(path).readAsStringSync();
        return ByteData.sublistView(Uint8List.fromList(utf8.encode(body)));
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('a plain string lesson entry matches no item that has a note', () async {
    final items = await loadAllPracticeItems();
    final cases = plainFormsOfNotedEntries();
    expect(cases, isNotEmpty);
    for (final (path, text, key) in cases) {
      _serve(path, text);
      final lessons = await loadLessonData(latinCourse.books);
      expect(lessons.notedWords, isNot(contains(key)), reason: "served");
      expect(
        () => assertLessonsCoverItems(lessons, items),
        throwsA(isStateError),
        reason: 'the plain entry "$key" in $path',
      );
    }
  });
}
