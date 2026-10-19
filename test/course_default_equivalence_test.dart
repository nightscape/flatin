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
      final lessons = await loadLessonData(lessonDataAssets);
      final curriculum = await loadCurriculum(curriculumAssets);
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
      final lessons = await loadLessonData(lessonDataAssets);
      final curriculum = await loadCurriculum(curriculumAssets);
      final filter = CourseFilter(settings, curriculum, lessons);
      final items = await loadAllPracticeItems();

      var words = 0, nounForms = 0, verbForms = 0;
      for (final item in items) {
        if (!legacyItemSelected(settings, item)) continue;
        words++;
        final forms = legacyEnabledForms(
          settings,
          item.dataFileId,
          item.formLabels,
        ).length;
        if (item.dataFileId == 'nouns') {
          nounForms += forms;
        } else {
          verbForms += forms;
        }
      }

      expect(words, items.length);
      expect(nounForms, greaterThan(0));
      expect(verbForms, greaterThan(0));
      expect(filter.summary(items), (
        words: words,
        nounForms: nounForms,
        verbForms: verbForms,
      ));
    },
  );
}
