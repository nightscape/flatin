import 'dart:math';

import 'package:latin_practice/models/course.dart';

typedef DataFileSpec = ({String id, String path, DataFileRole role});

/// A course manifest as data: what [courseYaml] writes and what the loader
/// must give back. [earnDataFiles] are the `when.dataFile` values of the
/// course's game rules, one earn rule each.
typedef CourseSpec = ({
  String path,
  String language,
  List<DataFileSpec> dataFiles,
  Map<DataFileRole, String> glossFiles,
  List<String> books,
  String sentences,
  String gameRules,
  List<String> earnDataFiles,
});

/// A course in directory [dir] with 1..4 data files of any roles, their ids
/// prefixed with [dir] so that courses of distinct [dir]s share no id, a gloss
/// file for any subset of the roles, 0..3 books, and game rules that name
/// 0..2 of the course's data file ids.
CourseSpec drawCourse(Random rng, String dir) {
  final fileCount = 1 + rng.nextInt(4);
  final bookCount = rng.nextInt(4);
  final earnCount = rng.nextInt(3);
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
    language: '$dir/language.yaml',
    dataFiles: dataFiles,
    glossFiles: {
      for (final role in DataFileRole.values)
        if (rng.nextBool()) role: '$dir/gloss_${role.name}.yaml',
    },
    books: [for (var i = 0; i < bookCount; i++) '$dir/book$i.yaml'],
    sentences: '$dir/sentences.yaml',
    gameRules: '$dir/game_rules.yaml',
    earnDataFiles: [
      for (var i = 0; i < earnCount; i++)
        dataFiles[rng.nextInt(dataFiles.length)].id,
    ],
  );
}

/// [course] with one more data file whose id is [id] and whose path is new.
CourseSpec withDataFile(CourseSpec course, String id) => (
  path: course.path,
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

/// [course] whose game rules also name the data file id [id].
CourseSpec withEarnDataFile(CourseSpec course, String id) => (
  path: course.path,
  language: course.language,
  dataFiles: course.dataFiles,
  glossFiles: course.glossFiles,
  books: course.books,
  sentences: course.sentences,
  gameRules: course.gameRules,
  earnDataFiles: [...course.earnDataFiles, id],
);

/// The manifest text of [course]; [rng] picks flow or block style per list.
String courseYaml(CourseSpec course, Random rng) {
  String list(List<String> items) => rng.nextBool() || items.isEmpty
      ? ' [${items.join(', ')}]'
      : items.map((i) => '\n  - $i').join();
  return [
    'language: ${course.language}',
    'data_files:${list([for (final f in course.dataFiles) '{id: ${f.id}, path: ${f.path}, role: ${f.role.name}}'])}',
    'gloss_files: {${[for (final MapEntry(:key, :value) in course.glossFiles.entries) '${key.name}: $value'].join(', ')}}',
    'books:${list(course.books)}',
    'sentences: ${course.sentences}',
    'game_rules: ${course.gameRules}',
  ].join('\n');
}

/// Game rules with one `answered` earn rule per id of [dataFileIds].
String gameRulesYaml(List<String> dataFileIds) => [
  'resources: [coins]',
  'earn:${dataFileIds.isEmpty ? ' []' : ''}',
  for (final id in dataFileIds)
    '  - {on: answered, when: {dataFile: $id}, gain: {coins: 1}}',
  'buildings: []',
].join('\n');

/// Every asset the course loader reads for the list [courses], by path.
Map<String, String> courseListAssets(List<CourseSpec> courses, Random rng) => {
  coursesAsset: courses.isEmpty
      ? '[]'
      : [for (final c in courses) '- ${c.path}'].join('\n'),
  for (final c in courses) ...{
    c.path: courseYaml(c, rng),
    c.gameRules: gameRulesYaml(c.earnDataFiles),
  },
};

/// [course] as the [CourseSpec] parts the loader gives back, for deep
/// equality with [specView].
Map<String, Object> courseView(Course course) => {
  'path': course.path,
  'language': course.language,
  'dataFiles': [
    for (final f in course.dataFiles) [f.id, f.path, f.role],
  ],
  'glossFiles': course.glossFiles,
  'books': course.books,
  'sentences': course.sentences,
  'gameRules': course.gameRules,
};

Map<String, Object> specView(CourseSpec spec) => {
  'path': spec.path,
  'language': spec.language,
  'dataFiles': [
    for (final f in spec.dataFiles) [f.id, f.path, f.role],
  ],
  'glossFiles': spec.glossFiles,
  'books': spec.books,
  'sentences': spec.sentences,
  'gameRules': spec.gameRules,
};
