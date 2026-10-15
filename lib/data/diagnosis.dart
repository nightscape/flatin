import '../models/derivation.dart';
import '../models/practice_item.dart';

/// What a wrong answer is, as far as the item's own derivation can tell.
sealed class Diagnosis {
  const Diagnosis();
}

/// `norm(answer) == norm(correct)`: only the macrons differ.
final class OnlyDiacritics extends Diagnosis {
  const OnlyDiacritics();
}

/// The answer is the regular form of a form that is irregular here.
final class RegularInsteadOfIrregular extends Diagnosis {
  const RegularInsteadOfIrregular();
}

/// The answer is another form of the same word.
final class OtherFormOfWord extends Diagnosis {
  /// The matching keys, in `form_order` order.
  final List<String> formKeys;

  const OtherFormOfWord(this.formKeys);
}

/// Own stem, but the ending another type uses for this form key.
final class EndingOfOtherType extends Diagnosis {
  /// The matching types, in YAML order.
  final List<String> types;

  const EndingOfOtherType(this.types);
}

/// Own ending, but another stem.
final class WrongStem extends Diagnosis {
  final String usedStem;

  const WrongStem(this.usedStem);
}

final class NoMatch extends Diagnosis {
  const NoMatch();
}

/// Classifies a wrong [answer] for [formKey] of [item].
///
/// Precondition: [answer] is non-empty and counts as wrong by the screen's
/// check (`answer.trim().toLowerCase() != correct.toLowerCase()`).
Diagnosis diagnose(PracticeItem item, String formKey, String answer) {
  final int index = item.formOrder.indexOf(formKey);
  assert(index >= 0, '"$formKey" is not a form of "${item.translation}"');
  final String correct = item.forms[index];
  assert(answer.trim().isNotEmpty);
  assert(answer.trim().toLowerCase() != correct.toLowerCase());

  final String given = norm(answer);
  final derivation = item.derivation;

  if (given == norm(correct)) return const OnlyDiacritics();

  final asked = derivation.forms[formKey]!;
  if (asked is IrregularForm &&
      asked.regular != null &&
      given == norm(asked.regular!.result)) {
    return const RegularInsteadOfIrregular();
  }

  final otherKeys = [
    for (int j = 0; j < item.formOrder.length; j++)
      if (j != index && norm(item.forms[j]) == given) item.formOrder[j],
  ];
  if (otherKeys.isNotEmpty) return OtherFormOfWord(otherKeys);

  final stem = derivation.stem;
  if (stem != null) {
    final types = [
      for (final entry in derivation.grammar.templatesByType.entries)
        if (entry.key != derivation.type &&
            entry.value[formKey] != null &&
            norm(entry.value[formKey]!.replaceAll('{stem}', stem.stem)) ==
                given)
          entry.key,
    ];
    if (types.isNotEmpty) return EndingOfOtherType(types);

    if (asked is GeneratedForm) {
      final ending = norm(asked.ending);
      if (given.endsWith(ending)) {
        final usedStem = given.substring(0, given.length - ending.length);
        if (usedStem.isNotEmpty && usedStem != stem.stem) {
          return WrongStem(usedStem);
        }
      }
    }
  }

  return const NoMatch();
}
