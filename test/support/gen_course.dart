import 'dart:math';

import 'package:latin_practice/models/course.dart';

typedef DataFileSpec = ({String id, String path, DataFileRole role});

/// A course manifest as data: what [courseYaml] writes and what the loader
/// must give back. [earnDataFiles] are the `when.dataFile` values of the
/// course's game rules, one earn rule each.
typedef CourseSpec = ({
  String path,
  String id,
  Map<String, String> name,
  String language,
  List<DataFileSpec> dataFiles,
  Map<DataFileRole, String> glossFiles,
  List<String> books,
  String? sentences,
  String? gameRules,
  List<String> earnDataFiles,
});

/// A course in directory [dir] with 1..4 data files of any roles, its id and
/// their ids prefixed with [dir] so that courses of distinct [dir]s share no
/// id, a gloss
/// file for any subset of the roles, 0..3 books, and game rules that name
/// 0..2 of the course's data file ids. With [anyShape] a course has 0..4 data
/// files; `sentences`, `books` and `game_rules` are absent or present by a
/// coin toss when it has no data file (a course with data files has 1..3
/// books, sentences and game rules, and always writes `gloss_files`).
CourseSpec drawCourse(Random rng, String dir, {bool anyShape = false}) {
  final fileCount = (anyShape ? 0 : 1) + rng.nextInt(anyShape ? 5 : 4);
  final hasData = fileCount > 0;
  final bookCount = (hasData ? 1 : 0) + rng.nextInt(hasData ? 3 : 4);
  final hasBooks = hasData || !anyShape || rng.nextBool();
  final hasSentences = hasData || !anyShape || rng.nextBool();
  final hasRules = hasData || !anyShape || rng.nextBool();
  final earnCount = fileCount == 0 || !hasRules ? 0 : rng.nextInt(3);
  final dataFiles = [
    for (var i = 0; i < fileCount; i++)
      (
        id: '${dir}_f$i',
        path: '$dir/f$i.yaml',
        role: DataFileRole.values[rng.nextInt(DataFileRole.values.length)],
      ),
  ];
  return (
    path: '$dir/course.yaml',
    id: dir,
    name: {'de': 'Kurs $dir', 'en': 'Course $dir'},
    language: '$dir/language.yaml',
    dataFiles: dataFiles,
    glossFiles: {
      for (final role in DataFileRole.values)
        if (rng.nextBool()) role: '$dir/gloss_${role.name}.yaml',
    },
    books: [
      if (hasBooks)
        for (var i = 0; i < bookCount; i++) '$dir/book$i.yaml',
    ],
    sentences: hasSentences ? '$dir/sentences.yaml' : null,
    gameRules: hasRules ? '$dir/game_rules.yaml' : null,
    earnDataFiles: [
      for (var i = 0; i < earnCount; i++)
        dataFiles[rng.nextInt(dataFiles.length)].id,
    ],
  );
}

/// [course] with one more data file whose id is [id] and whose path is new.
CourseSpec withDataFile(CourseSpec course, String id) => (
  path: course.path,
  id: course.id,
  name: course.name,
  language: course.language,
  dataFiles: [
    ...course.dataFiles,
    (id: id, path: '${course.path}.extra.yaml', role: DataFileRole.noun),
  ],
  glossFiles: course.glossFiles,
  books: course.books,
  sentences: course.sentences,
  gameRules: course.gameRules,
  earnDataFiles: course.earnDataFiles,
);

/// [course] with no books, so that `books` is an empty list or absent.
CourseSpec withoutBooks(CourseSpec course) => (
  path: course.path,
  id: course.id,
  name: course.name,
  language: course.language,
  dataFiles: course.dataFiles,
  glossFiles: course.glossFiles,
  books: [],
  sentences: course.sentences,
  gameRules: course.gameRules,
  earnDataFiles: course.earnDataFiles,
);

