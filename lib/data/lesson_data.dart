import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../models/practice_item.dart';

/// Maps each Latin word to the lesson in which it was introduced.
///
/// Lookup is diacritic-insensitive: words are normalized by stripping macrons
/// before comparison so that e.g. `amāre` in the source matches `amare` in
/// other data files.
class LessonData {
  /// Lesson names in presentation order.
  final List<String> lessonNames;

  /// normalized word -> lesson name (first occurrence wins).
  final Map<String, String> wordToLesson;

  const LessonData({required this.lessonNames, required this.wordToLesson});

  /// Returns the lesson for a [PracticeItem], or null if no match.
  ///
  /// For verbs the `base_form` is the canonical key; for nouns it's `word`.
  String? lessonFor(PracticeItem item) {
    final key = item.baseForm ?? item.word;
    if (key == null) return null;
    return wordToLesson[normalizeDiacritics(key)];
  }

  /// Whether [item] should be practiced given [selected] lessons.
  /// An empty selection means "all lessons".
  bool includes(PracticeItem item, Set<String> selected) {
    if (selected.isEmpty) return true;
    final lesson = lessonFor(item);
    if (lesson == null) return false;
    return selected.contains(lesson);
  }
}

/// Strips Latin macrons so words can be compared across data files.
String normalizeDiacritics(String text) {
  const map = {
    'ā': 'a',
    'ē': 'e',
    'ī': 'i',
    'ō': 'o',
    'ū': 'u',
    'Ā': 'A',
    'Ē': 'E',
    'Ī': 'I',
    'Ō': 'O',
    'Ū': 'U',
  };
  var result = text;
  map.forEach((from, to) => result = result.replaceAll(from, to));
  return result;
}

/// Load the lesson mapping from a YAML asset.
///
/// Expected top-level shape:
/// ```yaml
/// - lesson: "Lektion 1"
///   words: ["iam", "diū", ...]
/// ```
Future<LessonData> loadLessonData(String assetPath) async {
  final yamlString = await rootBundle.loadString(assetPath);
  final yaml = loadYaml(yamlString) as YamlList;

  final names = <String>[];
  final wordToLesson = <String, String>{};

  for (final entry in yaml) {
    final map = entry as YamlMap;
    final name = map['lesson'] as String;
    names.add(name);

    final words = map['words'] as YamlList;
    for (final word in words) {
      final normalized = normalizeDiacritics(word as String);
      wordToLesson.putIfAbsent(normalized, () => name);
    }
  }

  return LessonData(lessonNames: names, wordToLesson: wordToLesson);
}
