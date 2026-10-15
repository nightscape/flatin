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
  throw UnimplementedError('L1 logic lane');
}
