import 'curriculum.dart';
import 'exam.dart';
import 'languages/language.dart' show Language;
import 'lesson_data.dart';
import 'analyse_form.dart';
import '../models/form_label.dart' show FormKey;

/// A data file that lists a word, with the type the item has in it.
typedef WordFile = ({String dataFileId, String type});

/// The lessons of the course that teach a word token. A part the data does
/// not name is null or empty.
typedef TokenLessons = ({
  /// Ascending. One lesson when the lists spell the lemma exactly; several
  /// when only the fold finds it and the folded words sit in different
  /// lessons.
  List<int> word,

  /// Ascending; a lesson that teaches a type and a form is in [typeAndForm]
  /// only.
  List<int> typeAndForm,
  List<int> type,
  List<int> form,

  /// Syntax topic id -> lesson.
  Map<String, int> syntax,
});

/// Where the course teaches a word, its type, its form and its syntax
/// function.
final class LessonLookup {
  final Language language;
  final LessonData lessons;
  final Curriculum curriculum;

  /// lemma -> the data files that list it.
  final Map<String, List<WordFile>> files;

  LessonLookup(this.language, this.lessons, this.curriculum, this.files);

  /// Folded spelling -> the distinct lessons of the list words that fold to
  /// it; used only when no list word has the lemma's exact spelling.
  late final Map<String, Set<int>> _foldedWordLessons = () {
    final byFold = <String, Set<int>>{};
    for (final MapEntry(:key, :value) in lessons.wordToLesson.entries) {
      (byFold[language.fold(key)] ??= {}).add(value);
    }
    return byFold;
  }();

  /// The lessons of [lemma] in each of [files], with the form that [formOf]
  /// names in that file; the distinct lessons of several files are all
  /// returned, and [TokenLessons.syntax] is empty.
  TokenLessons lessonsOf(
    String lemma,
    Iterable<WordFile> files,
    FormKey? Function(WordFile file) formOf,
  ) {
    final types = <int>{}, forms = <int>{};
    for (final file in files) {
      if (!curriculum.hasGrammar(file.dataFileId)) continue;
      final type = curriculum.typeLessonOrNull(file.dataFileId, file.type);
      if (type != null) types.add(type);
      final key = formOf(file);
      final form = key == null
          ? null
          : curriculum.formLessonOrNull(file.dataFileId, key);
      if (form != null) forms.add(form);
    }
    List<int> sorted(Iterable<int> xs) => xs.toList()..sort();
    final exactWord = lessons.wordToLesson[lemma];
    final both = types.intersection(forms);
    return (
      word: sorted(
        exactWord != null
            ? [exactWord]
            : _foldedWordLessons[language.fold(lemma)] ?? const <int>{},
      ),
      typeAndForm: sorted(both),
      type: sorted(types.difference(both)),
      form: sorted(forms.difference(both)),
      syntax: const {},
    );
  }

  /// A lemma in several data files has one type and one form per file.
  TokenLessons of(WordToken token, Clause clause) {
    final byForm = lessonsOf(
      token.lemma,
      files[token.lemma] ?? const <WordFile>[],
      (file) => formKeyOfAnalyse(
        curriculum.labelsOf(file.dataFileId),
        token.analyse.codes,
      ),
    );
    final syntax = <String, int>{};
    for (final id in [
      for (final MapEntry(:key, :value) in token.analyse.codes.entries)
        'analyse.$key.$value',
      'clause.art.${clause.art}',
    ]) {
      final lesson = curriculum.syntaxLessonOrNull(id);
      if (lesson != null) syntax[id] = lesson;
    }
    return (
      word: byForm.word,
      typeAndForm: byForm.typeAndForm,
      type: byForm.type,
      form: byForm.form,
      syntax: syntax,
    );
  }
}
