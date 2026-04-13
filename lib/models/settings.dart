import '../data/lesson_data.dart';

/// Settings model to hold enabled forms and types per data file
class Settings {
  /// Map of data file identifier to set of enabled form keys
  /// e.g., {"nouns": {"nominative_singular", "genitive_singular", ...}, ...}
  final Map<String, Set<String>> enabledForms;

  /// Map of data file identifier to set of enabled type names
  /// e.g., {"nouns": {"A-Deklination", "O-Deklination-maskulinum", ...}, ...}
  final Map<String, Set<String>> enabledTypes;

  /// Map of data file identifier to input strategy id
  /// e.g., {"verbs": "dropdown_all_forms", "nouns": "text_field"}
  final Map<String, String> inputStrategyIds;

  /// Normalized words selected for practice.
  /// An empty set means "all words" (no filter).
  /// Can be set from either the settings screen (lesson-based) or the
  /// statistics screen (performance-based).
  final Set<String> selectedWords;

  Settings({
    Map<String, Set<String>>? enabledForms,
    Map<String, Set<String>>? enabledTypes,
    Map<String, String>? inputStrategyIds,
    Set<String>? selectedWords,
  })  : enabledForms = enabledForms ?? {},
        enabledTypes = enabledTypes ?? {},
        inputStrategyIds = inputStrategyIds ?? {},
        selectedWords = selectedWords ?? {};

  Settings copyWith({
    Map<String, Set<String>>? enabledForms,
    Map<String, Set<String>>? enabledTypes,
    Map<String, String>? inputStrategyIds,
    Set<String>? selectedWords,
  }) {
    return Settings(
      enabledForms: enabledForms ?? this.enabledForms,
      enabledTypes: enabledTypes ?? this.enabledTypes,
      inputStrategyIds: inputStrategyIds ?? this.inputStrategyIds,
      selectedWords: selectedWords ?? this.selectedWords,
    );
  }

  /// Check if a form is enabled for a given data file
  bool isFormEnabled(String dataFileId, String formKey) {
    final forms = enabledForms[dataFileId];
    if (forms == null) return true;
    return forms.contains(formKey);
  }

  /// Check if a type is enabled for a given data file
  bool isTypeEnabled(String dataFileId, String typeName) {
    final types = enabledTypes[dataFileId];
    if (types == null) return true;
    return types.contains(typeName);
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
    final newEnabledForms = Map<String, Set<String>>.from(enabledForms);
    final forms = Set<String>.from(newEnabledForms[dataFileId] ?? {});

    if (forms.contains(formKey)) {
      forms.remove(formKey);
    } else {
      forms.add(formKey);
    }

    newEnabledForms[dataFileId] = forms;
    return copyWith(enabledForms: newEnabledForms);
  }

  /// Set all forms as enabled for a given data file
  Settings enableAllForms(String dataFileId, List<String> allFormKeys) {
    final newEnabledForms = Map<String, Set<String>>.from(enabledForms);
    newEnabledForms[dataFileId] = Set<String>.from(allFormKeys);
    return copyWith(enabledForms: newEnabledForms);
  }

  /// Whether a specific normalized word is selected.
  /// When no words are explicitly selected, everything is treated as selected.
  bool isWordSelected(String normalizedWord) {
    if (selectedWords.isEmpty) return true;
    return selectedWords.contains(normalizedWord);
  }

  /// Whether all words in a lesson are selected.
  bool isLessonFullySelected(String lessonName, List<String> rawWords) {
    if (selectedWords.isEmpty) return true;
    return rawWords.every(
      (w) => selectedWords.contains(normalizeDiacritics(w)),
    );
  }

  /// Whether some (but not all) words in a lesson are selected.
  bool isLessonPartiallySelected(String lessonName, List<String> rawWords) {
    if (selectedWords.isEmpty) return false;
    final hasSelected = rawWords.any(
      (w) => selectedWords.contains(normalizeDiacritics(w)),
    );
    final hasUnselected = rawWords.any(
      (w) => !selectedWords.contains(normalizeDiacritics(w)),
    );
    return hasSelected && hasUnselected;
  }

