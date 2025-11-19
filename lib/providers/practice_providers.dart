import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/practice_item.dart';

part 'practice_providers.g.dart';

/// Generic state class for practice screens
class PracticeState {
  final bool isTranslationVisible;
  final bool isChecked;
  final List<bool?> validationResults;

  PracticeState({
    this.isTranslationVisible = true,
    this.isChecked = false,
    List<bool?>? validationResults,
  }) : validationResults = validationResults ?? [];

  PracticeState copyWith({
    bool? isTranslationVisible,
    bool? isChecked,
    List<bool?>? validationResults,
  }) {
    return PracticeState(
      isTranslationVisible: isTranslationVisible ?? this.isTranslationVisible,
      isChecked: isChecked ?? this.isChecked,
      validationResults: validationResults ?? this.validationResults,
    );
  }
}

/// Generic notifier for managing practice screen state
@riverpod
class PracticeNotifier extends _$PracticeNotifier {
  @override
  PracticeState build(PracticeItem item) {
    return PracticeState(
      validationResults: List.filled(item.allForms.length, null),
    );
  }

  void toggleTranslationVisibility() {
    state = state.copyWith(isTranslationVisible: !state.isTranslationVisible);
  }

  void checkAnswers(List<String> userAnswers, List<String> correctAnswers) {
    final results = <bool?>[];
    for (int i = 0; i < userAnswers.length; i++) {
      final userAnswer = userAnswers[i].trim().toLowerCase();
      final correctAnswer = correctAnswers[i].toLowerCase();

      // Only validate non-empty fields
      if (userAnswer.isNotEmpty) {
        results.add(userAnswer == correctAnswer);
      } else {
        results.add(null);
      }
    }
    state = state.copyWith(isChecked: true, validationResults: results);
  }

  void resetAnswers(int formCount) {
    state = state.copyWith(
      isChecked: false,
      validationResults: List.filled(formCount, null),
    );
  }

  void hideAnswers() {
    state = state.copyWith(isChecked: false);
  }
}

/// State for word classification practice
class WordClassificationState {
  final List<String> selectedTypes;
  final bool isChecked;
  final bool isCorrect;
  final List<String> correctTypes;

  WordClassificationState({
    this.selectedTypes = const [],
    this.isChecked = false,
    this.isCorrect = false,
    this.correctTypes = const [],
  });

  WordClassificationState copyWith({
    List<String>? selectedTypes,
    bool? isChecked,
    bool? isCorrect,
    List<String>? correctTypes,
  }) {
    return WordClassificationState(
      selectedTypes: selectedTypes ?? this.selectedTypes,
      isChecked: isChecked ?? this.isChecked,
      isCorrect: isCorrect ?? this.isCorrect,
      correctTypes: correctTypes ?? this.correctTypes,
    );
  }
}

/// Provider for word classification state
@riverpod
class WordClassificationNotifier extends _$WordClassificationNotifier {
  @override
  WordClassificationState build() {
    return WordClassificationState();
  }

  void toggleSelection(String type) {
    final currentSelections = List<String>.from(state.selectedTypes);
    if (currentSelections.contains(type)) {
      currentSelections.remove(type);
    } else {
      currentSelections.add(type);
    }
    state = state.copyWith(selectedTypes: currentSelections);
  }

  void checkAnswers(List<String> correctTypes) {
    final selected = Set<String>.from(state.selectedTypes);
    final correct = Set<String>.from(correctTypes);

    final isCorrect = selected.length == correct.length &&
                     selected.every((type) => correct.contains(type));

    state = state.copyWith(
      isChecked: true,
      isCorrect: isCorrect,
      correctTypes: correctTypes,
    );
  }

  void reset() {
    state = WordClassificationState();
  }
}

