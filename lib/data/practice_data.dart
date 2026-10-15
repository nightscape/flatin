import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../grammar/schema.dart' show parseAxes;
import '../models/derivation.dart';
import '../models/practice_item.dart';
import 'lesson_data.dart' show normalizeDiacritics;

/// The one stem the v1 loader knows. The engine of L1 names several.
const _stemName = 'stamm';
const _stemDisplay = 'Stamm';

/// Form metadata extracted from YAML
class FormMetadata {
  final List<String> formOrder;
  final Map<String, FormLabel> formLabelsByKey;
  final Axes axes;
  final String? dataFileId;
  final String? defaultWordForm;
  final List<String>? typeInferenceRuleSets;
  final List<String> availableTypes;

  FormMetadata({
    required this.formOrder,
    required this.formLabelsByKey,
    required this.axes,
    this.dataFileId,
    this.defaultWordForm,
    this.typeInferenceRuleSets,
    this.availableTypes = const [],
  });
}

/// Convert YamlMap to Map
Map<String, dynamic> _yamlMapToMap(YamlMap yamlMap) {
  return Map<String, dynamic>.from(
    yamlMap.map((key, value) {
      if (value is YamlMap) {
        return MapEntry(key.toString(), _yamlMapToMap(value));
      } else if (value is YamlList) {
        return MapEntry(
          key.toString(),
          value.map((e) {
            if (e is YamlMap) {
              return _yamlMapToMap(e);
            }
            return e;
          }).toList(),
        );
      }
      return MapEntry(key.toString(), value);
    }),
  );
}

/// Extract form metadata from a YAML file without loading all items
Future<FormMetadata> getFormMetadata(String assetPath) async {
  final String yamlString = await rootBundle.loadString(assetPath);
  final yaml = loadYaml(yamlString) as YamlMap;
  final Map<String, dynamic> yamlMap = _yamlMapToMap(yaml);

  final axes = parseAxes(yaml, path: assetPath);
  final Map<String, FormLabel> formLabelsByKey =
      (yamlMap['form_labels'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          FormLabel(
            features: {
              for (final feature in (value as Map<String, dynamic>).entries)
                feature.key: '${feature.value}',
            },
            axes: axes,
          ),
        ),
      );

  // Extract form order from top level
  final List<dynamic> formOrderList = yamlMap['form_order'] as List<dynamic>;
  final List<String> formOrder = formOrderList.map((v) => v as String).toList();

  // Extract data file identifier (required)
  final String? dataFileIdValue = yamlMap['data_file_id'] as String?;
  if (dataFileIdValue == null || dataFileIdValue.isEmpty) {
    throw Exception(
      'YAML file "$assetPath" must specify "data_file_id" at the top level.',
    );
  }
  final String dataFileId = dataFileIdValue;

  // Extract defaults
  final Map<String, dynamic>? defaultsMap =
      yamlMap['defaults'] as Map<String, dynamic>?;
  final String? defaultWordForm = defaultsMap?['word_form'] as String?;

  // Extract type inference rule set names from type_inference structure
  final Map<String, dynamic>? typeInferenceRules =
      yamlMap['type_inference'] as Map<String, dynamic>?;
  final List<String>? typeInferenceRuleSets = typeInferenceRules?.keys.toList();

  // Collect all available types from type_patterns and items
  final Set<String> typeSet = {};
  final Map<String, dynamic>? typePatternsMap =
      yamlMap['type_patterns'] as Map<String, dynamic>?;
  if (typePatternsMap != null) {
    typeSet.addAll(typePatternsMap.keys);
  }
  final List<dynamic>? itemsList = yamlMap['items'] as List<dynamic>?;
  if (itemsList != null) {
    for (final itemData in itemsList) {
      final item = itemData as Map<String, dynamic>;
      final type = item['type'] as String?;
      if (type != null) typeSet.add(type);
    }
  }
  final availableTypes = typeSet.toList()..sort();

  return FormMetadata(
    formOrder: formOrder,
    formLabelsByKey: formLabelsByKey,
    axes: axes,
    dataFileId: dataFileId,
    defaultWordForm: defaultWordForm,
    typeInferenceRuleSets: typeInferenceRuleSets,
    availableTypes: availableTypes,
  );
}

