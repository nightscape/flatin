import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/languages/language.dart' show Language;
import '../data/practice_data.dart';
import '../data/token_lessons.dart';
import '../models/form_label.dart' show FormKey;
import 'exam_provider.dart';
import 'locale_provider.dart';

part 'lookup_provider.g.dart';

/// One reading of a spelling: the item that has it and the form it is there.
/// [form] and [formName] are null for a word with no form of its own
/// (a phrase or an indeclinable word).
typedef WordAnalysis = ({
  String spelling,
  String lemma,
  String meaning,
  WordFile file,
  FormKey? form,
  String? formName,
});

/// Every generated form of every item of the active course, by its spelling
/// folded as the course language folds it.
final class FormIndex {
  final Language language;
  final Map<String, List<WordAnalysis>> _byFold;

  FormIndex(this.language, this._byFold);

  /// The readings of [text], in course order: those forms that spell it up to
  /// case and quantity marks.
  List<WordAnalysis> find(String text) =>
      _byFold[language.foldLower(text.trim())] ?? const [];
}

/// The [FormIndex] of the active course; a course switch rebuilds it.
@riverpod
Future<FormIndex> formIndex(Ref ref) async {
  final language = await ref.watch(courseLanguageProvider.future);
  final items = await loadAllPracticeItems(
    language: await ref.watch(dataLanguageProvider.future),
  );
  final index = <String, List<WordAnalysis>>{};
  for (final item in items) {
    for (final (i, spelling) in item.forms.indexed) {
      final label = item.formLabels[i];
      (index[language.foldLower(spelling)] ??= []).add((
        spelling: spelling,
        lemma: item.lemma,
        meaning: item.translation,
        file: (dataFileId: item.dataFileId, type: item.type),
        form: item.isVocab ? null : label.key,
        formName: item.isVocab ? null : label.displayName,
      ));
    }
  }
  return FormIndex(language, index);
}
