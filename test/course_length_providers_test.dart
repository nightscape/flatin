import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/selection.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/data/settings_conversion.dart'
    show settingsVersionField;
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

import 'support/gen_language.dart';
import 'support/hand_items.dart';
import 'support/test_axes.dart';
import 'tracer/toy_assets.dart';

/// [books] with the toy grammar taught once, in the first lesson, so that
/// the curriculum parser accepts them.
List<String> _curriculumBooks(List<String> books) {
  final grammar = RegExp(
    r'    grammar:\n(      .*\n|        .*\n|          .*\n)*',
  );
  var first = true;
  return [
    for (final book in books)
      book.replaceAllMapped(grammar, (m) {
        final keep = first;
        first = false;
        return keep ? m[0]! : '';
      }),
  ];
}

Map<String, String> _served(List<String> books) {
  final manifest =
      jsonDecode(
            jsonEncode(
              loadYaml(File('$toyDir/course.yaml').readAsStringSync()),
            ),
          )
          as Map<String, dynamic>;
  final paths = [for (var i = 0; i < books.length; i++) 'drawn/book_$i.yaml'];
  manifest['books'] = paths;
  return {
    coursesAsset: '- drawn/course.yaml',
    'drawn/course.yaml': jsonEncode(manifest),
    for (final (i, path) in paths.indexed) path: books[i],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final vocab = handItem(
    dataFileId: 'nouns',
    lemma: 'iam',
    axes: nounAxes,
    role: DataFileRole.vocab,
    forms: {
      'nom.sg': ['iam'],
    },
  );
  test('the app providers carry the length of the drawn books', () async {
    for (var seed = 0; seed < 25; seed++) {
      final drawn = drawnCourseBooks(Random(seed));
      injectToyCourse(served: _served(_curriculumBooks(drawn.books)));
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final reason = 'seed $seed, ${drawn.lessons} lessons';
      final settings = await container.read(settingsProvider.future);
      expect(settings.lastLesson, drawn.lessons, reason: reason);
      expect(settings.kursstand, drawn.lessons, reason: reason);
      final curriculum = await container.read(curriculumProvider.future);
      expect(curriculum.laterLesson, drawn.lessons + 1, reason: reason);
    }
  });

  test('drawn books reach the app path as drawn, and vocabulary comes after '
      'their last lesson', () async {
    for (var seed = 0; seed < 25; seed++) {
      final drawn = drawnCourseBooks(Random(seed));
      injectToyCourse(served: _served(drawn.books));
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final curriculum = await container.read(curriculumProvider.future);
      expect(
        grammarLesson(curriculum, vocab, 'unused'),
        drawn.lessons + 1,
        reason: 'seed $seed, ${drawn.lessons} lessons',
      );
    }
  });

  test('stored settings of a drawn course carry the length of the drawn '
      'books', () async {
    for (var seed = 0; seed < 25; seed++) {
      final r = Random(seed);
      final drawn = drawnCourseBooks(r);
      injectToyCourse(served: _served(drawn.books));
      final prefs = _drawnPrefs(r, drawn.lessons);
      SharedPreferences.setMockInitialValues(prefs.values);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final reason = 'seed $seed, ${drawn.lessons} lessons, ${prefs.kind}';
      final settings = await container.read(settingsProvider.future);
      expect(settings.lastLesson, drawn.lessons, reason: reason);
      expect(settings.laterLesson, drawn.lessons + 1, reason: reason);
      expect(
        settings.kursstand,
        prefs.kursstand ?? drawn.lessons,
        reason: reason,
      );
    }
  });
}

/// Stored preferences a returning learner has: none, settings of the current
/// version, or settings of version 4 (converted on load), the last two with a
/// drawn Kursstand within the course.
({Map<String, Object> values, int? kursstand, String kind}) _drawnPrefs(
  Random r,
  int lessons,
) {
  final branch = r.nextInt(3);
  if (branch == 0) return (values: {}, kursstand: null, kind: 'fresh');
  final kursstand = 1 + r.nextInt(lessons);
  final stored = Settings(lastLesson: lessons, kursstand: kursstand).toJson();
  if (branch == 2) stored[settingsVersionField] = 4;
  return (
    values: {'practice_settings': jsonEncode(stored)},
    kursstand: kursstand,
    kind: '${branch == 1 ? 'stored' : 'older'}, Kursstand $kursstand',
  );
}