/// Extract stem from a word based on pattern definition, with the suffix that
/// was cut off.
({String stem, String removedSuffix}) _extractStem(String word, String pattern) {
  // Pattern format: "remove_suffix:suffix1,suffix2,..."
  assert(pattern.startsWith('remove_suffix:'), 'unknown stem rule "$pattern"');
  final suffixes = pattern.substring('remove_suffix:'.length).split(',');
  final normalizedWord = normalizeDiacritics(word);

  // Sort suffixes by length (longest first) to match longer suffixes before shorter ones
  // This ensures "āre" is matched before "re" for words like "intrāre"
  final sortedSuffixes = suffixes.toList()
    ..sort((a, b) {
      final normA = normalizeDiacritics(a);
      final normB = normalizeDiacritics(b);
      return normB.length.compareTo(normA.length); // Descending order
    });

  for (final suffix in sortedSuffixes) {
    final normalizedSuffix = normalizeDiacritics(suffix);
    if (normalizedWord.endsWith(normalizedSuffix)) {
      // Use the original suffix length (not normalized) to determine how many characters to remove
      // This correctly handles macrons: "āre" is 3 chars, "re" is 2 chars
      final suffixLength = suffix.length;
      if (word.length >= suffixLength) {
        return (
          stem: word.substring(0, word.length - suffixLength),
          removedSuffix: suffix,
        );
      }
    }
  }
  throw StateError('Stem rule "$pattern" matches no suffix of "$word"');
}

/// Generate a form from a stem using a pattern template
String _generateForm(String stem, String template) {
  return template.replaceAll('{stem}', stem);
}

/// The `type_inference` rule that a word matched.
typedef RuleMatch = ({String sourceWord, String suffix, List<String> types});

/// Generic type inference using rules from YAML
/// Returns the first matching rule, or null if no rule matches [word]
/// [ruleSet] specifies which rule set to check (if null, checks all available rule sets)
/// [availableRuleSets] is the list of rule set names available in the YAML
RuleMatch? _inferTypesFromRules(
  String word,
  Map<String, dynamic>? typeInferenceRules,
  List<String>? availableRuleSets, {
  String? ruleSet,
}) {
  if (typeInferenceRules == null || availableRuleSets == null) return null;

  // Determine which rule sets to check
  final List<String> ruleSetsToCheck;
  if (ruleSet != null) {
    // Check specific rule set if provided
    ruleSetsToCheck = availableRuleSets.contains(ruleSet) ? [ruleSet] : [];
  } else {
    // Check all available rule sets in order
    ruleSetsToCheck = availableRuleSets;
  }

  // Check each rule set in order
  for (final ruleSetName in ruleSetsToCheck) {
    final List<dynamic>? rules =
        typeInferenceRules[ruleSetName] as List<dynamic>?;
    if (rules == null) continue;

    for (final ruleData in rules) {
      final Map<String, dynamic> rule = ruleData as Map<String, dynamic>;
      final String suffix = rule['suffix'] as String;
      final int? minLength = rule['min_length'] as int?;
      final List<dynamic> ruleTypes = rule['types'] as List<dynamic>;

      // Check if word matches this rule (normalize diacritics for comparison)
      final normalizedWord = normalizeDiacritics(word);
      final normalizedSuffix = normalizeDiacritics(suffix);
      if (normalizedWord.endsWith(normalizedSuffix)) {
        if (minLength == null || word.length >= minLength) {
          // First match wins for this rule set
          return (
            sourceWord: word,
            suffix: suffix,
            types: ruleTypes.map((t) => t as String).toList(),
          );
        }
      }
    }
  }

  return null;
}

