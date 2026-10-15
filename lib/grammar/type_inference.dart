/// S11: which type an item has, and how that was established.
///
/// The parser already matched the rule and stored it on the item; this library
/// holds the reading of that result the engine and the explanation need.
library;

import '../models/derivation.dart';
import 'schema.dart';

/// S11: a rule that names the item's type recognises it; a declared type
/// outside the rule's candidates stands on its own.
TypeRecognition recognizeType(GrammarItem item) {
  final rule = item.typeRule;
  if (rule == null) return const TypeDeclared();
  if (!rule.types.contains(item.typeName)) return const TypeDeclared();
  return TypeByRule(
    sourceWord: item.part(rule.part)!,
    suffix: rule.suffix,
    candidateTypes: rule.types,
  );
}

/// Whether the item's type needed `type:` to pick one candidate; the
/// explanation says so (`explain.typeByRuleAmbiguous`).
bool typeByRuleAmbiguous(GrammarItem item) =>
    recognizeType(item) is TypeByRule && item.typeRule!.isAmbiguous;
