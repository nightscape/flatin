import 'package:yaml/yaml.dart';
import 'asset_text.dart';
import '../models/practice_item.dart';

/// The course books, in reading order: each lists its lessons' words and
/// grammar.
const List<String> bookAssets = [
  'lib/data/agite_1.yaml',
  'lib/data/agite_2.yaml',
];

/// The highest lesson number of the configured volumes.
const int lastLesson = 40;

/// Maps each Latin word to the lesson in which it was introduced.
///
/// Lookup is by the exact spelling, macrons included: hīc (adverb) and hic
/// (pronoun) are different words and belong to different lessons.
class LessonData {
  /// word in its exact spelling -> its lesson (first occurrence wins).
  final Map<String, int> wordToLesson;

  /// lesson -> word list in its exact spelling, in YAML order; the lessons
  /// in reading order.
  final Map<int, List<String>> lessonWords;

  /// lesson number -> the 1-based index of the first asset that lists it.
  final Map<int, int> bookByLesson;

  /// The name of each asset's book, in asset order.
  final List<String> books;

  const LessonData({
    required this.wordToLesson,
    required this.lessonWords,
    required this.bookByLesson,
    required this.books,
  });

  /// The lesson that introduces [item]. Every practice item belongs to one;
  /// see [assertLessonsCoverItems].
  int lessonNumberOf(PracticeItem item) {
    final lesson = wordToLesson[item.lemma];
    if (lesson == null) {
      throw StateError('no lesson lists "${item.lemma}" (${item.id})');
    }
    return lesson;
  }

  /// The lesson numbers of the loaded data, ascending: the course scale.
  List<int> get lessonNumbers => bookByLesson.keys.toList()..sort();

  /// The first lesson of each volume, ascending.
  List<int> get bookStarts => [
    for (final l in lessonNumbers)
      if (l == lessonNumbers.first || bookOf(l) != bookOf(l - 1)) l,
  ];

  /// The volume that introduces [lesson].
  int bookOf(int lesson) {
    final book = bookByLesson[lesson];
    if (book == null) throw StateError('no volume lists lesson $lesson');
    return book;
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

/// Load the books' lessons from YAML assets, concatenated in the given
/// order.
///
/// Expected top-level shape of each asset (`grammar:` and `later:` are read
/// by the curriculum):
/// ```yaml
/// book: "Agite 1"
/// lessons:
///   - lesson: 1
///     words: ["iam", "diū", ...]
///     grammar: {...}
/// ```
///
/// A lesson must be unique across the assets; a word introduced by several
/// lessons belongs to the first one. A word is keyed by its exact spelling,
/// so a lesson list must spell it as the practice item does; see
/// [assertLessonsCoverItems].
Future<LessonData> loadLessonData(List<String> assetPaths) async {
  final wordToLesson = <String, int>{};
  final lessonWords = <int, List<String>>{};
  final bookByLesson = <int, int>{};
  final books = <String>[];

  for (var book = 1; book <= assetPaths.length; book++) {
    final assetPath = assetPaths[book - 1];
    final yaml = loadYaml(await loadAssetText(assetPath)) as YamlMap;
    books.add(yaml['book'] as String);

    for (final entry in yaml['lessons'] as YamlList) {
      final map = entry as YamlMap;
      final lesson = map['lesson'] as int;
      if (lessonWords.containsKey(lesson)) {
        throw StateError('lesson $lesson is listed twice ($assetPath)');
      }
      bookByLesson[lesson] = book;

      final words = <String>[];
      for (final word in map['words'] as YamlList) {
        final raw = word as String;
        if (raw.contains(',') || raw.contains('?')) {
          throw StateError(
            '$assetPath, lesson $lesson: the word "$raw" is no headword',
          );
        }
        words.add(raw);
        wordToLesson.putIfAbsent(raw, () => lesson);
      }
      lessonWords[lesson] = words;
    }
  }

  // A test loads one volume on its own, so only the configured course is
  // pinned to [lastLesson]; a lesson above it breaks the scale either way.
  final highest = bookByLesson.keys.reduce((a, b) => a > b ? a : b);
  final wholeCourse = assetPaths.join() == bookAssets.join();
  assert(
    wholeCourse ? highest == lastLesson : highest <= lastLesson,
    'the data ends at lesson $highest, lastLesson says $lastLesson',
  );

  return LessonData(
    wordToLesson: wordToLesson,
    lessonWords: lessonWords,
    bookByLesson: bookByLesson,
    books: books,
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
    if (lessons.wordToLesson.containsKey(item.lemma)) continue;
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