/// The item's possible types and, if a `type_inference` rule fired, that rule.
///
/// The rules run even when the item declares its types, so the trace can tell
/// whether a rule agrees with the declared type.
({List<String>? possibleTypes, RuleMatch? ruleMatch}) _recognizeType(
  Map<String, dynamic> item,
  Map<String, dynamic>? typeInferenceRules,
  List<String>? typeInferenceRuleSets,
) {
  final String? word = item['word'] as String?;
  final String? baseForm = item['base_form'] as String?;

  RuleMatch? ruleMatch;
  if (typeInferenceRules != null && typeInferenceRuleSets != null) {
    // Determine which fields to check based on available rule sets
    // If we have a single rule set (like 'rules'), check 'word' field
    // If we have multiple rule sets (like 'infinitive_rules', 'first_person_rules'),
    // check 'base_form' first, then 'word'
    if (typeInferenceRuleSets.length == 1) {
      if (word != null) {
        ruleMatch = _inferTypesFromRules(
          word,
          typeInferenceRules,
          typeInferenceRuleSets,
        );
      }
    } else {
      // Rule set names indicate which field to check
      // (e.g. 'infinitive_rules' -> base_form, 'first_person_rules' -> word)
      if (baseForm != null) {
        final infinitiveRuleSet = typeInferenceRuleSets.firstWhere(
          (rs) => rs.contains('infinitive') || rs.contains('base'),
          orElse: () => typeInferenceRuleSets.first,
        );
        ruleMatch = _inferTypesFromRules(
          baseForm,
          typeInferenceRules,
          typeInferenceRuleSets,
          ruleSet: infinitiveRuleSet,
        );
      }
      if (ruleMatch == null && word != null) {
        final wordRuleSet = typeInferenceRuleSets.firstWhere(
          (rs) =>
              rs.contains('first_person') ||
              rs.contains('word') ||
              rs.contains('person'),
          orElse: () => typeInferenceRuleSets.last,
        );
        ruleMatch = _inferTypesFromRules(
          word,
          typeInferenceRules,
          typeInferenceRuleSets,
          ruleSet: wordRuleSet,
        );
      }
    }
  }

  final List<dynamic>? declared = item['possible_types'] as List<dynamic>?;
  if (declared != null) {
    return (
      possibleTypes: declared.map((v) => v as String).toList(),
      ruleMatch: ruleMatch,
    );
  }
  return (possibleTypes: ruleMatch?.types, ruleMatch: ruleMatch);
}

/// Resolve a type pattern, following inherits_from chains
Map<String, dynamic>? _resolvePattern(
  String type,
  Map<String, dynamic> typePatterns,
) {
  final Map<String, dynamic>? pattern =
      typePatterns[type] as Map<String, dynamic>?;
  if (pattern == null) return null;

  final String? parentType = pattern['inherits_from'] as String?;
  if (parentType == null) return pattern;

  final Map<String, dynamic>? parentPattern =
      _resolvePattern(parentType, typePatterns);
  if (parentPattern == null) return pattern;

  // Parent first, then child overrides
  return {...parentPattern, ...pattern};
}

/// The template [type]'s parent chain gives for [formKey], if any.
String? _inheritedTemplate(
  String type,
  String formKey,
  Map<String, dynamic> typePatterns,
) {
  final pattern = typePatterns[type] as Map<String, dynamic>?;
  final parentType = pattern?['inherits_from'] as String?;
  if (parentType == null) return null;
  return _resolvePattern(parentType, typePatterns)?[formKey] as String?;
}

/// The type in [type]'s chain whose own pattern declares [formKey].
String _templateOwner(
  String type,
  String formKey,
  Map<String, dynamic> typePatterns,
) {
  final pattern = typePatterns[type] as Map<String, dynamic>?;
  if (pattern != null && pattern.containsKey(formKey)) return type;
  final parentType = pattern?['inherits_from'] as String?;
  assert(parentType != null, 'no type above $type declares $formKey');
  return _templateOwner(parentType!, formKey, typePatterns);
}

/// Infer forms for an item based on type patterns
/// [defaultWordForm] is the form key that the 'word' field represents (e.g., 'nominative_singular', 'first_person_singular')
/// This function is public to allow testing inference logic.
Map<String, String> inferForms(
  Map<String, dynamic> item,
  Map<String, dynamic> typePatterns,
  List<String> formOrder,
  String? defaultWordForm,
) =>
    deriveForms(item, typePatterns, formOrder, defaultWordForm).forms;

