/// How every form of a practice item follows from its principal parts.
/// Produced while the forms are computed, so the trace can never contradict
/// the answer.
library;

import '../data/lesson_data.dart' show normalizeDiacritics;
import 'form_label.dart' show FormKey;

/// The comparison form of a Latin word: trimmed, lower case, macron-free.
String norm(String text) => normalizeDiacritics(text.trim().toLowerCase());

/// How the item's type was established.
sealed class TypeRecognition {
  const TypeRecognition();
}

/// A `type_inference` rule produced or confirms the type.
final class TypeByRule extends TypeRecognition {
  /// The spelling the rule matched.
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

/// A sound rule that fires at a stem seam (S16).
final class SandhiRule {
  final String id;

  /// The German text the explanation shows, e.g. "ā fällt vor Vokal aus".
  final String explain;

  const SandhiRule({required this.id, required this.explain});
}

/// One named stem of an item, e.g. "praesens" = amā-.
sealed class StemDerivation {
  /// The item-level stem name, e.g. "perfekt".
  final String name;

  /// The shown spelling; `variants.first`.
  final String stem;

  /// What the stem is called to the learner, e.g. "Perfektstamm".
  final String display;

  /// All spellings of this stem (S9); the first is [stem].
  final List<String> variants;

  StemDerivation({
    required this.name,
    required this.display,
    required this.variants,
  }) : stem = variants.first,
       assert(variants.isNotEmpty),
       assert(
         variants.map(norm).toSet().length == variants.length,
         'stem $name: two variants differ only in quantity marks',
       );
}

/// Cut from a principal part the item gives (S3).
final class StemFromPart extends StemDerivation {
  /// The name of the principal part the stem was cut from.
  final String part;

  /// The part's first spelling.
  final String sourceWord;

  /// The entry of `remove` that matched [sourceWord].
  final String removedSuffix;

  StemFromPart({
    required super.name,
    required super.display,
    required super.variants,
    required this.part,
    required this.sourceWord,
    required this.removedSuffix,
  });
}

/// Built from another stem by a template, e.g. praesens = `{wurzel}ā` (S18 b).
final class StemFromDefault extends StemDerivation {
  final String template;
  final StemDerivation base;

  /// The rule that fired at the `{base}`/rest seam, if any.
  final SandhiRule? sandhiRule;

  StemFromDefault({
    required super.name,
    required super.display,
    required super.variants,
    required this.template,
    required this.base,
    this.sandhiRule,
  });
}

sealed class FormDerivation {
  final FormKey formKey;

  /// The shown spelling; `variants.first`.
  final String result;

  /// Every accepted spelling (S9); the first is [result].
  final List<String> variants;

  FormDerivation({required this.formKey, required this.variants})
    : result = variants.first,
      assert(variants.isNotEmpty),
      assert(
        variants.map(norm).toSet().length == variants.length,
        'form $formKey: two variants differ only in quantity marks',
      );
}

/// A principal part the item gives, shown as it stands.
final class GivenForm extends FormDerivation {
  GivenForm({required super.formKey, required super.variants});
}

/// Stem plus template ending.
final class GeneratedForm extends FormDerivation {
  /// The item-level stem name after `bind`: "ppp", not the target's "stamm".
  final String stemName;

  /// The template with "{stemName}" removed; may be empty (S2).
  final String ending;

  /// The type that wrote the template; differs from the item's type under
  /// delegation and inheritance.
  final String endingType;

  /// The rule that fired at the stem/ending seam of [result] (S18 a).
  final SandhiRule? sandhiRule;

  GeneratedForm({
    required super.formKey,
    required super.variants,
    required this.stemName,
    required this.ending,
    required this.endingType,
    this.sandhiRule,
  });
}

/// Several forms joined, e.g. amātus + est (S13).
final class ComposedForm extends FormDerivation {
  final List<FormPart> parts;

  /// The text after each part but the last (S21).
  final List<String> joins;

  ComposedForm({
    required super.formKey,
    required super.variants,
    required this.parts,
    required this.joins,
  }) : assert(parts.isNotEmpty && joins.length == parts.length - 1);

