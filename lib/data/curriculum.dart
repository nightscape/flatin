import 'package:yaml/yaml.dart';

import '../models/form_label.dart';
import '../models/lesson_range.dart';
import 'asset_text.dart';
import 'lesson_data.dart' show lastLesson;
import 'practice_data.dart';

/// The grammar progression of the configured volumes, by data file id.
const List<String> curriculumAssets = [
  'lib/data/agite_plus_bayern_1_grammatik.yaml',
  'lib/data/agite_plus_bayern_2_grammatik.yaml',
];

/// What a curriculum is checked against: the form labels and the types one
/// data file has.
typedef DataFileShape = ({List<FormLabel> labels, List<String> types});

/// One `forms:` entry: axis id -> the codes it accepts. A form matches when
/// every named axis carries one of them; `{}` matches every form of the file.
typedef _Selector = ({Map<String, Set<String>> axes, int lesson});

/// Which lesson introduces which form and which type.
///
/// Built once from the volume files and the shape of the practice data, so
/// every lookup is a map read and every inconsistency is a load error.
final class Curriculum {
  /// data file id -> form key -> lesson.
  final Map<String, Map<FormKey, int>> _formLessons;

  /// data file id -> type name -> lesson.
  final Map<String, Map<String, int>> _typeLessons;

  const Curriculum._(this._formLessons, this._typeLessons);

  static Curriculum parse(
    List<String> yamlSources,
    Map<String, DataFileShape> shapes,
  ) {
    final selectors = {for (final id in shapes.keys) id: <_Selector>[]};
    final typeLessons = {for (final id in shapes.keys) id: <String, int>{}};

    for (var i = 0; i < yamlSources.length; i++) {
      final where = 'curriculum file ${i + 1}';
      for (final entry in loadYaml(yamlSources[i]) as YamlList) {
        final map = entry as YamlMap;
        final later = map['later'] == true;
        final lesson = later ? laterLesson : map['lesson'] as int;
        if (!later && (lesson < 1 || lesson > lastLesson)) {
          throw StateError('$where: lesson $lesson is outside 1..$lastLesson');
        }
        for (final fileId in map.keys.cast<String>()) {
          if (fileId == 'lesson' || fileId == 'later') continue;
          final shape = shapes[fileId];
          if (shape == null) {
            throw StateError('$where, lesson $lesson: no data file "$fileId"');
          }
          final section = map[fileId] as YamlMap;
          for (final form in (section['forms'] as YamlList? ?? const [])) {
            selectors[fileId]!.add((
              axes: _parseSelector(form as YamlMap, shape, where, lesson),
              lesson: lesson,
            ));
          }
          for (final type in (section['types'] as YamlList? ?? const [])) {
            final name = type as String;
            if (!shape.types.contains(name)) {
              throw StateError(
                '$where, lesson $lesson: "$fileId" has no type "$name"',
              );
            }
            if (typeLessons[fileId]!.containsKey(name)) {
              throw StateError(
                '$where, lesson $lesson: type "$name" of "$fileId" is listed '
                'twice',
              );
            }
            typeLessons[fileId]![name] = lesson;
          }
        }
      }
    }

    final formLessons = <String, Map<FormKey, int>>{};
    for (final file in shapes.entries) {
      for (final type in file.value.types) {
        if (!typeLessons[file.key]!.containsKey(type)) {
          throw StateError(
            'no lesson teaches type "$type" of "${file.key}"',
          );
        }
      }
      formLessons[file.key] = _resolveForms(
        file.key,
        file.value.labels,
        selectors[file.key]!,
      );
    }

    return Curriculum._(formLessons, typeLessons);
  }

  int formLesson(String dataFileId, FormKey key) {
    final lesson = _formLessons[dataFileId]![key];
    if (lesson == null) {
      throw StateError('no curriculum entry for "$dataFileId" form "$key"');
    }
    return lesson;
  }

  int typeLesson(String dataFileId, String typeName) {
    final lesson = _typeLessons[dataFileId]![typeName];
    if (lesson == null) {
      throw StateError('no curriculum entry for "$dataFileId" type '
          '"$typeName"');
    }
    return lesson;
  }

  bool taughtForm(String dataFileId, FormKey key, LessonRange range) =>
      range.contains(formLesson(dataFileId, key));

  bool taughtType(String dataFileId, String typeName, LessonRange range) =>
      range.contains(typeLesson(dataFileId, typeName));
}

Map<String, Set<String>> _parseSelector(
  YamlMap selector,
  DataFileShape shape,
  String where,
  int lesson,
) {
  final axes = shape.labels.first.axes;
  return {
    for (final axisId in selector.keys.cast<String>())
      axisId: {
        for (final code in _codesOf(selector[axisId]))
          if (_knownCode(axes, axisId, code, where, lesson)) code,
      },
  };
}

List<String> _codesOf(dynamic value) =>
    value is YamlList ? value.cast<String>().toList() : [value as String];

bool _knownCode(
  Axes axes,
  String axisId,
  String code,
  String where,
  int lesson,
) {
  final axis = axes.axes.where((a) => a.id == axisId).firstOrNull;
  if (axis == null) {
    throw StateError('$where, lesson $lesson: no axis "$axisId"');
  }
  if (axis.indexOf(code) < 0) {
    throw StateError('$where, lesson $lesson: axis "$axisId" has no code '
        '"$code"');
  }
  return true;
}

/// The lesson of each form key: the most specific selector that matches it.
///
/// Every specificity is checked, not only the winning one, so the verdict
/// never depends on the order the selectors are listed in.
Map<FormKey, int> _resolveForms(
  String dataFileId,
  List<FormLabel> labels,
  List<_Selector> selectors,
) {
  final lessons = <FormKey, int>{};
  for (final label in labels) {
    final claims = <int, int>{};
    for (final selector in selectors) {
      if (!_matches(selector, label)) continue;
      final claimed = claims[selector.axes.length];
      if (claimed != null && claimed != selector.lesson) {
        throw StateError(
          '"$dataFileId" form "${label.key}": lesson $claimed and '
          'lesson ${selector.lesson} claim it equally specifically',
        );
      }
      claims[selector.axes.length] = selector.lesson;
    }
    if (claims.isEmpty) {
      throw StateError('no lesson teaches "$dataFileId" form "${label.key}"');
    }
    final mostSpecific = claims.keys.reduce((a, b) => a > b ? a : b);
    lessons[label.key] = claims[mostSpecific]!;
  }
  return lessons;
}

bool _matches(_Selector selector, FormLabel label) => selector.axes.entries
    .every((axis) => axis.value.contains(label.features[axis.key]));

/// Reads the volume files and checks them against the loaded practice data.
Future<Curriculum> loadCurriculum(List<String> assets) async {
  const practiceAssets = [
    'lib/data/latin_nouns.yaml',
    'lib/data/latin_verbs.yaml',
  ];
  final shapes = <String, DataFileShape>{};
  for (final path in practiceAssets) {
    final metadata = await getFormMetadata(path);
    shapes[metadata.dataFileId] = (
      labels: [
        for (final key in metadata.formOrder) metadata.formLabelsByKey[key]!,
      ],
      types: metadata.availableTypes,
    );
  }
  return Curriculum.parse(
    [for (final asset in assets) await loadAssetText(asset)],
    shapes,
  );
}