  /// Toggle a single word's selection state.
  ///
  /// [allNormalizedWords] is the full list needed to materialize the set when
  /// moving from "all selected" (empty set) to "all but one selected".
  Settings toggleWord(String normalizedWord, List<String> allNormalizedWords) {
    final Set<String> base = selectedWords.isEmpty
        ? Set<String>.from(allNormalizedWords)
        : Set<String>.from(selectedWords);

    if (base.contains(normalizedWord)) {
      base.remove(normalizedWord);
    } else {
      base.add(normalizedWord);
    }

    // Collapse back to "all" if every word is selected
    if (base.length == allNormalizedWords.length &&
        base.containsAll(allNormalizedWords)) {
      return copyWith(selectedWords: <String>{});
    }
    return copyWith(selectedWords: base);
  }

  /// Toggle all words in a lesson.
  ///
  /// If all lesson words are selected, deselect them all.
  /// Otherwise, select all of them.
  /// [allNormalizedWords] is the full universe needed for the "all" collapse.
  Settings toggleLessonWords(
    List<String> rawLessonWords,
    List<String> allNormalizedWords,
  ) {
    final lessonNormalized =
        rawLessonWords.map(normalizeDiacritics).toList();

    final allSelected = isLessonFullySelected('', rawLessonWords);

    final Set<String> base = selectedWords.isEmpty
        ? Set<String>.from(allNormalizedWords)
        : Set<String>.from(selectedWords);

    if (allSelected) {
      base.removeAll(lessonNormalized);
    } else {
      base.addAll(lessonNormalized);
    }

    if (base.length == allNormalizedWords.length &&
        base.containsAll(allNormalizedWords)) {
      return copyWith(selectedWords: <String>{});
    }
    return copyWith(selectedWords: base);
  }

  /// Replace the entire selection with [words] (normalized).
  /// Pass an empty set to select all words (no filter).
  Settings withSelectedWords(Set<String> words) {
    return copyWith(selectedWords: words);
  }

  /// Select every word (stored as an empty set meaning "no filter").
  Settings selectAllWords() {
    return copyWith(selectedWords: <String>{});
  }

  /// Toggle a type's enabled state for a given data file
  Settings toggleType(String dataFileId, String typeName) {
    final newEnabledTypes = Map<String, Set<String>>.from(enabledTypes);
    final types = Set<String>.from(newEnabledTypes[dataFileId] ?? {});

    if (types.contains(typeName)) {
      types.remove(typeName);
    } else {
      types.add(typeName);
    }

    newEnabledTypes[dataFileId] = types;
    return copyWith(enabledTypes: newEnabledTypes);
  }

  /// Set all types as enabled for a given data file
  Settings enableAllTypes(String dataFileId, List<String> allTypes) {
    final newEnabledTypes = Map<String, Set<String>>.from(enabledTypes);
    newEnabledTypes[dataFileId] = Set<String>.from(allTypes);
    return copyWith(enabledTypes: newEnabledTypes);
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'enabledForms': enabledForms.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'enabledTypes': enabledTypes.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'inputStrategyIds': inputStrategyIds,
      'selectedWords': selectedWords.toList(),
    };
  }

  /// Create from JSON
  factory Settings.fromJson(Map<String, dynamic> json) {
    final enabledFormsMap = json['enabledForms'] as Map<String, dynamic>?;
    final enabledTypesMap = json['enabledTypes'] as Map<String, dynamic>?;
    final strategyMap = json['inputStrategyIds'] as Map<String, dynamic>?;
    // Support both old key ('selectedLessons') and new key ('selectedWords').
    // Old lesson names cannot be migrated to words without lesson data, so
    // when only the old key is present we fall back to "select all" (empty set).
    final wordList = json['selectedWords'] as List<dynamic>?;

    return Settings(
      enabledForms: enabledFormsMap?.map(
            (key, value) => MapEntry(key, Set<String>.from(value as List)),
          ) ??
          {},
      enabledTypes: enabledTypesMap?.map(
            (key, value) => MapEntry(key, Set<String>.from(value as List)),
          ) ??
          {},
      inputStrategyIds:
          strategyMap?.map((key, value) => MapEntry(key, value as String)) ??
              {},
      selectedWords: wordList != null
          ? Set<String>.from(wordList.map((e) => e as String))
          : <String>{},
    );
  }
}
