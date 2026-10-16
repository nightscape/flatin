import 'package:yaml/yaml.dart';
import 'asset_text.dart';
import '../models/practice_item.dart';

/// The lesson word lists of the configured volumes, in reading order.
const List<String> lessonDataAssets = [
  'lib/data/agite_plus_bayern_1.yaml',
  'lib/data/agite_plus_bayern_2.yaml',
];

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
  String? lessonFor(PracticeItem item) =>
      wordToLesson[normalizeDiacritics(item.lemma)];

  /// Whether [item] should be practiced; words in [deselectedWords]
  /// (normalized) are the ones the user switched off.
  bool includes(PracticeItem item, Set<String> deselectedWords) {
    if (deselectedWords.isEmpty) return true;
    return !deselectedWords.contains(normalizeDiacritics(item.lemma));
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

/// Load the lesson mapping from YAML assets, concatenated in the given order.
///
/// Expected top-level shape of each asset:
/// ```yaml
/// - lesson: "Lektion 1"
///   words: ["iam", "diū", ...]
/// ```
///
/// A lesson name must be unique across the assets; a word introduced by
/// several lessons belongs to the first one.
Future<LessonData> loadLessonData(List<String> assetPaths) async {
  final names = <String>[];
  final wordToLesson = <String, String>{};
  final lessonWords = <String, List<String>>{};

  for (final assetPath in assetPaths) {
    final yamlString = await loadAssetText(assetPath);
    final yaml = loadYaml(yamlString) as YamlList;

    for (final entry in yaml) {
      final map = entry as YamlMap;
      final name = map['lesson'] as String;
      if (lessonWords.containsKey(name)) {
        throw StateError('lesson "$name" is listed twice ($assetPath)');
      }
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
  }

  return LessonData(
    lessonNames: names,
    wordToLesson: wordToLesson,
    lessonWords: lessonWords,
  );
}
