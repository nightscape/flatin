import '../../data/exam.dart';
import '../../data/languages/language.dart';

/// Whether [input] fills the gap of [item]: it equals one reading of one
/// answer variant after both go through the language's answer rules.
bool gapAccepts(Language language, LueckeItem item, String input) {
  final given = normalizeAnswer(language, input);
  return item.antworten.any(
    (variant) => expand(
      variant,
    ).any((reading) => normalizeAnswer(language, reading) == given),
  );
}
