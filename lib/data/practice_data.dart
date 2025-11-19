import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../models/practice_item.dart';

/// Form metadata extracted from YAML
class FormMetadata {
  final List<String> formOrder;
  final Map<String, FormLabel> formLabelsByKey;
  final List<String> classificationSections;
  final String? dataFileId;
  final String? defaultWordForm;
  final List<String>? typeInferenceRuleSets;

  FormMetadata({
    required this.formOrder,
    required this.formLabelsByKey,
    required this.classificationSections,
    this.dataFileId,
    this.defaultWordForm,
    this.typeInferenceRuleSets,
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

  // Extract form labels from top level
  final Map<String, dynamic> formLabelsMap =
      yamlMap['form_labels'] as Map<String, dynamic>;
  final Map<String, FormLabel> formLabelsByKey = formLabelsMap.map(
    (key, value) =>
        MapEntry(key, FormLabel.fromMap(value as Map<String, dynamic>)),
  );

  // Extract form order from top level
  final List<dynamic> formOrderList = yamlMap['form_order'] as List<dynamic>;
  final List<String> formOrder = formOrderList.map((v) => v as String).toList();

  // Extract classification sections from top level
  final List<dynamic> classificationSectionsList =
      yamlMap['classification_sections'] as List<dynamic>;
  final List<String> classificationSections = classificationSectionsList
      .map((v) => v as String)
      .toList();

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

  return FormMetadata(
    formOrder: formOrder,
    formLabelsByKey: formLabelsByKey,
    classificationSections: classificationSections,
    dataFileId: dataFileId,
    defaultWordForm: defaultWordForm,
    typeInferenceRuleSets: typeInferenceRuleSets,
  );
}

/// Normalize Latin diacritics (macrons) for comparison
/// Removes macrons from vowels: ā→a, ē→e, ī→i, ō→o, ū→u
String _normalizeDiacritics(String text) {
  return text
      .replaceAll('ā', 'a')
      .replaceAll('ē', 'e')
      .replaceAll('ī', 'i')
      .replaceAll('ō', 'o')
      .replaceAll('ū', 'u')
      .replaceAll('Ā', 'A')
      .replaceAll('Ē', 'E')
      .replaceAll('Ī', 'I')
      .replaceAll('Ō', 'O')
      .replaceAll('Ū', 'U');
}

/// Extract stem from a word based on pattern definition
String _extractStem(String word, String pattern) {
  // Pattern format: "remove_suffix:suffix1,suffix2,..."
  if (pattern.startsWith('remove_suffix:')) {
    final suffixes = pattern.substring('remove_suffix:'.length).split(',');
    final normalizedWord = _normalizeDiacritics(word);

    // Sort suffixes by length (longest first) to match longer suffixes before shorter ones
    // This ensures "āre" is matched before "re" for words like "intrāre"
    final sortedSuffixes = suffixes.toList()
      ..sort((a, b) {
        final normA = _normalizeDiacritics(a);
        final normB = _normalizeDiacritics(b);
        return normB.length.compareTo(normA.length); // Descending order
      });

    for (final suffix in sortedSuffixes) {
      final normalizedSuffix = _normalizeDiacritics(suffix);
      if (normalizedWord.endsWith(normalizedSuffix)) {
        // Use the original suffix length (not normalized) to determine how many characters to remove
        // This correctly handles macrons: "āre" is 3 chars, "re" is 2 chars
        final suffixLength = suffix.length;
        if (word.length >= suffixLength) {
          return word.substring(0, word.length - suffixLength);
        }
      }
    }
  }
  return word; // Fallback: return word as-is
}

/// Generate a form from a stem using a pattern template
String _generateForm(String stem, String template) {
  return template.replaceAll('{stem}', stem);
}

/// Generic type inference using rules from YAML
/// Returns list of possible types based on word ending
/// [ruleSet] specifies which rule set to check (if null, checks all available rule sets)
/// [availableRuleSets] is the list of rule set names available in the YAML
List<String> _inferTypesFromRules(
  String word,
  Map<String, dynamic>? typeInferenceRules,
  List<String>? availableRuleSets, {
  String? ruleSet,
}) {
  final List<String> types = [];

  if (typeInferenceRules == null || availableRuleSets == null) return types;

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
      final normalizedWord = _normalizeDiacritics(word);
      final normalizedSuffix = _normalizeDiacritics(suffix);
      if (normalizedWord.endsWith(normalizedSuffix)) {
        if (minLength == null || word.length >= minLength) {
          // Add all types from this rule
          for (final type in ruleTypes) {
            types.add(type as String);
          }
          // First match wins for this rule set
          break;
        }
      }
    }

    // If we found types and we're checking a specific rule set, stop
    // Otherwise continue to next rule set
    if (types.isNotEmpty && ruleSet != null) {
      break;
    }
  }