/// [course] with no game rules file.
CourseSpec withoutGameRules(CourseSpec course) => (
  path: course.path,
  id: course.id,
  name: course.name,
  language: course.language,
  dataFiles: course.dataFiles,
  glossFiles: course.glossFiles,
  books: course.books,
  sentences: course.sentences,
  gameRules: null,
  earnDataFiles: [],
);

/// [course] whose game rules also name the data file id [id].
CourseSpec withEarnDataFile(CourseSpec course, String id) => (
  path: course.path,
  id: course.id,
  name: course.name,
  language: course.language,
  dataFiles: course.dataFiles,
  glossFiles: course.glossFiles,
  books: course.books,
  sentences: course.sentences,
  gameRules: course.gameRules,
  earnDataFiles: [...course.earnDataFiles, id],
);

/// The manifest text of [course]; [rng] picks flow or block style per list.
String courseYaml(
  CourseSpec course,
  Random rng, {
  Set<String> omit = const {},
}) {
  String list(List<String> items) => rng.nextBool() || items.isEmpty
      ? ' [${items.join(', ')}]'
      : items.map((i) => '\n  - $i').join();
  return [
    'id: ${course.id}',
    'name: {${[for (final MapEntry(:key, :value) in course.name.entries) '$key: $value'].join(', ')}}',
    'language: ${course.language}',
    'data_files:${list([for (final f in course.dataFiles) '{id: ${f.id}, path: ${f.path}, role: ${f.role.name}}'])}',
    if (!omit.contains('gloss_files') &&
        (course.dataFiles.isNotEmpty ||
            course.glossFiles.isNotEmpty ||
            rng.nextBool()))
      'gloss_files: {${[for (final MapEntry(:key, :value) in course.glossFiles.entries) '${key.name}: $value'].join(', ')}}',
    if (!omit.contains('books') && (course.books.isNotEmpty || rng.nextBool()))
      'books:${list(course.books)}',
    if (!omit.contains('sentences'))
      if (course.sentences case final sentences?) 'sentences: $sentences',
    if (!omit.contains('game_rules'))
      if (course.gameRules case final rules?) 'game_rules: $rules',
  ].join('\n');
}

/// Game rules with one `answered` earn rule per id of [dataFileIds] and one
/// per name of [kinds].
String gameRulesYaml(
  List<String> dataFileIds, {
  List<String> kinds = const [],
}) => [
  'resources: [coins]',
  'earn:${dataFileIds.isEmpty && kinds.isEmpty ? ' []' : ''}',
  for (final id in dataFileIds)
    '  - {on: answered, when: {dataFile: $id}, gain: {coins: 1}}',
  for (final kind in kinds)
    '  - {on: answered, when: {kind: $kind}, gain: {coins: 1}}',
  'buildings: []',
].join('\n');

/// Every asset the course loader reads for the list [courses], by path.
Map<String, String> courseListAssets(List<CourseSpec> courses, Random rng) => {
  coursesAsset: courses.isEmpty
      ? '[]'
      : [for (final c in courses) '- ${c.path}'].join('\n'),
  for (final c in courses) ...{
    c.path: courseYaml(c, rng),
    ?c.gameRules: gameRulesYaml(c.earnDataFiles),
  },
};

/// [course] as the [CourseSpec] parts the loader gives back, for deep
/// equality with [specView].
Map<String, Object?> courseView(Course course) => {
  'path': course.path,
  'id': course.id,
  'name': course.name,
  'language': course.language,
  'dataFiles': [
    for (final f in course.dataFiles) [f.id, f.path, f.role],
  ],
  'glossFiles': course.glossFiles,
  'books': course.books,
  'sentences': course.sentences,
  'gameRules': course.gameRules,
};

Map<String, Object?> specView(CourseSpec spec) => {
  'path': spec.path,
  'id': spec.id,
  'name': spec.name,
  'language': spec.language,
  'dataFiles': [
    for (final f in spec.dataFiles) [f.id, f.path, f.role],
  ],
  'glossFiles': spec.glossFiles,
  'books': spec.books,
  'sentences': spec.sentences,
  'gameRules': spec.gameRules,
};
