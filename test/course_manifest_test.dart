import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/game_rules.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/models/exercise.dart' show ExerciseKind;

import 'support/gen_course.dart';

const _seeds = 200;

/// The files the app read by fixed path before the manifest: the real list
/// must give exactly these, in this order.
const CourseSpec _latin = (
  path: 'lib/data/course.yaml',
  id: 'latein',
  name: {'de': 'Latein', 'en': 'Latin'},
  language: 'lib/data/languages/la.yaml',
  dataFiles: [
    (id: 'nouns', path: 'lib/data/latin_nouns.yaml', role: DataFileRole.noun),
    (id: 'verbs', path: 'lib/data/latin_verbs.yaml', role: DataFileRole.verb),
    (id: 'vocab', path: 'lib/data/latin_vocab.yaml', role: DataFileRole.vocab),
  ],
  glossFiles: {
    DataFileRole.noun: 'lib/data/german_nouns.yaml',
    DataFileRole.verb: 'lib/data/german_verbs.yaml',
  },
  books: ['lib/data/agite_1.yaml', 'lib/data/agite_2.yaml'],
  sentences: 'lib/data/sentences.yaml',
  gameRules: 'lib/data/game_rules.yaml',
  earnDataFiles: [],
);

const CourseSpec _english = (
  path: 'lib/data/course_en.yaml',
  id: 'englisch',
  name: {'de': 'Englisch', 'en': 'English'},
  language: 'lib/data/languages/en.yaml',
  dataFiles: [],
  glossFiles: {},
  books: [],
  sentences: null,
  gameRules: null,
  earnDataFiles: [],
);

/// The repo's own list, manifest and game rules.
Map<String, String> _repoAssets() => {
  for (final path in [
    coursesAsset,
    _latin.path,
    _english.path,
    _latin.gameRules!,
  ])
    path: File(path).readAsStringSync(),
};

void _serve(Map<String, String> assets) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final text = assets[utf8.decode(message!.buffer.asUint8List())];
        return text == null
            ? null
            : ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
      });
}

/// The fixed case first, then [_seeds] drawn ones: the name, the assets the
/// loader reads and the courses they list.
Iterable<(String, Map<String, String>, List<CourseSpec>)> _oneCourse() sync* {
  yield ('the repo courses', _repoAssets(), [_latin, _english]);
  for (var seed = 1; seed <= _seeds; seed++) {
    final rng = Random(seed);
    final course = drawCourse(rng, 'c0', anyShape: true);
    yield ('seed $seed', courseListAssets([course], rng), [course]);
  }
}

/// A list of 2..4 courses that share no data file id.
List<CourseSpec> _drawList(Random rng) => [
  for (var i = 0; i < 2 + rng.nextInt(3); i++) drawCourse(rng, 'c$i'),
];

