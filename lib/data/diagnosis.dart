import '../models/derivation.dart';
import '../models/practice_item.dart';

/// What a wrong answer is, as far as the item's own derivation can tell.
sealed class Diagnosis {
  const Diagnosis();
}

/// The answer is the regular form of a form that is irregular here.
final class RegularInsteadOfIrregular extends Diagnosis {
  const RegularInsteadOfIrregular();
}

/// The answer is another form of the same word.
final class OtherFormOfWord extends Diagnosis {
  /// The matching keys, in `form_order` order.
  final List<FormKey> formKeys;

  const OtherFormOfWord(this.formKeys);
}

/// Own stem, but the ending another type uses for this form key.
final class EndingOfOtherType extends Diagnosis {
  /// The matching types, in YAML order.
  final List<String> types;

  const EndingOfOtherType(this.types);
}

/// The ending the asked form uses, but on another stem.
final class WrongStem extends Diagnosis {
  final String usedStem;

  /// The item-level name of the stem the form is built on.
  final String stemName;

  const WrongStem(this.usedStem, this.stemName);
}

final class NoMatch extends Diagnosis {
  const NoMatch();
}

/// Classifies a wrong [answer] for [formKey] of [item].
///
/// Precondition: [answer] is non-empty and no accepted spelling of [formKey]
/// matches it ([PracticeItem.accepts]). An answer that differs only in
/// quantity marks is correct (Q11 A) and gets [explainCorrectAnswer] instead.
Diagnosis diagnose(PracticeItem item, FormKey formKey, String answer) {
  final int index = item.formOrder.indexOf(formKey);
  assert(index >= 0, '"$formKey" is not a form of "${item.translation}"');
  assert(answer.trim().isNotEmpty);
  assert(!item.accepts(index, answer), 'a correct answer has no diagnosis');

  final String given = norm(answer);
  final derivation = item.derivation;
  final asked = derivation.forms[formKey]!;

  if (asked is IrregularForm &&
      asked.regular != null &&
      asked.regular!.variants.any((spelling) => norm(spelling) == given)) {
    return const RegularInsteadOfIrregular();
  }

  final otherKeys = [
    for (int j = 0; j < item.formOrder.length; j++)
      if (j != index && item.accepts(j, answer)) item.formOrder[j],
  ];
  if (otherKeys.isNotEmpty) return OtherFormOfWord(otherKeys);

  final types = [
    for (final entry in derivation.grammar.templatesByType.entries)
      if (entry.key != derivation.type &&
          _otherTypeForm(derivation, entry.value[formKey]) == given)
        entry.key,
  ];
  if (types.isNotEmpty) return EndingOfOtherType(types);

  if (asked is GeneratedForm) {
    final String ending = norm(asked.ending);
    if (given.endsWith(ending)) {
      final usedStem = given.substring(0, given.length - ending.length);
      final stem = derivation.stems[asked.stemName]!;
      if (usedStem.isNotEmpty && usedStem != norm(stem.stem)) {
        return WrongStem(usedStem, asked.stemName);
      }
    }
  }

  return const NoMatch();
}

/// The shown spelling [template] would give on this item's stems, normalized;
/// null when the item has no stem of the template's name.
String? _otherTypeForm(Derivation derivation, Template? template) {
  if (template == null) return null;
  final String? stemName = template.stemName;
  if (stemName == null) return norm(template.endings.first);
  final stem = derivation.stems[stemName];
  if (stem == null) return null;
  return norm(stem.stem + template.endings.first);
}