/// Infer forms for an item and record how each one was built.
///
/// [generated] holds a [GeneratedForm] for every key that a template produced;
/// the word form itself and keys without a template are absent.
({
  Map<String, String> forms,
  StemDerivation? stem,
  Map<String, GeneratedForm> generated,
}) deriveForms(
  Map<String, dynamic> item,
  Map<String, dynamic> typePatterns,
  List<String> formOrder,
  String? defaultWordForm,
) {
  const empty = (
    forms: <String, String>{},
    stem: null,
    generated: <String, GeneratedForm>{},
  );

  final String type = item['type'] as String;
  final Map<String, dynamic>? pattern = _resolvePattern(type, typePatterns);

  if (pattern == null) {
    return empty;
  }

  // Determine which form the 'word' field represents
  final String? wordForm = defaultWordForm;
  if (wordForm == null) {
    // Cannot infer forms without knowing what 'word' represents
    return empty;
  }

  StemDerivation? stem;
  String? baseWord = item['word'] as String?;
  String? baseForm = item['base_form'] as String?;

  // Try to extract stem from 'word' field first
  if (baseWord != null) {
    final String stemPattern = pattern['stem_extraction'] as String? ?? '';
    if (stemPattern.isNotEmpty) {
      final cut = _extractStem(baseWord, stemPattern);
      stem = StemFromPart(
        name: _stemName,
        display: _stemDisplay,
        variants: [normalizeDiacritics(cut.stem)],
        part: wordForm,
        sourceWord: baseWord,
        removedSuffix: cut.removedSuffix,
      );
    }
  }

  // If no stem from 'word', try 'base_form' with alternative stem extraction
  if (stem == null && baseForm != null) {
    // Check for alternative stem extraction pattern (e.g., infinitive_stem_extraction)
    // Look for any pattern key ending with '_stem_extraction' that isn't 'stem_extraction'
    String? alternativeStemPattern;
    for (final key in pattern.keys) {
      if (key.toString().endsWith('_stem_extraction') &&
          key.toString() != 'stem_extraction') {
        alternativeStemPattern = pattern[key] as String?;
        break;
      }
    }

    if (alternativeStemPattern != null && alternativeStemPattern.isNotEmpty) {
      final altCut = _extractStem(baseForm, alternativeStemPattern);
      // Normalize the alternative stem to remove diacritics
      final String alternativeStem = normalizeDiacritics(altCut.stem);

      // Try to reconstruct the base word from the alternative stem
      // This is pattern-specific: for verbs, infinitive stem + 'o' = first person singular
      // We check if there's a reconstruction pattern in the pattern definition
      final String? reconstructionPattern =
          pattern['reconstruction_from_alternative_stem'] as String?;
      if (reconstructionPattern != null) {
        baseWord = reconstructionPattern.replaceAll('{stem}', alternativeStem);
        // A pattern that reconstructs the word form always cuts the stem again
        final cut = _extractStem(baseWord, pattern['stem_extraction'] as String);
        final String finalStem = normalizeDiacritics(cut.stem);
        // The detour over the reconstructed word form only shortens the first
        // cut, so the result still reads as one cut from the base form.
        assert(
          normalizeDiacritics(baseForm).startsWith(finalStem),
          'the stem "$finalStem" is no prefix of "$baseForm"',
        );
        stem = StemFromPart(
          name: _stemName,
          display: _stemDisplay,
          variants: [finalStem],
          part: 'base_form',
          sourceWord: baseForm,
          removedSuffix: baseForm.substring(finalStem.length),
        );
      } else {
        // The alternative stem is the stem (consonant declension: regis → reg)
        stem = StemFromPart(
          name: _stemName,
          display: _stemDisplay,
          variants: [alternativeStem],
          part: 'base_form',
          sourceWord: baseForm,
          removedSuffix: altCut.removedSuffix,
        );
      }
    }
  }

  if (stem == null || baseWord == null) return empty;

  // Build forms map starting with the word form
  final Map<String, String> forms = {wordForm: baseWord};
  final Map<String, GeneratedForm> generated = {};

  // Generate other forms from pattern
  for (final formKey in formOrder) {
    if (formKey == wordForm) continue;

    final String? template = pattern[formKey] as String?;
    if (template != null) {
      final String result = _generateForm(stem.stem, template);
      forms[formKey] = result;
      generated[formKey] = GeneratedForm(
        formKey: formKey,
        variants: [result],
        stemName: _stemName,
        ending: template.replaceAll('{stem}', ''),
        endingType: _templateOwner(type, formKey, typePatterns),
      );
    }
  }

  return (forms: forms, stem: stem, generated: generated);
}

