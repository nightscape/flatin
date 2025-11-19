/// Generic practice item loaded directly from YAML
class PracticeItem {
  final String type;
  final String translation;
  final String? baseForm;
  final String? baseFormLabel;
  final List<String> forms;
  final List<FormLabel> formLabels;
  final String? word;
  final String? wordForm;
  final List<String>? possibleTypes;
  final List<String> classificationSections;
  final String dataFileId; // 'nouns' or 'verbs'
  final List<String> formOrder; // Order of form keys

  PracticeItem({
    required this.type,
    required this.translation,
    this.baseForm,
    this.baseFormLabel,
    required this.forms,
    required this.formLabels,
    this.word,
    this.wordForm,
    this.possibleTypes,
    required this.classificationSections,
    required this.dataFileId,
    required this.formOrder,
  });

  /// Get all forms that need to be practiced
  List<String> get allForms => forms;

  /// Filter forms and labels based on enabled form keys
  ({List<String> forms, List<FormLabel> labels}) filterForms(
    Set<String> enabledFormKeys,
  ) {
    final filteredForms = <String>[];
    final filteredLabels = <FormLabel>[];

    for (int i = 0; i < formOrder.length; i++) {
      final formKey = formOrder[i];
      if (enabledFormKeys.contains(formKey)) {
        filteredForms.add(forms[i]);
        filteredLabels.add(formLabels[i]);
      }
    }

    return (forms: filteredForms, labels: filteredLabels);
  }
}

/// Form label (case, person, etc.)
class FormLabel {
  final String name;
  final String number;

  FormLabel({required this.name, required this.number});

  String get displayName => '$name $number';

  factory FormLabel.fromMap(Map<String, dynamic> map) {
    return FormLabel(
      name: map['name'] as String,
      number: map['number'] as String,
    );
  }
}
