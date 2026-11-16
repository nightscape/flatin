import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/data/sentences.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/practice_item.dart';

import '../support/latin_course.dart' show lastLessonOf;
import 'toy_assets.dart';
import 'package:latin_practice/models/course.dart';

final _latin = RegExp(r'[āēīōūȳĀĒĪŌŪȲăĕĭŏŭ]|latin_|\b(nouns|verbs|vocab)\b');

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

  test('the toy course parses with the app parsers', () {
    final words = parseGrammarFiles(lang: courseLanguage(toyCourse), {
      'toy_words.yaml': File('$toyDir/toy_words.yaml').readAsStringSync(),
    }).single;
    expect(
      words.lang.id,
      courseLanguage(toyCourse).id,
      reason: 'a course parses with the language its manifest names',
    );
    final engine = GrammarEngine([words]);
    final keys = <String>{};
    for (final item in words.items) {
      final forms = engine.of(words.dataFileId, item.id).forms;
      expect(forms, hasLength(4), reason: item.id);
      keys.addAll(forms.keys);
    }
    final shape = (
      role: DataFileRole.noun,
      labels: [for (final k in keys) FormLabel.fromKey(k, words.axes)],
      types: {for (final item in words.items) item.typeName}.toList(),
      baseForm: words.roles.baseForm!,
    );
    final books = [
      for (final path in toyCourse.books) File(path).readAsStringSync(),
    ];
    Curriculum.parse(books, {
      words.dataFileId: shape,
    }, lastLesson: lastLessonOf(toyCourse));

    expect(
      parseSentenceCorpus(
        File('$toyDir/toy_sentences.yaml').readAsStringSync(),
        Language.parse(File('$toyDir/toy_language.yaml').readAsStringSync()),
      ).sentences,
      isEmpty,
    );
    parseExam(
      File('$toyDir/toy.exam').readAsStringSync(),
      Language.parse(File('$toyDir/toy_language.yaml').readAsStringSync()),
    );
  });
}

/// The language file that [course] names.
Language courseLanguage(Course course) =>
    Language.parse(File(course.language).readAsStringSync());
