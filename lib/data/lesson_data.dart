import 'package:yaml/yaml.dart';
import 'asset_text.dart';
import '../models/practice_item.dart';

/// The lesson word lists of the configured volumes, in reading order.
const List<String> lessonDataAssets = [
  'lib/data/agite_plus_bayern_1.yaml',
  'lib/data/agite_plus_bayern_2.yaml',
];

/// The highest lesson number of the configured volumes.
const int lastLesson = 40;

/// The lesson number a unit name carries: "Lektion 22 Stammformen" -> 22,
/// "Plateaulektion 11 – 15 Stammformen" -> 11.
int lessonNumber(String lessonName) {
  final match = RegExp(r'[Ll]ektion\s+(\d+)').firstMatch(lessonName);
  if (match == null) {
    throw StateError('unit name "$lessonName" carries no lesson number');
  }
  return int.parse(match.group(1)!);
}

/// Maps each Latin word to the lesson in which it was introduced.
///
/// Lookup is by the exact spelling, macrons included: hīc (adverb) and hic
/// (pronoun) are different words and belong to different lessons.
class LessonData {
  /// Lesson names in presentation order.
  final List<String> lessonNames;

  /// word in its exact spelling -> lesson name (first occurrence wins).
  final Map<String, String> wordToLesson;

  /// lesson name -> word list in its exact spelling, in YAML order.
  final Map<String, List<String>> lessonWords;

  /// lesson number -> the 1-based index of the first asset that lists it.
  final Map<int, int> bookByLesson;

  const LessonData({
    required this.lessonNames,
    required this.wordToLesson,
    required this.lessonWords,
    required this.bookByLesson,
  });

  /// Returns the lesson for a [PracticeItem], or null if no match.
  String? lessonFor(PracticeItem item) => wordToLesson[item.lemma];

  /// The lesson that introduces [item]. Every practice item belongs to one;
  /// see [assertLessonsCoverItems].
  int lessonNumberOf(PracticeItem item) {
    final name = lessonFor(item);
    if (name == null) {
      throw StateError('no lesson lists "${item.lemma}" (${item.id})');
    }
    return lessonNumber(name);
  }

  /// The lesson numbers of the loaded data, ascending: the course scale.
  List<int> get lessonNumbers => bookByLesson.keys.toList()..sort();

  /// The volume that introduces [lesson].
  int bookOf(int lesson) {
    final book = bookByLesson[lesson];
    if (book == null) throw StateError('no volume lists lesson $lesson');
    return book;
  }

  /// Whether [item] should be practiced; [deselectedWords] holds the words
  /// the user switched off, stored without macrons, so two lemmas with the
  /// same letters are switched off together.
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
/// several lessons belongs to the first one. A word is keyed by its exact
/// spelling, so a lesson list must spell it as the practice item does; see
/// [assertLessonsCoverItems].
Future<LessonData> loadLessonData(List<String> assetPaths) async {
  final names = <String>[];
  final wordToLesson = <String, String>{};
  final lessonWords = <String, List<String>>{};
  final bookByLesson = <int, int>{};

  for (var book = 1; book <= assetPaths.length; book++) {
    final assetPath = assetPaths[book - 1];
    final yamlString = await loadAssetText(assetPath);
    final yaml = loadYaml(yamlString) as YamlList;

    for (final entry in yaml) {
      final map = entry as YamlMap;
      final name = map['lesson'] as String;
      if (lessonWords.containsKey(name)) {
        throw StateError('lesson "$name" is listed twice ($assetPath)');
      }
      names.add(name);
      bookByLesson.putIfAbsent(lessonNumber(name), () => book);

      final words = map['words'] as YamlList;
      final rawWords = <String>[];
      for (final word in words) {
        final raw = word as String;
        if (raw.contains(',') || raw.contains('?')) {
          throw StateError(
            '$assetPath, "$name": the word "$raw" is no headword',
          );
        }
        rawWords.add(raw);
        wordToLesson.putIfAbsent(raw, () => name);
      }
      lessonWords[name] = rawWords;
    }
  }

  // A test loads one volume on its own, so only the configured course is
  // pinned to [lastLesson]; a lesson above it breaks the scale either way.
  final highest = bookByLesson.keys.reduce((a, b) => a > b ? a : b);
  final wholeCourse = assetPaths.join() == lessonDataAssets.join();
  assert(
    wholeCourse ? highest == lastLesson : highest <= lastLesson,
    'the data ends at lesson $highest, lastLesson says $lastLesson',
  );

  return LessonData(
    lessonNames: names,
    wordToLesson: wordToLesson,
    lessonWords: lessonWords,
    bookByLesson: bookByLesson,
  );
}

/// Throws naming every practice item that no lesson introduces. An item a
/// lesson lists in another spelling is named with that spelling.
void assertLessonsCoverItems(LessonData lessons, List<PracticeItem> items) {
  final byLetters = {
    for (final words in lessons.lessonWords.values)
      for (final word in words) normalizeDiacritics(word): word,
  };
  final orphans = <String>[];
  for (final item in items) {
    if (lessons.lessonFor(item) != null) continue;
    final otherSpelling = byLetters[normalizeDiacritics(item.lemma)];
    final hint = otherSpelling == null
        ? ''
        : ', the lessons spell it "$otherSpelling"';
    orphans.add('${item.id} (${item.lemma})$hint');
  }
  if (orphans.isNotEmpty) {
    throw StateError('no lesson introduces: ${orphans.join(", ")}');
  }
}
