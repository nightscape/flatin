import 'package:yaml/yaml.dart';

import '../data/asset_text.dart';
import '../data/game_rules.dart';
import 'exercise.dart' show ExerciseKind;

/// The list of course manifests the app reads.
const coursesAsset = 'lib/data/courses.yaml';

/// What the app does with the items of a data file.
enum DataFileRole { noun, verb, vocab }

final class DataFile {
  /// The file's `data_file_id`: the first part of every card id.
  final String id;
  final String path;
  final DataFileRole role;

  const DataFile(this.id, this.path, this.role);
}

/// The files one course reads, as its manifest at [path] names them.
final class Course {
  final String path;
  final String language;

  /// In load order, which is also the display order.
  final List<DataFile> dataFiles;

  /// The translation files for the items of a role.
  final Map<DataFileRole, String> glossFiles;

  /// In reading order.
  final List<String> books;
  final String sentences;
  final String gameRules;

  const Course({
    required this.path,
    required this.language,
    required this.dataFiles,
    required this.glossFiles,
    required this.books,
    required this.sentences,
    required this.gameRules,
  });

  static const _keys = {
    'language',
    'data_files',
    'gloss_files',
    'books',
    'sentences',
    'game_rules',
  };

  /// Throws a [StateError] naming [path] for a key that is unknown or missing.
  factory Course.parse(String path, String source) {
    final yaml = _map(loadYaml(source), path);
    _keysExactly(yaml, _keys, path);
    return Course(
      path: path,
      language: _string(yaml['language'], '$path: language'),
      dataFiles: [
        for (final (i, entry) in _list(yaml['data_files'], path).indexed)
          _dataFile(entry, '$path: data_files[$i]'),
      ],
      glossFiles: {
        for (final MapEntry(:key, :value) in _map(
          yaml['gloss_files'],
          '$path: gloss_files',
        ).entries)
          _role(key, '$path: gloss_files'): _string(
            value,
            '$path: gloss_files.$key',
          ),
      },
      books: [
        for (final (i, book) in _list(yaml['books'], path).indexed)
          _string(book, '$path: books[$i]'),
      ],
      sentences: _string(yaml['sentences'], '$path: sentences'),
      gameRules: _string(yaml['game_rules'], '$path: game_rules'),
    );
  }

  /// Every data file but the vocab file, in course order.
  List<DataFile> get grammarFiles =>
      dataFiles.where((f) => f.role != DataFileRole.vocab).toList();

  DataFile dataFile(String id) => dataFiles.singleWhere(
    (f) => f.id == id,
    orElse: () => throw StateError('$path names no data file "$id"'),
  );

  DataFile dataFileAt(String assetPath) => dataFiles.singleWhere(
    (f) => f.path == assetPath,
    orElse: () => throw StateError('$path names no data file $assetPath'),
  );

  DataFile ofRole(DataFileRole role) => dataFiles.singleWhere(
    (f) => f.role == role,
    orElse: () => throw StateError('$path has no ${role.name} data file'),
  );
}

DataFile _dataFile(Object? entry, String where) {
  final map = _map(entry, where);
  _keysExactly(map, const {'id', 'path', 'role'}, where);
  return DataFile(
    _string(map['id'], '$where.id'),
    _string(map['path'], '$where.path'),
    _role(map['role'], '$where.role'),
  );
}

DataFileRole _role(Object? name, String where) =>
    DataFileRole.values.firstWhere(
      (r) => r.name == name,
      orElse: () => throw StateError('$where: unknown role "$name"'),
    );

void _keysExactly(YamlMap map, Set<String> keys, String where) {
  final unknown = map.keys.toSet().difference(keys);
  final missing = keys.difference(map.keys.toSet());
  if (unknown.isNotEmpty || missing.isNotEmpty) {
    throw StateError('$where: unknown keys $unknown, missing keys $missing');
  }
}

YamlMap _map(Object? value, String where) =>
    value is YamlMap ? value : throw StateError('$where: not a map');

YamlList _list(Object? value, String where) =>
    value is YamlList ? value : throw StateError('$where: not a list');

String _string(Object? value, String where) =>
    value is String ? value : throw StateError('$where: not a string');

/// Throws a [StateError] when a data file id repeats across [courses] (naming
/// the manifest of the repeat), when a game rule's `when` names a data file
/// or an exercise kind its course does not have (naming the game rules file),
/// and then when the list does not hold exactly one course.
void checkCourses(List<(Course, GameRules)> courses) {
  final seen = <String>{};
  for (final (course, rules) in courses) {
    for (final file in course.dataFiles) {
      if (!seen.add(file.id)) {
        throw StateError('${course.path}: data file id "${file.id}" repeats');
      }
    }
    final allowed = {
      'dataFile': {for (final f in course.dataFiles) f.id},
      'kind': {for (final k in ExerciseKind.values) k.name},
    };
    for (final (i, rule) in rules.earn.indexed) {
      for (final MapEntry(key: field, value: names) in allowed.entries) {
        final value = rule.when[field];
        if (value == null) continue;
        for (final name in value is List ? value : [value]) {
          if (!names.contains(name)) {
            throw StateError(
              '${course.gameRules}: earn[$i].when.$field "$name" is not one '
              'of $names',
            );
          }
        }
      }
    }
  }
  if (courses.length != 1) {
    throw StateError(
      '$coursesAsset lists ${courses.length} courses; the app reads one',
    );
  }
}

/// Throws a [StateError] naming the data file whose own `data_file_id`
/// ([declaredIdByPath]) differs from the id [course] gives it.
void checkDataFileIds(Course course, Map<String, String> declaredIdByPath) {
  for (final file in course.dataFiles) {
    final declared = declaredIdByPath[file.path]!;
    if (declared != file.id) {
      throw StateError(
        '${file.path}: data_file_id "$declared", but ${course.path} '
        'names it "${file.id}"',
      );
    }
  }
}

/// Reads, checks and returns the courses of [coursesAsset].
Future<List<Course>> loadCourses() async {
  final paths = _list(
    loadYaml(await loadAssetText(coursesAsset)),
    coursesAsset,
  );
  final courses = <(Course, GameRules)>[];
  for (final (i, path) in paths.indexed) {
    final course = Course.parse(
      _string(path, '$coursesAsset[$i]'),
      await loadAssetText(path as String),
    );
    courses.add((
      course,
      GameRules.parse(await loadAssetText(course.gameRules), course.gameRules),
    ));
  }
  checkCourses(courses);
  return [for (final (course, _) in courses) course];
}

/// The one course of [coursesAsset].
Future<Course> loadCourse() async => (await loadCourses()).single;
