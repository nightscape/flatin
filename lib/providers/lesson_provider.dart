import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/lesson_data.dart';
import '../data/practice_data.dart';
import '../models/practice_item.dart';

part 'lesson_provider.g.dart';

/// The lesson → word mapping of the configured volumes.
@riverpod
Future<LessonData> lessonData(Ref ref) async {
  return loadLessonData(bookAssets);
}

/// Every practice item of the loaded data files, nouns first.
@riverpod
Future<List<PracticeItem>> practiceItems(Ref ref) => loadAllPracticeItems();
