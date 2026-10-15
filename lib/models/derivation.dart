/// How every form of a practice item follows from the dictionary form.
/// Produced while the forms are computed, so the trace can never contradict
/// the answer.
library;

/// How the item's type was established.
sealed class TypeRecognition {
  const TypeRecognition();
}

/// A `type_inference` rule produced or confirms the type.
final class TypeByRule extends TypeRecognition {
  /// `word` or `base_form`, as spelled in the YAML.
  final String sourceWord;

  /// The matched rule suffix, e.g. "us", "āre".
  final String suffix;

  /// The rule's `types`, e.g. [E-Konjugation, Mischkonjugation].
  final List<String> candidateTypes;

  const TypeByRule({
    required this.sourceWord,
    required this.suffix,
    required this.candidateTypes,
  });
}

/// Explicit `type`/`possible_types` without an agreeing rule.
final class TypeDeclared extends TypeRecognition {
  const TypeDeclared();
}

final class StemDerivation {
  /// The word the stem rule was applied to (`word` or `base_form`).
  final String sourceWord;

  /// The suffix that was cut from [sourceWord].
  final String removedSuffix;

  /// Verbs: amāre → "amo" (`reconstruction_from_alternative_stem`).
  final String? reconstructedWord;

  /// The suffix cut from [reconstructedWord], e.g. "o".
  final String? reconstructedSuffix;

  /// Macron-free, exactly the value used in the templates.
  final String stem;

  const StemDerivation({
    required this.sourceWord,
    required this.removedSuffix,
    this.reconstructedWord,
    this.reconstructedSuffix,
    required this.stem,
  }) : assert((reconstructedWord == null) == (reconstructedSuffix == null));
}

sealed class FormDerivation {
  const FormDerivation();

  String get formKey;
  String get result;
}

/// The dictionary word itself.
final class GivenForm extends FormDerivation {
  @override
  final String formKey;
  @override
  final String result;

  const GivenForm({required this.formKey, required this.result});
}

/// Built from stem plus template ending.
final class GeneratedForm extends FormDerivation {
  @override
  final String formKey;
  @override
  final String result;

  /// The template with "{stem}" removed.
  final String ending;

  const GeneratedForm({
    required this.formKey,
    required this.result,
    required this.ending,
  }) : assert(ending.length > 0);
}

/// Explicit and different from the rule, or no template at all.
final class IrregularForm extends FormDerivation {
  @override
  final String formKey;
  @override
  final String result;

  /// What the rule would have produced, if there is a rule.
  final GeneratedForm? regular;

  const IrregularForm({
    required this.formKey,
    required this.result,
    this.regular,
  });
}

/// The endings of one YAML file, shared by all its items.
final class Grammar {
  /// Resolved (`inherits_from` applied) type → form key → "{stem}" template.
  final Map<String, Map<String, String>> templatesByType;

  const Grammar(this.templatesByType);
}

final class Derivation {
  final String type;
  final TypeRecognition recognition;

  /// Null iff the type has no pattern.
  final StemDerivation? stem;

  /// Exactly the keys of `item.formOrder`, in that order.
  final Map<String, FormDerivation> forms;

  final Grammar grammar;

  Derivation({
    required this.type,
    required this.recognition,
    this.stem,
    required this.forms,
    required this.grammar,
  })  : assert(forms.entries.every((e) => e.key == e.value.formKey)),
        assert(stem != null || !forms.values.any((f) => f is GeneratedForm));
}