Matcher _stateError(List<String> parts) => throwsA(
  isA<StateError>().having(
    (e) => e.message,
    'message',
    allOf([for (final p in parts) contains(p)]),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a list of one to four courses loads its courses in order: their ids, '
      'names, data file ids, paths and roles, gloss files, books, sentences, '
      'game rules and language', () async {
    final cases = [
      ..._oneCourse(),
      for (var seed = 1; seed <= _seeds; seed++)
        () {
          final rng = Random(seed);
          final courses = _drawList(rng);
          return ('list $seed', courseListAssets(courses, rng), courses);
        }(),
    ];
    for (final (name, assets, courses) in cases) {
      _serve(assets);
      final loaded = await loadCourses();
      expect(
        [for (final c in loaded) courseView(c)],
        [for (final c in courses) specView(c)],
        reason: name,
      );
    }
  });

  test('an empty list throws and names the list', () async {
    _serve(courseListAssets([], Random(1)));
    await expectLater(loadCourses(), _stateError(['$coursesAsset lists no']));
  });

  test('a course id that repeats in a list throws and names the manifest of '
      'the repeat and the id', () async {
    for (var seed = 1; seed <= _seeds; seed++) {
      final rng = Random(seed);
      final courses = _drawList(rng);
      final at = 1 + rng.nextInt(courses.length - 1);
      final id = courses[rng.nextInt(at)].id;
      courses[at] = (
        path: courses[at].path,
        id: id,
        name: courses[at].name,
        language: courses[at].language,
        dataFiles: courses[at].dataFiles,
        glossFiles: courses[at].glossFiles,
        books: courses[at].books,
        sentences: courses[at].sentences,
        gameRules: courses[at].gameRules,
        earnDataFiles: courses[at].earnDataFiles,
      );
      _serve(courseListAssets(courses, rng));
      await expectLater(
        loadCourses(),
        _stateError([courses[at].path, 'course id "$id" repeats']),
        reason: 'seed $seed',
      );
    }
  });

  test('a manifest whose id is no lowercase slug, or whose name lacks an '
      'offered language, has another language, or has an empty text throws '
      'and names the manifest', () {
    final rng = Random(7);
    final spec = drawCourse(rng, 'c0');
    final text = courseYaml(spec, rng);
    final broken = [
      for (final id in ['Latein', 'la tein', '', '-a', 'a--b', 'ä', 'a_b'])
        text.replaceFirst('id: c0', "id: '$id'"),
      text.replaceFirst('name: {de: Kurs c0, ', 'name: {'),
      text.replaceFirst('en: Course c0}', 'en: Course c0, fr: Cours}'),
      text.replaceFirst('de: Kurs c0', "de: ' '"),
      text.replaceFirst('name: {de: Kurs c0, en: Course c0}', 'name: Kurs'),
      text.replaceFirst('id: c0\n', ''),
    ];
    for (final source in broken) {
      expect(
        () => Course.parse(spec.path, source),
        _stateError([spec.path]),
        reason: source,
      );
    }
  });

  test('a data file id that repeats in a list throws and names the manifest '
      'of the repeat and the id', () async {
    for (var seed = 1; seed <= _seeds; seed++) {
      final rng = Random(seed);
      final courses = rng.nextBool() ? [drawCourse(rng, 'c0')] : _drawList(rng);
      final at = rng.nextInt(courses.length);
      final earlier = [
        for (final c in courses.take(at + 1)) ...c.dataFiles.map((f) => f.id),
      ];
      final id = earlier[rng.nextInt(earlier.length)];
      courses[at] = withDataFile(courses[at], id);
      _serve(courseListAssets(courses, rng));
      await expectLater(
        loadCourses(),
        _stateError([courses[at].path, '"$id" repeats']),
        reason: 'seed $seed',
      );
    }
  });

  test('a course with data files and no books, or no game rules, throws and '
      'names the manifest and the key', () async {
    for (var seed = 1; seed <= _seeds; seed++) {
      final rng = Random(seed);
      final spec = drawCourse(rng, 'c0');
      final (broken, key) = rng.nextBool()
          ? (withoutBooks(spec), 'books')
          : (withoutGameRules(spec), 'game_rules');
      _serve(courseListAssets([broken], rng));
      await expectLater(
        loadCourses(),
        _stateError([spec.path, key]),
        reason: 'seed $seed',
      );
    }
  });

  test('a game rule that names a data file id its course lacks throws and '
      'names the game rules file and the id', () async {
    for (var seed = 1; seed <= _seeds; seed++) {
      final rng = Random(seed);
      final courses = rng.nextBool() ? [drawCourse(rng, 'c0')] : _drawList(rng);
      final at = rng.nextInt(courses.length);
      final id = '${courses[at].path}_missing';
      courses[at] = withEarnDataFile(courses[at], id);
      _serve(courseListAssets(courses, rng));
      await expectLater(
        loadCourses(),
        _stateError([courses[at].gameRules!, '"$id"']),
        reason: 'seed $seed',
      );
    }
  });

  // Generators: drawCourse and courseListAssets (reused, gen_course.dart);
  // gameRulesYaml takes the `kinds` of its rules. The kind names are the retired ones
  // (static examples, spelled in parts so no search finds them) then drawn
  // names that no kind has.
  final retired = [
    'lat'
        'De'
        'Wahl',
    'de'
        'Lat'
        'Wahl',
    'de'
        'Lat'
        'Tippen',
  ];
  Iterable<String> unknownKinds(Random rng) sync* {
    yield* retired;
    for (var i = 0; i < _seeds; i++) {
      yield 'kind${rng.nextInt(1 << 30)}';
    }
  }

  test('a game rule that names an exercise kind the app does not have '
      'throws and names the game rules file and the kind', () async {
    final rng = Random(5);
    var seed = 0;
    for (final kind in unknownKinds(rng)) {
      seed++;
      final course = drawCourse(Random(seed), 'c0');
      final assets = courseListAssets([course], Random(seed));
      assets[course.gameRules!] = gameRulesYaml([], kinds: [kind]);
      _serve(assets);
      await expectLater(
        loadCourses(),
        _stateError([course.gameRules!, '"$kind"']),
        reason: kind,
      );
    }
  });

  test('the load check refuses an unknown exercise kind and accepts every '
      'kind the app has', () {
    final rng = Random(6);
    final spec = drawCourse(rng, 'c0');
    final course = Course.parse(spec.path, courseYaml(spec, rng));
    GameRules rules(String kind) =>
        GameRules.parse(gameRulesYaml([], kinds: [kind]), spec.gameRules!);
    for (final kind in ExerciseKind.values) {
      checkCourses([(course, rules(kind.name))]);
    }
    for (final kind in unknownKinds(rng)) {
      expect(
        () => checkCourses([(course, rules(kind))]),
        _stateError([spec.gameRules!, '"$kind"']),
      );
    }
  });

  test('a data file whose own data_file_id differs from the id its manifest '
      'gives throws and names the data file and both ids', () {
    for (var seed = 1; seed <= _seeds; seed++) {
      final rng = Random(seed);
      final spec = drawCourse(rng, 'c0');
      final course = Course.parse(spec.path, courseYaml(spec, rng));
      final declared = {for (final f in spec.dataFiles) f.path: f.id};
      checkDataFileIds(course, declared);
      final wrong = spec.dataFiles[rng.nextInt(spec.dataFiles.length)];
      declared[wrong.path] = '${wrong.id}_other';
      expect(
        () => checkDataFileIds(course, declared),
        _stateError([wrong.path, '"${wrong.id}_other"', '"${wrong.id}"']),
        reason: 'seed $seed',
      );
    }
  });
}