/// How [result], the final value of [formKey], came about.
///
/// An explicit value that the rule also produces stays a [GeneratedForm]: the
/// rule explains it.
FormDerivation _classifyForm(
  String formKey,
  String result,
  String? wordForm,
  GeneratedForm? generated,
) {
  if (formKey == wordForm) {
    return GivenForm(formKey: formKey, variants: [result]);
  }
  if (generated != null && norm(result) == norm(generated.result)) {
    return GeneratedForm(
      formKey: formKey,
      variants: [result],
      stemName: generated.stemName,
      ending: generated.ending,
      endingType: generated.endingType,
    );
  }
  return IrregularForm(
    formKey: formKey,
    variants: [result],
    regular: generated,
  );
}

/// Load practice items from a YAML file
Future<List<PracticeItem>> loadPracticeItems(String assetPath) async {
  final String yamlString = await rootBundle.loadString(assetPath);
  final yaml = loadYaml(yamlString) as YamlMap;
  final Map<String, dynamic> yamlMap = _yamlMapToMap(yaml);

  final Map<String, FormLabel> formLabelsByKey =
      (await getFormMetadata(assetPath)).formLabelsByKey;

  // Extract form order from top level
  final List<dynamic> formOrderList = yamlMap['form_order'] as List<dynamic>;
  final List<String> formOrder = formOrderList.map((v) => v as String).toList();

  // Extract type patterns from top level (if present)
  final Map<String, dynamic>? typePatternsMap =
      yamlMap['type_patterns'] as Map<String, dynamic>?;
  final Map<String, dynamic> typePatterns = typePatternsMap ?? {};

  // Extract type inference rules from top level (if present)
  final Map<String, dynamic>? typeInferenceRules =
      yamlMap['type_inference'] as Map<String, dynamic>?;
  final List<String>? typeInferenceRuleSets = typeInferenceRules?.keys.toList();

  // Extract defaults from top level (if present)
  final Map<String, dynamic>? defaultsMap =
      yamlMap['defaults'] as Map<String, dynamic>?;
  final String? defaultWordForm = defaultsMap?['word_form'] as String?;
  final String? defaultBaseFormLabel =
      defaultsMap?['base_form_label'] as String?;

  // Get data file identifier (required)
  final String? dataFileIdValue = yamlMap['data_file_id'] as String?;
  if (dataFileIdValue == null || dataFileIdValue.isEmpty) {
    throw Exception(
      'YAML file "$assetPath" must specify "data_file_id" at the top level.',
    );
  }
  final String dataFileId = dataFileIdValue;

  // The endings of this file: resolved templates per type, practised keys only.
  // A type that inherits keeps only the endings it changes, so a diagnosis
  // names the parent rule instead of both (R1).
  final grammar = Grammar({
    for (final type in typePatterns.keys)
      type: {
        for (final entry in (_resolvePattern(type, typePatterns) ?? const {})
            .entries)
          if (formOrder.contains(entry.key) &&
              entry.value is String &&
              (entry.value as String).contains('{stem}') &&
              entry.value != _inheritedTemplate(type, entry.key, typePatterns))
            entry.key: Template(
              stemName: _stemName,
              endings: [(entry.value as String).replaceAll('{stem}', '')],
            ),
      },
  });

  // Extract items
  final List<dynamic> itemsList = yamlMap['items'] as List<dynamic>;

  return itemsList.map((itemData) {
    final Map<String, dynamic> item = itemData as Map<String, dynamic>;

    // Infer possible_types from word ending if not provided
    String? word = item['word'] as String?;
    final String? baseForm = item['base_form'] as String?;
    final recognized = _recognizeType(
      item,
      typeInferenceRules,
      typeInferenceRuleSets,
    );
    final List<String>? possibleTypes = recognized.possibleTypes;

    // Infer type if not provided (use first from possible_types)
    String type = item['type'] as String? ?? '';
    if (type.isEmpty && possibleTypes != null && possibleTypes.isNotEmpty) {
      type = possibleTypes.first;
    }

    if (type.isEmpty) {
      throw Exception(
        'Item "${word ?? baseForm}" has no type and cannot be inferred. Please provide type explicitly.',
      );
    }

    // Infer forms from type patterns
    final itemWithType = Map<String, dynamic>.from(item)..['type'] = type;
    final derived = deriveForms(
      itemWithType,
      typePatterns,
      formOrder,
      defaultWordForm,
    );
    final inferredForms = derived.forms;

    // Start with inferred forms, then overlay explicit forms as overrides
    Map<String, dynamic> formsMap = inferredForms
        .map((key, value) => MapEntry<String, dynamic>(key, value));
    // Keep a copy of pure inferred forms before explicit overrides
    final Map<String, dynamic> inferredOnlyMap = Map.from(formsMap);
    final Map<String, dynamic>? explicitForms =
        item['forms'] as Map<String, dynamic>?;
    if (explicitForms != null && explicitForms.isNotEmpty) {
      formsMap.addAll(explicitForms);
    }

    if (formsMap.isEmpty) {
      throw Exception(
        'Item "${word ?? baseForm}" of type "$type" has no forms and cannot be inferred. Please provide forms explicitly.',
      );
    }

    // If word is not set but we have forms, set it from the appropriate form
    if (word == null && defaultWordForm != null) {
      word = formsMap[defaultWordForm] as String?;
    }

    // Filter form_order to only include keys present in formsMap
    final List<String> itemFormOrder = formOrder
        .where((key) => formsMap.containsKey(key))
        .toList();

    // Extract forms from the forms map, ordered by form_order
    final List<String> forms = itemFormOrder
        .map((key) => formsMap[key] as String)
        .toList();

    // Extract inferred-only forms (before explicit overrides)
    final List<String> inferredFormsList = itemFormOrder
        .map((key) => (inferredOnlyMap[key] ?? formsMap[key]) as String)
        .toList();

    // Build per-item form labels (matching itemFormOrder)
    final List<FormLabel> itemFormLabels = itemFormOrder
        .map((key) => formLabelsByKey[key]!)
        .toList();

    // Apply defaults if not specified
    final String? wordForm = item['word_form'] as String? ?? defaultWordForm;
    final String? baseFormLabel =
        item['base_form_label'] as String? ?? defaultBaseFormLabel;

    final ruleMatch = recognized.ruleMatch;
    final derivation = Derivation(
      type: type,
      // A rule is only shown when it agrees with the type that is practised.
      recognition: ruleMatch != null && ruleMatch.types.contains(type)
          ? TypeByRule(
              sourceWord: ruleMatch.sourceWord,
              suffix: ruleMatch.suffix,
              candidateTypes: ruleMatch.types,
            )
          : const TypeDeclared(),
      stems: {if (derived.stem != null) _stemName: derived.stem!},
      forms: {
        for (int i = 0; i < itemFormOrder.length; i++)
          itemFormOrder[i]: _classifyForm(
            itemFormOrder[i],
            forms[i],
            wordForm,
            derived.generated[itemFormOrder[i]],
          ),
      },
      grammar: grammar,
    );

    // The spellings the file gives, in file order. A part without a label is
    // shown without one; `word` never carries a label in v1 data.
    final String? givenWord = item['word'] as String?;
    final principalParts = <(String, String)>[
      if (givenWord != null) ('', givenWord),
      if (baseForm != null) (baseFormLabel ?? '', baseForm),
    ];
    final String lemma = baseForm ?? givenWord!;

    return PracticeItem(
      id: '$dataFileId:${normalizeDiacritics(lemma).toLowerCase()}',
      lemma: lemma,
      type: type,
      translation: item['translation'] as String,
      principalParts: principalParts,
      forms: forms,
      acceptedForms: [for (final form in forms) [form]],
      formLabels: itemFormLabels,
      possibleTypes: possibleTypes,
      dataFileId: dataFileId,
      formOrder: itemFormOrder,
      derivation: derivation,
      inferredForms: inferredFormsList,
    );
  }).toList();
}
