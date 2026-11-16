import 'package:yaml/yaml.dart';
import 'asset_text.dart';
import '../models/course.dart';
import '../models/practice_item.dart';

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

  /// The highest lesson of the loaded data: the length of the course.
  int get lastLesson => bookByLesson.keys.reduce((a, b) => a > b ? a : b);

  /// The stop beyond the last lesson: what the course never reaches.
  int get laterLesson => lastLesson + 1;

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

  final highest = bookByLesson.keys.reduce((a, b) => a > b ? a : b);
  final wholeCourse = assetPaths.join() == (await loadCourse()).books.join();
  if (wholeCourse) {
    for (var lesson = 1; lesson <= highest; lesson++) {
      if (!bookByLesson.containsKey(lesson)) {
        throw StateError('no lesson $lesson, but lesson $highest exists');
      }
    }
  }

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
  if (items.isEmpty) return;
  final lang = items.first.lang;
  final byLetters = {
    for (final words in lessons.lessonWords.values)
      for (final word in words) lang.fold(word): word,
  };
  final orphans = <String>[];
  for (final item in items) {
    if (lessons.wordToLesson.containsKey(item.lemma)) continue;
    final otherSpelling = byLetters[lang.fold(item.lemma)];
    final hint = otherSpelling == null
        ? ''
        : ', the lessons spell it "$otherSpelling"';
    orphans.add('${item.id} (${item.lemma})$hint');
  }
  if (orphans.isNotEmpty) {
    throw StateError('no lesson introduces: ${orphans.join(", ")}');
  }
}
