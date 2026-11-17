import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/models/course.dart' show coursesAsset;
import 'package:yaml/yaml.dart';

import 'latin_course.dart';

/// The language file of the course as JSON, for tests to break.
Map<String, dynamic> latinLanguageData() => _json(latinCourse.language);

Map<String, dynamic> _json(String path) =>
    jsonDecode(jsonEncode(loadYaml(File(path).readAsStringSync())))
        as Map<String, dynamic>;

/// The sentence codes of a drawn language and the Latin codes they replace.
typedef CodeRenames = ({
  Map<String, String> constructions,
  Map<String, String> meanings,
  Map<String, String> mistakes,
});

/// [latinLang] with every construction, meaning and mistake code replaced by
/// a drawn code that no Latin code shares, and the sentences of the real
/// corpus (as JSON) with the same replacement.
({
  Language language,
  Map<String, dynamic> languageData,
  Map<String, dynamic> corpus,
  CodeRenames renames,
})
drawnSentenceLanguage(Random r) {
  final used = <String>{};
  String fresh() {
    String code;
    do {
      code = 'z${r.nextInt(1 << 20)}';
    } while (!used.add(code));
    return code;
  }

  Map<String, String> rename(Iterable<String> codes) => {
    for (final c in codes) c: fresh(),
  };
  final data = _json(latinCourse.language);
  final constructions = data['constructions'] as Map<String, dynamic>;
  final renames = (
    constructions: rename(constructions.keys),
    meanings: rename((data['meanings'] as List).cast()),
    mistakes: rename((data['mistakes'] as List).cast()),
  );
  data['id'] = 'x${r.nextInt(1 << 30)}';
  data['constructions'] = {
    for (final MapEntry(:key, :value) in constructions.entries)
      renames.constructions[key]!: value,
  };
  data['meanings'] = [
    for (final m in (data['meanings'] as List).cast<String>())
      renames.meanings[m]!,
  ];
  data['mistakes'] = [
    for (final m in (data['mistakes'] as List).cast<String>())
      renames.mistakes[m]!,
  ];

  final corpus = _json(latinCourse.sentences);
  for (final s in corpus['sentences'] as List) {
    final c = s['construction'] as Map<String, dynamic>;
    c['kind'] = renames.constructions[c['kind']]!;
    if (c['meaning'] case final List m) {
      c['meaning'] = [for (final x in m) renames.meanings[x]!];
    }
    for (final w in s['wrong'] as List) {
      w['mistake'] = renames.mistakes[w['mistake']]!;
    }
  }
  return (
    language: Language.parse(jsonEncode(data)),
    languageData: data,
    corpus: corpus,
    renames: renames,
  );
}

/// A language `name` map with a fresh name per UI language code.
Map<String, String> drawnLanguageName(Random r) {
  final n = r.nextInt(1 << 30);
  return {'de': 'Sprachede$n', 'en': 'Languageen$n'};
}

const _toyGrammar =
    '    grammar:\n      toy_words:\n        forms:\n'
    '          - {name: Grundformen}\n        types: [Klasse-Ka]\n';

/// The book files of a drawn course: [lessons] lessons numbered 1.. in order,
/// split over one to three volumes (one volume when a hole is drawn), with a
/// word of their own each. [gap] is the lesson left out when the draw asks
/// for a hole, else null.
({List<String> books, int lessons, int? gap}) drawnCourseBooks(
  Random r, {
  bool withGap = false,
}) {
  final lessons = (withGap ? 3 : 1) + r.nextInt(60);
  final gap = withGap ? 2 + r.nextInt(lessons - 2) : null;
  final volumes = withGap ? 1 : 1 + r.nextInt(min(3, lessons));
  final cuts = {for (var i = 1; i < volumes; i++) 2 + r.nextInt(lessons - 1)}
    ..add(lessons + 1);
  final books = <String>[];
  var next = 1;
  for (final end in (cuts.toList()..sort())) {
    final entries = [
      for (var l = next; l < end; l++)
        if (l != gap)
          '  - lesson: $l\n    words: ["w$l"]\n'
              '${l == 1 ? _toyGrammar : ''}',
    ];
    books.add('book: "B${books.length + 1}"\nlessons:\n${entries.join()}');
    next = end;
  }
  return (books: books, lessons: lessons, gap: gap);
}

const _toyCourseDir = 'test/fixtures/toy_course';

/// One drawn course of a course list: the toy course under its own id, name
/// and data file id.
typedef DrawnCourse = ({
  String id,
  String dataFileId,
  Map<String, String> name,
});

/// One to three drawn courses with distinct ids and data file ids; the
/// first of the list is the course that data stored before a list existed
/// belongs to.
List<DrawnCourse> drawnCourses(Random r, {int min = 1, int max = 3}) {
  final count = min + r.nextInt(max - min + 1);
  return [
    for (var i = 0; i < count; i++)
      (
        id: 'kurs$i-${r.nextInt(1000)}',
        dataFileId: 'words${i}_${r.nextInt(1000)}',
        name: drawnLanguageName(r),
      ),
  ];
}

String _toyFile(String name) => File('$_toyCourseDir/$name').readAsStringSync();

/// The asset texts that make the app load [courses] as its course list; every
/// course teaches the toy words of its own data file in the two toy books.
Map<String, String> servedCourses(List<DrawnCourse> courses) {
  String own(String text, DrawnCourse c) =>
      text.replaceAll('toy_words', c.dataFileId);
  final manifest = _toyFile('course.yaml');
  return {
    coursesAsset: [
      for (final c in courses) '- drawn/${c.id}/course.yaml',
    ].join('\n'),
    for (final c in courses) ...{
      'drawn/${c.id}/course.yaml': own(manifest, c)
          .replaceFirst('id: toy\n', 'id: ${c.id}\n')
          .replaceFirst(
            RegExp(r'name: \{.*\}\n'),
            'name: {de: "${c.name['de']}", en: "${c.name['en']}"}\n',
          )
          .replaceAll('$_toyCourseDir/toy_book_', 'drawn/${c.id}/book_')
          .replaceAll(
            '$_toyCourseDir/${c.dataFileId}.yaml',
            'drawn/${c.id}/words.yaml',
          ),
      'drawn/${c.id}/words.yaml': own(_toyFile('toy_words.yaml'), c),
      'drawn/${c.id}/book_1.yaml': own(_toyFile('toy_book_1.yaml'), c),
      'drawn/${c.id}/book_2.yaml': own(_toyFile('toy_book_2.yaml'), c),
    },
  };
}

/// The toy exam pack under [packId], bound to [course] by its `kurs` header
/// unless [course] is null.
String drawnPack(String packId, String? course) {
  final text = _toyFile(
    'toy.exam',
  ).replaceFirst('id: toy-pack\n', 'id: $packId\n');
  return course == null
      ? text
      : text.replaceFirst('schema: 1\n', 'schema: 1\nkurs: $course\n');
}
