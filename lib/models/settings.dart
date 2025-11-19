/// Settings model to hold enabled forms per data file
class Settings {
  /// Map of data file identifier to set of enabled form keys
  /// e.g., {"nouns": {"nominative_singular", "genitive_singular", ...}, ...}
  final Map<String, Set<String>> enabledForms;

  Settings({Map<String, Set<String>>? enabledForms})
    : enabledForms = enabledForms ?? {};

  Settings copyWith({Map<String, Set<String>>? enabledForms}) {
    return Settings(enabledForms: enabledForms ?? this.enabledForms);
  }

  /// Check if a form is enabled for a given data file
  bool isFormEnabled(String dataFileId, String formKey) {
    final forms = enabledForms[dataFileId];
    if (forms == null) {
      // If not set, default to enabled
      return true;
    }
    return forms.contains(formKey);
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
    return Settings(enabledForms: newEnabledForms);
  }

  /// Set all forms as enabled for a given data file
  Settings enableAllForms(String dataFileId, List<String> allFormKeys) {
    final newEnabledForms = Map<String, Set<String>>.from(enabledForms);
    newEnabledForms[dataFileId] = Set<String>.from(allFormKeys);
    return Settings(enabledForms: newEnabledForms);
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'enabledForms': enabledForms.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
    };
  }

  /// Create from JSON
  factory Settings.fromJson(Map<String, dynamic> json) {
    final enabledFormsMap = json['enabledForms'] as Map<String, dynamic>?;
    if (enabledFormsMap == null) {
      return Settings();
    }

    return Settings(
      enabledForms: enabledFormsMap.map(
        (key, value) => MapEntry(key, Set<String>.from(value as List)),
      ),
    );
  }
}
