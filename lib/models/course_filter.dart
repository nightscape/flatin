import '../data/curriculum.dart';
import '../data/lesson_data.dart';
import 'practice_item.dart';
import 'settings.dart';

/// Decides what the learner practises: the course position says what has
/// been taught, the overrides say where the learner overruled that.
///
/// Precedence is forced-off, then forced-on, then the course range.
/// Why the course does not practise something yet.
sealed class CourseGap {
  const CourseGap();
}

/// The lesson lies outside the chosen range, to its left or right.
final class OutsideRange extends CourseGap {
  const OutsideRange();
}

/// The grammar range will reach it at [lesson].
final class FromLesson extends CourseGap {
  final int lesson;
  const FromLesson(this.lesson);
}

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

  /// The form's own verdict: its override, else the course. A switched-off
  /// axis value is not part of it.
  bool formSelected(String dataFileId, FormLabel label) =>
      switch (settings.overrideOfForm(dataFileId, label.key)) {
        Override.forcedOff => false,
        Override.forcedOn => true,
        Override.none => formInRange(dataFileId, label),
      };

  /// A switched-off axis value hides every form that names it, whatever the
  /// form's own override says.
  bool formPracticed(String dataFileId, FormLabel label) =>
      settings.offFeaturesOf(dataFileId, label).isEmpty &&
      formSelected(dataFileId, label);

  Set<FormKey> practicedForms(String dataFileId, List<FormLabel> labels) => {
        for (final label in labels)
          if (formPracticed(dataFileId, label)) label.key,
      };

  bool itemPracticed(PracticeItem item) =>
      wordPracticed(item) && typePracticed(item.dataFileId, item.type);

  /// Whether practice offers the item: it is practised and has a form to ask.
  bool reachesPractice(PracticeItem item) =>
      itemPracticed(item) &&
      practicedForms(item.dataFileId, item.formLabels).isNotEmpty;

  CourseGap? wordGap(PracticeItem item) {
    if (!wordInRange(item)) return const OutsideRange();
    return typeGap(item.dataFileId, item.type, lessons.lessonNumberOf(item));
  }

  /// [wordLesson] lifts the lesson a type is first practised with its words.
  CourseGap? typeGap(String dataFileId, String typeName, [int wordLesson = 1]) {
    if (typeInRange(dataFileId, typeName)) return null;
    return _grammarGap(curriculum.typeLesson(dataFileId, typeName), wordLesson);
  }

  CourseGap? formGap(String dataFileId, FormLabel label) {
    if (formInRange(dataFileId, label)) return null;
    return _grammarGap(curriculum.formLesson(dataFileId, label.key), 1);
  }

  CourseGap _grammarGap(int grammarLesson, int wordLesson) =>
      grammarLesson > settings.effectiveGrammar.to
          ? FromLesson(grammarLesson > wordLesson ? grammarLesson : wordLesson)
          : const OutsideRange();

  /// The live counts of the course card: the words practice offers and, per
  /// data file, the practised forms they add up to.
  ({int words, int nounForms, int verbForms}) summary(
    List<PracticeItem> items,
  ) {
    var words = 0, nounForms = 0, verbForms = 0;
    for (final item in items) {
      if (!reachesPractice(item)) continue;
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