  return types;
}

/// Infer forms for an item based on type patterns
/// [defaultWordForm] is the form key that the 'word' field represents (e.g., 'nominative_singular', 'first_person_singular')
/// This function is public to allow testing inference logic.
Map<String, String> inferForms(
  Map<String, dynamic> item,
  Map<String, dynamic> typePatterns,
  List<String> formOrder,
  String? defaultWordForm,
) {
  final String type = item['type'] as String;
  final Map<String, dynamic>? pattern =
      typePatterns[type] as Map<String, dynamic>?;

  if (pattern == null) {
    // No pattern available, return empty map (will require explicit forms)
    return {};
  }

  // Determine which form the 'word' field represents
  final String? wordForm = defaultWordForm;
  if (wordForm == null) {
    // Cannot infer forms without knowing what 'word' represents
    return {};
  }

  String? stem;
  String? baseWord = item['word'] as String?;
  String? baseForm = item['base_form'] as String?;

  // Try to extract stem from 'word' field first
  if (baseWord != null) {
    final String stemPattern = pattern['stem_extraction'] as String? ?? '';
    if (stemPattern.isNotEmpty) {
      stem = _normalizeDiacritics(_extractStem(baseWord, stemPattern));
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
      String alternativeStem = _extractStem(baseForm, alternativeStemPattern);
      // Normalize the alternative stem to remove diacritics
      alternativeStem = _normalizeDiacritics(alternativeStem);

      // Try to reconstruct the base word from the alternative stem
      // This is pattern-specific: for verbs, infinitive stem + 'o' = first person singular
      // We check if there's a reconstruction pattern in the pattern definition
      final String? reconstructionPattern =
          pattern['reconstruction_from_alternative_stem'] as String?;
      if (reconstructionPattern != null) {
        baseWord = reconstructionPattern.replaceAll('{stem}', alternativeStem);
        // Now extract stem from reconstructed base word
        final String stemPattern = pattern['stem_extraction'] as String? ?? '';
        if (stemPattern.isNotEmpty) {
          stem = _normalizeDiacritics(_extractStem(baseWord, stemPattern));
        } else {
          stem = alternativeStem;
        }
      } else {
        // Fallback: use alternative stem directly
        stem = alternativeStem;
      }
    }
  }

  if (stem == null || baseWord == null) return {};

  // Build forms map starting with the word form
  final Map<String, String> forms = {wordForm: baseWord};

  // Generate other forms from pattern
  for (final formKey in formOrder) {
    if (formKey == wordForm) continue;

    final String? template = pattern[formKey] as String?;
    if (template != null) {
      forms[formKey] = _generateForm(stem, template);
    }
  }

  return forms;
}

