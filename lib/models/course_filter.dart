import 'dart:math';

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

/// The lesson that teaches it lies below the grammar range.
final class GrammarOutsideRange extends CourseGap {
  const GrammarOutsideRange();
}

/// The grammar range will reach it at [lesson].
final class FromLesson extends CourseGap {
  final int lesson;
  const FromLesson(this.lesson);
}

/// Per data file, the feature of a word's basic form: its first form with
/// it spells the lemma.
const basicFormFeature = {'nouns': ('kasus', 'nom'), 'verbs': ('modus', 'inf')};

final class CourseFilter {
  final Settings settings;
  final Curriculum curriculum;
  final LessonData lessons;

  const CourseFilter(this.settings, this.curriculum, this.lessons);

  bool wordInRange(PracticeItem item) =>
      settings.courseWords.contains(lessons.lessonNumberOf(item));

  /// What the course alone says about a topic: a type stays known below the
  /// grammar range, only forms are narrowed by its lower bound.
  bool courseReaches(CourseTopic topic) => topic.typeName != null
      ? topic.lesson <= settings.courseGrammar.to
      : settings.courseGrammar.contains(topic.lesson);

  /// The grammar range's verdict on a topic, after the learner's own choice
  /// about the topic.
  bool topicInRange(CourseTopic topic) => settings
      .overrideOfTopic(topic.key)
      .verdict(inRange: courseReaches(topic));

  bool typeInRange(String dataFileId, String typeName) =>
      topicInRange(curriculum.typeTopic(dataFileId, typeName));

  bool formInRange(String dataFileId, FormLabel label) =>
      topicInRange(curriculum.formTopic(dataFileId, label.key));

  bool _topicSwitchedOff(CourseTopic topic) =>
      settings.overrideOfTopic(topic.key) == Override.forcedOff;

  bool wordPracticed(PracticeItem item) =>
      switch (settings.overrideOfWord(item.lemma)) {
        Override.forcedOff => false,
        Override.forcedOn => true,
        Override.none => wordInRange(item),
      };

  /// Vocab items have no grammar: their type and their one form are always
  /// practised, so only the word decides.
  bool typePracticed(String dataFileId, String typeName) =>
      dataFileId == 'vocab' ||
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
      dataFileId == 'vocab' ||
      settings.offFeaturesOf(dataFileId, label).isEmpty &&
          formSelected(dataFileId, label);

  /// The forms asked of a word; a word with none in the grammar range is
  /// asked its basic form once taught, unless the learner switched it off.
  Set<FormKey> practicedForms(String dataFileId, List<FormLabel> labels) {
    final practiced = {
      for (final label in labels)
        if (formPracticed(dataFileId, label)) label.key,
    };
    if (practiced.isNotEmpty) return practiced;
    final basic = _basicForm(dataFileId, labels);
    return {if (_formTaught(dataFileId, basic)) basic.key};
  }

  FormLabel _basicForm(String dataFileId, List<FormLabel> labels) {
    final (axis, value) = basicFormFeature[dataFileId]!;
    return labels.firstWhere(
      (l) => l.features[axis] == value,
      orElse: () => throw StateError(
        'no basic form ($axis: $value) among the $dataFileId forms '
        '${labels.map((l) => l.key)}',
      ),
    );
  }

  /// The forms the dropdowns offer: the practised ones and every other
  /// taught one, whatever the grammar range's lower bound.
  Set<FormKey> optionForms(String dataFileId, List<FormLabel> labels) => {
    ...practicedForms(dataFileId, labels),
    for (final label in labels)
      if (_formTaught(dataFileId, label)) label.key,
  };

  /// Taught up to the grammar range's end and not switched off.
  bool _formTaught(String dataFileId, FormLabel label) =>
      dataFileId == 'vocab' ||
      curriculum.formLesson(dataFileId, label.key) <=
              settings.courseGrammar.to &&
          settings.offFeaturesOf(dataFileId, label).isEmpty &&
          settings.overrideOfForm(dataFileId, label.key) !=
              Override.forcedOff &&
          !_topicSwitchedOff(curriculum.formTopic(dataFileId, label.key));

  bool itemPracticed(PracticeItem item) =>
      wordPracticed(item) && typePracticed(item.dataFileId, item.type);

  /// Whether practice offers the item: it is practised and has a form to ask.
  bool reachesPractice(PracticeItem item) {
    final (id, labels) = (item.dataFileId, item.formLabels);
    return itemPracticed(item) &&
        (labels.any((l) => formPracticed(id, l)) ||
            _formTaught(id, _basicForm(id, labels)));
  }

  /// Null when practice offers the word, or when the learner's own choice,
  /// not the course, keeps it from practice.
  CourseGap? wordGap(PracticeItem item) {
    final id = item.dataFileId;
    final lesson = lessons.lessonNumberOf(item);
    if (settings.overrideOfWord(item.lemma) != Override.forcedOn &&
        !wordInRange(item)) {
      return const OutsideRange();
    }
    final typeGapOfItem = typeGap(id, item.type, lesson);
    if (typeGapOfItem != null) return typeGapOfItem;

    if (practicedForms(id, item.formLabels).isNotEmpty) return null;
    final unreached = [
      for (final label in item.formLabels)
        if (settings.offFeaturesOf(id, label).isEmpty &&
            settings.overrideOfForm(id, label.key) != Override.forcedOff &&
            !_topicSwitchedOff(curriculum.formTopic(id, label.key)) &&
            !formInRange(id, label))
          curriculum.formLesson(id, label.key),
    ];
    if (unreached.isEmpty) return null;
    return _grammarGap(unreached.reduce(min), lesson);
  }

  /// [wordLesson] lifts the lesson a type is first practised with its words.
  CourseGap? typeGap(String dataFileId, String typeName, [int wordLesson = 1]) {
    if (dataFileId == 'vocab' ||
        settings.overrideOfType(dataFileId, typeName) == Override.forcedOn ||
        _topicSwitchedOff(curriculum.typeTopic(dataFileId, typeName)) ||
        typeInRange(dataFileId, typeName)) {
      return null;
    }
    return _grammarGap(curriculum.typeLesson(dataFileId, typeName), wordLesson);
  }

  CourseGap? formGap(String dataFileId, FormLabel label) {
    if (dataFileId == 'vocab' ||
        settings.overrideOfForm(dataFileId, label.key) == Override.forcedOn ||
        _topicSwitchedOff(curriculum.formTopic(dataFileId, label.key)) ||
        formInRange(dataFileId, label)) {
      return null;
    }
    return _grammarGap(curriculum.formLesson(dataFileId, label.key), 1);
  }

  CourseGap _grammarGap(int grammarLesson, int wordLesson) =>
      grammarLesson > settings.courseGrammar.to
      ? FromLesson(grammarLesson > wordLesson ? grammarLesson : wordLesson)
      : const GrammarOutsideRange();
}
