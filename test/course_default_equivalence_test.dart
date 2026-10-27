import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/legacy_selection.dart';

/// With the default course position the filter must answer exactly what the
/// settings answered before it existed, for every item of the real data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the default course practises what the settings alone practised',
    () async {
      final settings = Settings();
      final lessons = await loadLessonData(bookAssets);
      final curriculum = await loadCurriculum(bookAssets);
      final filter = CourseFilter(settings, curriculum, lessons);
      final items = await loadAllPracticeItems();

      expect(items, isNotEmpty);
      for (final item in items) {
        expect(
          filter.itemPracticed(item),
          legacyItemSelected(settings, item),
          reason: item.id,
        );
        expect(
          filter.typePracticed(item.dataFileId, item.type),
          settings.isTypeEnabled(item.dataFileId, item.type),
          reason: item.id,
        );
        expect(
          filter.practicedForms(item.dataFileId, item.formLabels),
          legacyEnabledForms(settings, item.dataFileId, item.formLabels),
          reason: item.id,
        );
      }
    },
  );

  test(
    'the default course card counts what the settings alone counted',
    () async {
      final settings = Settings();
      final lessons = await loadLessonData(bookAssets);
      final curriculum = await loadCurriculum(bookAssets);
      final filter = CourseFilter(settings, curriculum, lessons);
      final items = await loadAllPracticeItems();

      final words = items.where((i) => legacyItemSelected(settings, i));

      expect(words.length, items.length);
      expect(items.where(filter.reachesPractice), words);
    },
  );
}