/// Load practice items from a YAML file
Future<List<PracticeItem>> loadPracticeItems(String assetPath) async {
  final String yamlString = await rootBundle.loadString(assetPath);
  final yaml = loadYaml(yamlString) as YamlMap;
  final Map<String, dynamic> yamlMap = _yamlMapToMap(yaml);

  // Extract form labels from top level
  final Map<String, dynamic> formLabelsMap =
      yamlMap['form_labels'] as Map<String, dynamic>;
  final Map<String, FormLabel> formLabelsByKey = formLabelsMap.map(
    (key, value) =>
        MapEntry(key, FormLabel.fromMap(value as Map<String, dynamic>)),
  );

  // Extract form order from top level
  final List<dynamic> formOrderList = yamlMap['form_order'] as List<dynamic>;
  final List<String> formOrder = formOrderList.map((v) => v as String).toList();

  // Extract classification sections from top level
  final List<dynamic> classificationSectionsList =
      yamlMap['classification_sections'] as List<dynamic>;
  final List<String> classificationSections = classificationSectionsList
      .map((v) => v as String)
      .toList();

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

  // Build ordered list of form labels
  final List<FormLabel> formLabels = formOrder
      .map((key) => formLabelsByKey[key]!)
      .toList();

  // Get data file identifier (required)
  final String? dataFileIdValue = yamlMap['data_file_id'] as String?;
  if (dataFileIdValue == null || dataFileIdValue.isEmpty) {
    throw Exception(
      'YAML file "$assetPath" must specify "data_file_id" at the top level.',
    );
  }
  final String dataFileId = dataFileIdValue;

  // Extract items
  final List<dynamic> itemsList = yamlMap['items'] as List<dynamic>;

  return itemsList.map((itemData) {
    final Map<String, dynamic> item = itemData as Map<String, dynamic>;

    // Infer possible_types from word ending if not provided
    String? word = item['word'] as String?;
    final String? baseForm = item['base_form'] as String?;
    List<String>? possibleTypes;

    if (item['possible_types'] != null) {
      final List<dynamic> possibleTypesList =
          item['possible_types'] as List<dynamic>;
      possibleTypes = possibleTypesList.map((v) => v as String).toList();
    } else {
      // Infer possible_types from word ending using YAML rules
      if (typeInferenceRules != null && typeInferenceRuleSets != null) {
        // Determine which fields to check based on available rule sets
        // If we have a single rule set (like 'rules'), check 'word' field
        // If we have multiple rule sets (like 'infinitive_rules', 'first_person_rules'),
        // check 'base_form' first, then 'word'
        if (typeInferenceRuleSets.length == 1) {
          // Single rule set: check word field
          if (word != null) {
            final inferredTypes = _inferTypesFromRules(
              word,
              typeInferenceRules,
              typeInferenceRuleSets,
            );
            if (inferredTypes.isNotEmpty) {
              possibleTypes = inferredTypes;
            }
          }
        } else {
          // Multiple rule sets: check base_form first, then word
          // Rule set names typically indicate which field to check
          // (e.g., 'infinitive_rules' -> base_form, 'first_person_rules' -> word)
          if (baseForm != null) {
            // Find rule set that suggests infinitive/base_form
            final infinitiveRuleSet = typeInferenceRuleSets.firstWhere(
              (rs) => rs.contains('infinitive') || rs.contains('base'),
              orElse: () => typeInferenceRuleSets.first,
            );
            final inferredTypes = _inferTypesFromRules(
              baseForm,
              typeInferenceRules,
              typeInferenceRuleSets,
              ruleSet: infinitiveRuleSet,
            );
            if (inferredTypes.isNotEmpty) {
              possibleTypes = inferredTypes;
            }
          }
          // If no match from base_form, try word field
          if ((possibleTypes == null || possibleTypes.isEmpty) &&
              word != null) {
            // Find rule set that suggests word field (e.g., first_person_rules)
            final wordRuleSet = typeInferenceRuleSets.firstWhere(
              (rs) =>
                  rs.contains('first_person') ||
                  rs.contains('word') ||
                  rs.contains('person'),
              orElse: () => typeInferenceRuleSets.last,
            );
            final inferredTypes = _inferTypesFromRules(
              word,
              typeInferenceRules,
              typeInferenceRuleSets,
              ruleSet: wordRuleSet,
            );
            if (inferredTypes.isNotEmpty) {
              possibleTypes = inferredTypes;
            }
          }
        }
      }
    }

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

    // Check if forms are explicitly provided
    Map<String, dynamic>? formsMap = item['forms'] as Map<String, dynamic>?;

    // If forms are not provided, try to infer them
    if (formsMap == null || formsMap.isEmpty) {
      // Update item with inferred type for form inference
      final itemWithType = Map<String, dynamic>.from(item)..['type'] = type;
      final inferredForms = inferForms(
        itemWithType,
        typePatterns,
        formOrder,
        defaultWordForm,
      );
      if (inferredForms.isNotEmpty) {
        formsMap = inferredForms.map((key, value) => MapEntry(key, value));

        // If word is not set but we inferred forms, set it from the appropriate form
        if (word == null && defaultWordForm != null) {
          word = formsMap[defaultWordForm] as String?;
        }
      } else {
        // If inference failed and no forms provided, throw an error
        throw Exception(
          'Item "${word ?? baseForm}" of type "$type" has no forms and cannot be inferred. Please provide forms explicitly.',
        );
      }
    }

    // Extract forms from the forms map, ordered by form_order
    final List<String> forms = formOrder
        .map((key) => formsMap![key] as String)
        .toList();

    // Apply defaults if not specified
    final String? wordForm = item['word_form'] as String? ?? defaultWordForm;
    final String? baseFormLabel =
        item['base_form_label'] as String? ?? defaultBaseFormLabel;

    return PracticeItem(
      type: type,
      translation: item['translation'] as String,
      baseForm: item['base_form'] as String?,
      baseFormLabel: baseFormLabel,
      forms: forms,
      formLabels: formLabels,
      word: item['word'] as String?,
      wordForm: wordForm,
      possibleTypes: possibleTypes,
      classificationSections: classificationSections,
      dataFileId: dataFileId,
      formOrder: formOrder,
    );
  }).toList();
}
