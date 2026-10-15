import '../data/lesson_data.dart';
import 'form_label.dart';

/// Settings model holding the user's practice selection.
///
/// Everything is stored as what the user switched OFF, so an entry that is
/// added to the YAML later is practised by default and needs no migration.
class Settings {
  /// Map of data file identifier to set of form keys the user switched off
  /// e.g., {"nouns": {"genitive_singular", ...}, ...}
  final Map<String, Set<String>> disabledForms;

  /// Data file identifier → axis id → the value codes the user switched off,
  /// e.g. {"verbs": {"genus_verbi": {"pass"}}}. Switching off one value hides
  /// every form that names it.
  final Map<String, Map<String, Set<String>>> disabledFeatures;

  /// Map of data file identifier to set of type names the user switched off
  /// e.g., {"nouns": {"O-Deklination-maskulinum", ...}, ...}
  final Map<String, Set<String>> disabledTypes;

  /// Map of data file identifier to input strategy id
  /// e.g., {"verbs": "dropdown_all_forms", "nouns": "text_field"}
  final Map<String, String> inputStrategyIds;

  /// Normalized words the user switched off; every other word is practised.
  /// Can be set from either the settings screen (lesson-based) or the
  /// statistics screen (performance-based).
  final Set<String> deselectedWords;

  Settings({
    Map<String, Set<String>>? disabledForms,
    Map<String, Map<String, Set<String>>>? disabledFeatures,
    Map<String, Set<String>>? disabledTypes,
    Map<String, String>? inputStrategyIds,
    Set<String>? deselectedWords,
  })  : disabledForms = disabledForms ?? {},
        disabledFeatures = disabledFeatures ?? {},
        disabledTypes = disabledTypes ?? {},
        inputStrategyIds = inputStrategyIds ?? {},
        deselectedWords = deselectedWords ?? {};

  Settings copyWith({
    Map<String, Set<String>>? disabledForms,
    Map<String, Map<String, Set<String>>>? disabledFeatures,
    Map<String, Set<String>>? disabledTypes,
    Map<String, String>? inputStrategyIds,
    Set<String>? deselectedWords,
  }) {
    return Settings(
      disabledForms: disabledForms ?? this.disabledForms,
      disabledFeatures: disabledFeatures ?? this.disabledFeatures,
      disabledTypes: disabledTypes ?? this.disabledTypes,
      inputStrategyIds: inputStrategyIds ?? this.inputStrategyIds,
      deselectedWords: deselectedWords ?? this.deselectedWords,
    );
  }

  /// Whether one value of one axis is practised, e.g. the Passive voice
  bool isFeatureEnabled(String dataFileId, String axisId, String code) {
    return !(disabledFeatures[dataFileId]?[axisId]?.contains(code) ?? false);
  }

  /// Whether a form is practised: its key must be on, and every feature it
  /// names must be on.
  bool isFormEnabled(String dataFileId, FormKey formKey, FormLabel label) {
    if (disabledForms[dataFileId]?.contains(formKey) ?? false) return false;
    return label.features.entries
        .every((f) => isFeatureEnabled(dataFileId, f.key, f.value));
  }

  /// Check if a type is enabled for a given data file
  bool isTypeEnabled(String dataFileId, String typeName) {
    return !(disabledTypes[dataFileId]?.contains(typeName) ?? false);
  }

  /// The enabled subset of [allFormKeys], which [labels] describes in the same
  /// order.
  Set<FormKey> enabledFormsOf(
    String dataFileId,
    List<FormKey> allFormKeys,
    List<FormLabel> labels,
  ) {
    assert(allFormKeys.length == labels.length);
    return {
      for (int i = 0; i < allFormKeys.length; i++)
        if (isFormEnabled(dataFileId, allFormKeys[i], labels[i]))
          allFormKeys[i],
    };
  }

  /// Get the input strategy id for a data file (default: text_field)
  String getInputStrategyId(String dataFileId) {
    return inputStrategyIds[dataFileId] ?? 'text_field';
  }

  /// Set the input strategy for a data file
  Settings setInputStrategy(String dataFileId, String strategyId) {
    final newMap = Map<String, String>.from(inputStrategyIds);
    newMap[dataFileId] = strategyId;
    return copyWith(inputStrategyIds: newMap);
  }

  /// Toggle a form's enabled state for a given data file
  Settings toggleForm(String dataFileId, String formKey) {
    return copyWith(
      disabledForms: _toggled(disabledForms, dataFileId, formKey),
    );
  }

  /// Toggle one axis value for a given data file
  Settings toggleFeature(String dataFileId, String axisId, String code) {
    final next = {
      for (final file in disabledFeatures.entries)
        file.key: {
          for (final axis in file.value.entries)
            axis.key: Set<String>.from(axis.value),
        },
    };
    final codes = next
        .putIfAbsent(dataFileId, () => {})
        .putIfAbsent(axisId, () => <String>{});
    if (!codes.remove(code)) {
      codes.add(code);
    }
    return copyWith(disabledFeatures: next);
  }

