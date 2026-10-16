import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/lesson_data.dart';
import '../data/practice_data.dart';

part 'lesson_provider.g.dart';

/// The lesson → word mapping for the currently-configured textbook.
@riverpod
Future<LessonData> lessonData(Ref ref) async {
  return loadLessonData(lessonDataAsset);
}

/// Practisable words that no lesson lists, in YAML order and raw spelling.
///
/// Without them the settings screen has no checkbox for a word the app
/// practises, so it could never be switched off.
@riverpod
Future<List<String>> wordsOutsideLessons(Ref ref) async {
  final lessons = await ref.watch(lessonDataProvider.future);
  final words = <String>[];
  for (final item in await loadAllPracticeItems()) {
    final raw = item.lemma;
    if (lessons.wordToLesson.containsKey(normalizeDiacritics(raw))) continue;
    if (!words.contains(raw)) words.add(raw);
  }
  return words;
}
