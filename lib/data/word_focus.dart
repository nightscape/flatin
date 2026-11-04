/// The word group one round asks, chosen at its start and never stored.
library;

import '../models/course.dart';
import '../models/course_filter.dart';
import '../models/practice_item.dart';

/// The verb types whose forms the data gives by hand instead of by one of
/// the regular conjugations.
const irregularVerbTypes = {'esse-Typ', 'esse-Kompositum', 'Unregelmäßig'};

sealed class WordFocus {
  /// Unique among the focuses; two focuses with the same id are equal.
  final String id;

  const WordFocus(this.id);

  bool includes(PracticeItem word);

  /// Whether the practice opens [word] under [filter]: it is included and has
  /// something to ask.
  bool offers(PracticeItem word, CourseFilter filter) => includes(word);

  /// [practicable] with only the words of this focus, under the same keys.
  Map<String, List<PracticeItem>> narrow(
    Map<String, List<PracticeItem>> practicable,
  ) => {
    for (final MapEntry(:key, :value) in practicable.entries)
      key: [
        for (final word in value)
          if (includes(word)) word,
      ],
  };

  bool hasWords(Map<String, List<PracticeItem>> practicable) =>
      practicable.values.any((words) => words.any(includes));

  @override
  bool operator ==(Object other) => other is WordFocus && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class AllWords extends WordFocus {
  const AllWords() : super('all');

  @override
  bool includes(PracticeItem word) => true;
}

/// Every word of one data file: "Nomen" or "Verben".
final class FileFocus extends WordFocus {
  final String dataFileId;

  const FileFocus(this.dataFileId) : super(dataFileId);

  @override
  bool includes(PracticeItem word) => word.dataFileId == dataFileId;
}

final class IrregularVerbs extends WordFocus {
  const IrregularVerbs() : super('irregular');

  @override
  bool includes(PracticeItem word) =>
      word.role == DataFileRole.verb && irregularVerbTypes.contains(word.type);
}

/// Every noun and verb, asked only for its base forms
/// ([PracticeItem.baseFormKeys]).
final class BaseForms extends WordFocus {
  const BaseForms() : super('baseForms');

  @override
  bool includes(PracticeItem word) => !word.isVocab;

  /// A word whose base forms all lie outside the course range, and that has
  /// no genus to ask, waits until one of them is taught.
  @override
  bool offers(PracticeItem word, CourseFilter filter) =>
      word.genus.isNotEmpty ||
      askedBaseForms(
        word,
        filter.practicedForms(word.dataFileId, word.formLabels),
      ).isNotEmpty;
}

/// The base forms [BaseForms] asks of [word] when the course asks [practiced].
List<FormKey> askedBaseForms(PracticeItem word, Set<FormKey> practiced) =>
    word.baseFormKeys.where(practiced.contains).toList();

/// The words of one declension or conjugation type; [display] names it.
final class TypeFocus extends WordFocus {
  final String dataFileId;
  final String type;
  final String display;

  const TypeFocus(this.dataFileId, this.type, this.display)
    : super('$dataFileId:$type');

  @override
  bool includes(PracticeItem word) =>
      word.dataFileId == dataFileId && word.type == type;
}

/// The fixed groups with a [FileFocus] per grammar file, then one
/// [TypeFocus] per type that has words in [practicable], file by file, each
/// file's types sorted by name. [displayByType] names the types of each
/// grammar file; vocab has no grammar to focus on, so it is not among them.
List<WordFocus> focusesOf(
  Map<String, List<PracticeItem>> practicable,
  Map<String, Map<String, String>> displayByType,
) => [
  const AllWords(),
  for (final file in displayByType.keys) FileFocus(file),
  const IrregularVerbs(),
  for (final MapEntry(key: file, value: display) in displayByType.entries)
    ...<TypeFocus>[
      for (final type in {for (final w in practicable[file]!) w.type})
        TypeFocus(file, type, display[type]!),
    ]..sort((a, b) => a.display.compareTo(b.display)),
];
