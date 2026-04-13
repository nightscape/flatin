import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/lesson_data.dart';

part 'lesson_provider.g.dart';

/// The lesson → word mapping for the currently-configured textbook.
@riverpod
Future<LessonData> lessonData(Ref ref) async {
  return loadLessonData('lib/data/agite_plus_bayern_1.yaml');
}
