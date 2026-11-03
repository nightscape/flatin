import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'toy_assets.dart';
import 'toy_course_boot_test.dart' show tracerSteps;

final _latin = RegExp(r'[āēīōūȳĀĒĪŌŪȲăĕĭŏŭ]|latin_|\b(nouns|verbs|vocab)\b');
final _knownRed = RegExp(r'^- ([a-z-]+): (\S.*)$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Example tests: each pins one checked-in file set, not an input space.
  test('no toy course file holds a macron letter or a Latin file id', () {
    final files = Directory(toyDir).listSync().whereType<File>().toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        expect(_latin.hasMatch(line), isFalse, reason: '${file.path}:${i + 1}');
      }
    }
  });

  // The books' lesson range is checked against lastLesson by loadLessonData,
  // which the tracer's home step lists; Curriculum.parse reads their schema.
  test('the toy course parses with the app parsers', () {
    final words = parseGrammarFiles({
      'toy_words.yaml': File('$toyDir/toy_words.yaml').readAsStringSync(),
    }).single;
    final engine = GrammarEngine([words]);
    final keys = <String>{};
    for (final item in words.items) {
      final forms = engine.of(words.dataFileId, item.id).forms;
      expect(forms, hasLength(4), reason: item.id);
      keys.addAll(forms.keys);
    }
    final shape = (
      labels: [for (final k in keys) FormLabel.fromKey(k, words.axes)],
      types: {for (final item in words.items) item.typeName}.toList(),
    );
    final books = [
      for (final path in bookAssets) File(toyAssets[path]!).readAsStringSync(),
    ];
    Curriculum.parse(books, {words.dataFileId: shape});

    expect(
      parseSentenceCorpus(
        File('$toyDir/toy_sentences.yaml').readAsStringSync(),
      ).sentences,
      isEmpty,
    );
  });

  test('KNOWN_RED.md lists exactly the red steps of the tracer, each with '
      'its first error', () {
    final listed = [
      for (final line in File('test/tracer/KNOWN_RED.md').readAsLinesSync())
        if (_knownRed.firstMatch(line) case final m?) m[1]!,
    ];
    expect(
      listed,
      unorderedEquals([
        for (final step in tracerSteps)
          if (step.red) step.id,
      ]),
    );
  });
}
