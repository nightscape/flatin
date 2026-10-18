import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/lesson_data.dart';
import '../data/practice_data.dart';

part 'lesson_provider.g.dart';

/// The lesson → word mapping of the configured volumes.
@riverpod
Future<LessonData> lessonData(Ref ref) async {
  return loadLessonData(lessonDataAssets);
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
    if (lessons.lessonFor(item) != null) continue;
    if (!words.contains(item.lemma)) words.add(item.lemma);
  }
  return words;
}
