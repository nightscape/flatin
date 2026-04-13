/// Settings model to hold enabled forms per data file
class Settings {
  /// Map of data file identifier to set of enabled form keys
  /// e.g., {"nouns": {"nominative_singular", "genitive_singular", ...}, ...}
  final Map<String, Set<String>> enabledForms;

  /// Map of data file identifier to input strategy id
  /// e.g., {"verbs": "dropdown_all_forms", "nouns": "text_field"}
  final Map<String, String> inputStrategyIds;

  /// Names of lessons selected for practice.
  /// An empty set means "all lessons" (no filter).
  final Set<String> selectedLessons;

  Settings({
    Map<String, Set<String>>? enabledForms,
    Map<String, String>? inputStrategyIds,
    Set<String>? selectedLessons,
  })  : enabledForms = enabledForms ?? {},
        inputStrategyIds = inputStrategyIds ?? {},
        selectedLessons = selectedLessons ?? {};

  Settings copyWith({
    Map<String, Set<String>>? enabledForms,
    Map<String, String>? inputStrategyIds,
    Set<String>? selectedLessons,
  }) {
    return Settings(
      enabledForms: enabledForms ?? this.enabledForms,
      inputStrategyIds: inputStrategyIds ?? this.inputStrategyIds,
      selectedLessons: selectedLessons ?? this.selectedLessons,
    );
  }

  /// Check if a form is enabled for a given data file
  bool isFormEnabled(String dataFileId, String formKey) {
    final forms = enabledForms[dataFileId];
    if (forms == null) return true;
    return forms.contains(formKey);
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

  /// Whether a given lesson is currently selected for practice.
  /// When no lessons are explicitly selected, everything is treated
  /// as selected (no filter).
  bool isLessonSelected(String lessonName) {
    if (selectedLessons.isEmpty) return true;
    return selectedLessons.contains(lessonName);
  }

  /// Toggle a lesson's selection state.
  ///
  /// Because an empty set means "all selected", toggling a single lesson
  /// off from the "all" state first materializes the full list so only the
  /// toggled one actually turns off.
  Settings toggleLesson(String lessonName, List<String> allLessons) {
    final Set<String> base = selectedLessons.isEmpty
        ? Set<String>.from(allLessons)
        : Set<String>.from(selectedLessons);

    if (base.contains(lessonName)) {
      base.remove(lessonName);
    } else {
      base.add(lessonName);
    }

    return copyWith(selectedLessons: base);
  }

  /// Select every lesson (stored as an empty set meaning "no filter").
  Settings selectAllLessons() {
    return copyWith(selectedLessons: <String>{});
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'enabledForms': enabledForms.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'inputStrategyIds': inputStrategyIds,
      'selectedLessons': selectedLessons.toList(),
    };
  }

  /// Create from JSON
  factory Settings.fromJson(Map<String, dynamic> json) {
    final enabledFormsMap = json['enabledForms'] as Map<String, dynamic>?;
    final strategyMap = json['inputStrategyIds'] as Map<String, dynamic>?;
    final lessonList = json['selectedLessons'] as List<dynamic>?;

    return Settings(
      enabledForms: enabledFormsMap?.map(
            (key, value) => MapEntry(key, Set<String>.from(value as List)),
          ) ??
          {},
      inputStrategyIds:
          strategyMap?.map((key, value) => MapEntry(key, value as String)) ??
              {},
      selectedLessons: lessonList != null
          ? Set<String>.from(lessonList.map((e) => e as String))
          : <String>{},
    );
  }
}
