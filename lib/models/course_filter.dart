import '../data/curriculum.dart';
import '../data/lesson_data.dart';
import 'practice_item.dart';
import 'settings.dart';

/// Decides what the learner practises: the course position says what has
/// been taught, the overrides say where the learner overruled that.
///
/// Precedence is forced-off, then forced-on, then the course range.
final class CourseFilter {
  final Settings settings;
  final Curriculum curriculum;
  final LessonData lessons;

  const CourseFilter(this.settings, this.curriculum, this.lessons);

  bool wordInRange(PracticeItem item) =>
      settings.courseWords.contains(lessons.lessonNumberOf(item));

  bool typeInRange(String dataFileId, String typeName) => curriculum
      .taughtType(dataFileId, typeName, settings.effectiveGrammar);

  bool formInRange(String dataFileId, FormLabel label) =>
      curriculum.taughtForm(dataFileId, label.key, settings.effectiveGrammar);

  bool wordPracticed(PracticeItem item) => switch (settings
      .overrideOfWord(normalizeDiacritics(item.lemma))) {
        Override.forcedOff => false,
        Override.forcedOn => true,
        Override.none => wordInRange(item),
      };

  bool typePracticed(String dataFileId, String typeName) =>
      switch (settings.overrideOfType(dataFileId, typeName)) {
        Override.forcedOff => false,
        Override.forcedOn => true,
        Override.none => typeInRange(dataFileId, typeName),
      };

  /// A switched-off axis value hides every form that names it, whatever the
  /// form's own override says.
  bool formPracticed(String dataFileId, FormLabel label) {
    if (settings.offFeaturesOf(dataFileId, label).isNotEmpty) return false;
    return switch (settings.overrideOfForm(dataFileId, label.key)) {
      Override.forcedOff => false,
      Override.forcedOn => true,
      Override.none => formInRange(dataFileId, label),
    };
  }

  Set<FormKey> practicedForms(String dataFileId, List<FormLabel> labels) => {
        for (final label in labels)
          if (formPracticed(dataFileId, label)) label.key,
      };

  bool itemPracticed(PracticeItem item) =>
      wordPracticed(item) && typePracticed(item.dataFileId, item.type);

  /// The live counts of the course card: the practised words and, per data
  /// file, the practised forms they add up to.
  ({int words, int nounForms, int verbForms}) summary(
    List<PracticeItem> items,
  ) {
    var words = 0, nounForms = 0, verbForms = 0;
    for (final item in items) {
      if (!itemPracticed(item)) continue;
      words++;
      final forms = practicedForms(item.dataFileId, item.formLabels).length;
      if (item.dataFileId == 'nouns') {
        nounForms += forms;
      } else {
        verbForms += forms;
      }
    }
    return (words: words, nounForms: nounForms, verbForms: verbForms);
  }
}
