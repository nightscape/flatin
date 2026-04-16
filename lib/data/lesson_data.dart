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

  /// lesson name -> raw (undiacriticized) word list, in YAML order, for display.
  final Map<String, List<String>> lessonWords;

  const LessonData({
    required this.lessonNames,
    required this.wordToLesson,
    required this.lessonWords,
  });

  /// Returns the lesson for a [PracticeItem], or null if no match.
  ///
  /// For verbs the `base_form` is the canonical key; for nouns it's `word`.
  String? lessonFor(PracticeItem item) {
    final key = item.baseForm ?? item.word;
    if (key == null) return null;
    return wordToLesson[normalizeDiacritics(key)];
  }

  /// Whether [item] should be practiced given [selectedWords] (normalized).
  /// An empty selection means "all words".
  bool includes(PracticeItem item, Set<String> selectedWords) {
    if (selectedWords.isEmpty) return true;
    final key = item.baseForm ?? item.word;
    if (key == null) return false;
    return selectedWords.contains(normalizeDiacritics(key));
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
  final lessonWords = <String, List<String>>{};

  for (final entry in yaml) {
    final map = entry as YamlMap;
    final name = map['lesson'] as String;
    names.add(name);

    final words = map['words'] as YamlList;
    final rawWords = <String>[];
    for (final word in words) {
      final raw = word as String;
      rawWords.add(raw);
      final normalized = normalizeDiacritics(raw);
      wordToLesson.putIfAbsent(normalized, () => name);
    }
    lessonWords[name] = rawWords;
  }

  return LessonData(
    lessonNames: names,
    wordToLesson: wordToLesson,
    lessonWords: lessonWords,
  );
}