  /// Enable every form for a given data file, by key and by feature
  Settings enableAllForms(String dataFileId) {
    final newDisabledForms = Map<String, Set<String>>.from(disabledForms);
    newDisabledForms.remove(dataFileId);
    final newDisabledFeatures =
        Map<String, Map<String, Set<String>>>.from(disabledFeatures);
    newDisabledFeatures.remove(dataFileId);
    return copyWith(
      disabledForms: newDisabledForms,
      disabledFeatures: newDisabledFeatures,
    );
  }

  /// Toggle a type's enabled state for a given data file
  Settings toggleType(String dataFileId, String typeName) {
    return copyWith(
      disabledTypes: _toggled(disabledTypes, dataFileId, typeName),
    );
  }

  /// Enable every type for a given data file
  Settings enableAllTypes(String dataFileId) {
    final newDisabledTypes = Map<String, Set<String>>.from(disabledTypes);
    newDisabledTypes.remove(dataFileId);
    return copyWith(disabledTypes: newDisabledTypes);
  }

  /// Whether a specific normalized word is selected.
  bool isWordSelected(String normalizedWord) {
    return !deselectedWords.contains(normalizedWord);
  }

  /// Whether all words in a lesson are selected.
  bool isLessonFullySelected(List<String> rawWords) {
    return rawWords.every((w) => isWordSelected(normalizeDiacritics(w)));
  }

  /// Whether some (but not all) words in a lesson are selected.
  bool isLessonPartiallySelected(List<String> rawWords) {
    final selected = rawWords.where(
      (w) => isWordSelected(normalizeDiacritics(w)),
    );
    return selected.isNotEmpty && selected.length < rawWords.length;
  }

  /// Toggle a single word's selection state.
  Settings toggleWord(String normalizedWord) {
    final next = Set<String>.from(deselectedWords);
    if (!next.remove(normalizedWord)) {
      next.add(normalizedWord);
    }
    return copyWith(deselectedWords: next);
  }

  /// Toggle all words in a lesson.
  ///
  /// If all lesson words are selected, deselect them all.
  /// Otherwise, select all of them.
  Settings toggleLessonWords(List<String> rawLessonWords) {
    final lessonNormalized = rawLessonWords.map(normalizeDiacritics);
    final next = Set<String>.from(deselectedWords);

    if (isLessonFullySelected(rawLessonWords)) {
      next.addAll(lessonNormalized);
    } else {
      next.removeAll(lessonNormalized);
    }
    return copyWith(deselectedWords: next);
  }

  /// Select every word.
  Settings selectAllWords() {
    return copyWith(deselectedWords: <String>{});
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'disabledForms': disabledForms.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'disabledFeatures': disabledFeatures.map(
        (file, axes) => MapEntry(
          file,
          axes.map((axis, codes) => MapEntry(axis, codes.toList())),
        ),
      ),
      'disabledTypes': disabledTypes.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'inputStrategyIds': inputStrategyIds,
      'deselectedWords': deselectedWords.toList(),
    };
  }

  /// Create from JSON
  factory Settings.fromJson(Map<String, dynamic> json) {
    final disabledFormsMap = json['disabledForms'] as Map<String, dynamic>?;
    final featureMap = json['disabledFeatures'] as Map<String, dynamic>?;
    final disabledTypesMap = json['disabledTypes'] as Map<String, dynamic>?;
    final strategyMap = json['inputStrategyIds'] as Map<String, dynamic>?;
    final wordList = json['deselectedWords'] as List<dynamic>?;

    return Settings(
      disabledForms: disabledFormsMap?.map(
            (key, value) => MapEntry(key, Set<String>.from(value as List)),
          ) ??
          {},
      disabledFeatures: featureMap?.map(
            (file, axes) => MapEntry(
              file,
              (axes as Map<String, dynamic>).map(
                (axis, codes) =>
                    MapEntry(axis, Set<String>.from(codes as List)),
              ),
            ),
          ) ??
          {},
      disabledTypes: disabledTypesMap?.map(
            (key, value) => MapEntry(key, Set<String>.from(value as List)),
          ) ??
          {},
      inputStrategyIds:
          strategyMap?.map((key, value) => MapEntry(key, value as String)) ??
              {},
      deselectedWords: wordList != null
          ? Set<String>.from(wordList.map((e) => e as String))
          : <String>{},
    );
  }
}

Map<String, Set<String>> _toggled(
  Map<String, Set<String>> disabled,
  String dataFileId,
  String key,
) {
  final next = Map<String, Set<String>>.from(disabled);
  final keys = Set<String>.from(next[dataFileId] ?? const <String>{});
  if (!keys.remove(key)) {
    keys.add(key);
  }
  next[dataFileId] = keys;
  return next;
}
