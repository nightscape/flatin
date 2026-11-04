import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/course.dart';

import 'support/gen_course.dart';

const _seeds = 200;

/// The files the app read by fixed path before the manifest: the real list
/// must give exactly these, in this order.
const CourseSpec _latin = (
  path: 'lib/data/course.yaml',
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

/// The repo's own list, manifest and game rules.
Map<String, String> _repoAssets() => {
  for (final path in [coursesAsset, _latin.path, _latin.gameRules])
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
  yield ('the repo course', _repoAssets(), [_latin]);
  for (var seed = 1; seed <= _seeds; seed++) {
    final rng = Random(seed);
    final course = drawCourse(rng, 'c0');
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

  test('a list of one course loads that course: its data file ids, paths '
      'and roles in order, its gloss files, books, sentences, game rules and '
      'language', () async {
    for (final (name, assets, courses) in _oneCourse()) {
      _serve(assets);
      final loaded = await loadCourses();
      expect(
        [for (final c in loaded) courseView(c)],
        [for (final c in courses) specView(c)],
        reason: name,
      );
    }
  });

  test('a list of any other length than one throws and names the count, '
      'after the checks of each entry passed', () async {
    for (var seed = 1; seed <= _seeds; seed++) {
      final rng = Random(seed);
      final courses = seed == 1 ? <CourseSpec>[] : _drawList(rng);
      _serve(courseListAssets(courses, rng));
      await expectLater(
        loadCourses(),
        _stateError(['$coursesAsset lists ${courses.length} courses']),
        reason: 'seed $seed',
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
        _stateError([courses[at].gameRules, '"$id"']),
        reason: 'seed $seed',
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