  /// The parts' texts with their separators.
  String get joinedText => [
    for (var i = 0; i < parts.length; i++) ...[
      parts[i].text,
      if (i < joins.length) joins[i],
    ],
  ].join();
}

/// Explicit and different from the rule, or no rule at all.
final class IrregularForm extends FormDerivation {
  /// What the rules give for this key, if they give anything.
  final FormDerivation? regular;

  IrregularForm({required super.formKey, required super.variants, this.regular})
    : assert(
        regular == null ||
            (regular.formKey == formKey && regular.result != variants.first),
        'the regular derivation must be another spelling of the same key',
      );
}

/// One piece of a [ComposedForm].
sealed class FormPart {
  String get text;
}

/// A stem used as an affix, e.g. "pos" from "pot" by rule t_s.
final class AffixPart extends FormPart {
  final String stemName;

  @override
  final String text;

  /// The rule that fired at the seam to the next part (S18 c).
  final SandhiRule? sandhiRule;

  /// S18: false when the seam after the part takes no sandhi.
  final bool sandhi;

  AffixPart({
    required this.stemName,
    required this.text,
    required this.sandhi,
    this.sandhiRule,
  });
}

/// A form of an item, either another one or the composing item itself.
final class LexemeFormPart extends FormPart {
  /// The composing item's own id for a `self:` part.
  final String lexemeId;

  /// For a `self:` part the delegated key after the delegate's `set`.
  final FormKey key;

  final FormDerivation derivation;

  LexemeFormPart({
    required this.lexemeId,
    required this.key,
    required this.derivation,
  });

  @override
  String get text => derivation.result;
}

/// One form template of a type: a stem name and the spellings of its ending.
final class Template {
  /// Null for a literal template.
  final String? stemName;

  /// The endings, first = shown.
  final List<String> endings;

  const Template({this.stemName, required this.endings});
}

/// The templates of one YAML file, shared by all its items.
final class Grammar {
  /// Type → form key → template. A type that inherits keeps only the endings
  /// it changes, so a diagnosis names the parent rather than both.
  final Map<String, Map<FormKey, Template>> templatesByType;

  /// S19: concrete type → its word class. Abstract types are absent.
  final Map<String, String> classByType;

  /// S20: concrete type → what the learner reads for it, in [language].
  final Map<String, String> displayByType;

  final String language;

  const Grammar(
    this.templatesByType,
    this.classByType,
    this.displayByType,
    this.language,
  );
}

final class Derivation {
  final String type;
  final TypeRecognition recognition;

  /// The item's named stems; empty when the type has no pattern.
  final Map<String, StemDerivation> stems;

  /// Exactly the keys of `item.formOrder`, in that order.
  final Map<FormKey, FormDerivation> forms;

  /// Keys moved from a passive key to the active one (S10).
  final Set<FormKey> deponentKeys;

  /// S10: the item is deponent in every tempus (`deponent: all`), not only in
  /// some. A semi-deponent keeps the passive keys the move leaves alone.
  final bool fullDeponent;

  /// Forms with `emit: false` (S8): for compositions and the oracle, never
  /// practised.
  final Map<FormKey, FormDerivation> internal;

  final Grammar grammar;

  Derivation({
    required this.type,
    required this.recognition,
    this.stems = const {},
    required this.forms,
    this.deponentKeys = const {},
    this.fullDeponent = false,
    this.internal = const {},
    required this.grammar,
  }) : assert(forms.entries.every((e) => e.key == e.value.formKey)),
       assert(
         stems.entries.every((e) => e.key == e.value.name),
         'a stem is filed under another name than its own',
       ),
       // I5: no stem, no generated or composed form.
       assert(
         stems.isNotEmpty ||
             !forms.values.any(
               (f) =>
                   f is GeneratedForm ||
                   (f is ComposedForm && f.parts.any((p) => p is AffixPart)),
             ),
       ),
       // I2, as far as it holds without the sandhi function: a seam rule may
       // change the stem, so only a rule-free seam concatenates exactly.
       assert(
         forms.values.every(
           (f) => switch (f) {
             GeneratedForm(sandhiRule: final rule) when rule != null => true,
             GeneratedForm(:final stemName, :final ending, :final result) =>
               norm(stems[stemName]!.stem + ending) == norm(result),
             _ => true,
           },
         ),
       );
}
