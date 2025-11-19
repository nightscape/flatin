import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart';
import '../models/practice_item.dart';
import '../models/settings.dart';
import '../data/practice_data.dart';
import '../providers/settings_provider.dart';
import '../providers/fsrs_provider.dart';
import '../widgets/app_drawer.dart';
import 'dart:math';

class WordClassificationScreen extends ConsumerStatefulWidget {
  const WordClassificationScreen({super.key});

  @override
  ConsumerState<WordClassificationScreen> createState() =>
      _WordClassificationScreenState();
}

class _WordClassificationScreenState
    extends ConsumerState<WordClassificationScreen> {
  PracticeItem? _currentItem;
  String? _displayedWord;
  List<int> _correctFormIndices = [];
  bool _isLoading = true;
  bool _isNoun = true;

  // Selected answers - list of combinations, each combination is a map of section->value
  List<Map<String, String?>> _selectedAnswers = [];

  // Correct answers - list of FormLabels that match the displayed word
  List<FormLabel> _correctAnswers = [];

  bool _isChecked = false;
  bool _isCorrect = false;
  bool _isPartiallyCorrect = false;
  Rating? _suggestedRating;
  bool _showRatingButtons = false;

  @override
  void initState() {
    super.initState();
    _loadRandomWord();
  }

  Future<void> _loadRandomWord() async {
    setState(() {
      _isLoading = true;
      _isChecked = false;
      _isCorrect = false;
      _isPartiallyCorrect = false;
      _showRatingButtons = false;
      _suggestedRating = null;
      _selectedAnswers = [];
      _correctAnswers = [];
      _correctFormIndices = [];
    });

    try {
      // Try to get due items from FSRS first
      final dueItemsByType = await ref.read(dueItemsByTypeProvider.future);
      final allDueItems = [
        ...(dueItemsByType['nouns'] ?? []),
        ...(dueItemsByType['verbs'] ?? []),
      ];

      // Load all items as fallback
      final nouns = await loadPracticeItems('lib/data/latin_nouns.yaml');
      final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final allItems = [...nouns, ...verbs];

      if (allItems.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get settings to filter forms
      final settings = await ref.read(settingsProvider.future);

      // Pick from due items if available, otherwise random
      final random = Random();
      final item = allDueItems.isNotEmpty
          ? allDueItems[random.nextInt(allDueItems.length)]
          : allItems[random.nextInt(allItems.length)];
      _isNoun = nouns.contains(item);

      // Filter forms based on settings
      final enabledForms =
          settings.enabledForms[item.dataFileId] ??
          Set<String>.from(item.formOrder);
      final filteredData = item.filterForms(enabledForms);

      if (filteredData.forms.isEmpty) {
        // No enabled forms, try again
        setState(() {
          _isLoading = false;
        });
        _loadRandomWord();
        return;
      }

      // Pick a random form from filtered forms
      final filteredFormIndex = random.nextInt(filteredData.forms.length);
      _displayedWord = filteredData.forms[filteredFormIndex];

      // Find ALL enabled forms in the item that match the displayed word string
      _correctFormIndices = [];
      _correctAnswers = [];

      for (int i = 0; i < item.forms.length; i++) {
        final formKey = item.formOrder[i];
        // Only include forms that are enabled in settings
        if (item.forms[i] == _displayedWord && enabledForms.contains(formKey)) {
          _correctFormIndices.add(i);
          _correctAnswers.add(item.formLabels[i]);
        }
      }

      // Initialize selected answers with one empty combination
      final emptyCombination = <String, String?>{};
      for (final section in item.classificationSections) {
        emptyCombination[section] = null;
      }
      _selectedAnswers = [emptyCombination];

      _currentItem = item;
    } catch (e) {
      print('Error loading word: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkAnswers() {
    if (_currentItem == null || _correctAnswers.isEmpty) return;

    // Check if at least one combination is fully selected
    bool atLeastOneComplete = _selectedAnswers.any(
      (combination) => _currentItem!.classificationSections.every(
        (section) => combination[section] != null,
      ),
    );

    if (!atLeastOneComplete) return;

    // Count correct and incorrect combinations
    int correctSelected = 0;
    int incorrectSelected = 0;

    for (final combination in _selectedAnswers) {
      // Only check complete combinations
      final isComplete = _currentItem!.classificationSections.every(
        (section) => combination[section] != null,
      );

      if (!isComplete) continue;

      final formLabel = _combinationToFormLabel(combination);
      if (formLabel != null) {
        if (_correctAnswers.any(
          (correctLabel) =>
              correctLabel.name == formLabel.name &&
              correctLabel.number == formLabel.number,
        )) {
          correctSelected++;
        } else {
          incorrectSelected++;
        }
      }
    }

    // Calculate partial credit score
    final totalCorrect = _correctAnswers.length;
    final totalPossible = _currentItem!.formLabels.length;
    final score =
        (correctSelected / totalCorrect) - (incorrectSelected / totalPossible);

    // Determine if all correct combinations were selected
    final allCorrect =
        correctSelected == totalCorrect && incorrectSelected == 0;
    // Determine if at least one correct combination was selected
    final hasCorrect = correctSelected > 0;
    // Determine if partially correct (some but not all correct)
    final partiallyCorrect = hasCorrect && !allCorrect;

    // Calculate FSRS rating based on partial credit
    if (allCorrect) {
      // Perfect: all correct, no incorrect
      _suggestedRating = Rating.good;
    } else if (score >= 0.5) {
      // Good performance: mostly correct
      _suggestedRating = Rating.good;
    } else if (score >= 0.25 || (hasCorrect && incorrectSelected == 0)) {
      // Some correct answers, or correct with no incorrect
      _suggestedRating = Rating.hard;
    } else if (hasCorrect) {
      // At least one correct but many incorrect
      _suggestedRating = Rating.hard;
    } else {
      // No correct answers
      _suggestedRating = Rating.again;
    }

    setState(() {
      _isChecked = true;
      _isCorrect = allCorrect;
      _isPartiallyCorrect = partiallyCorrect;
      _showRatingButtons = true;
    });
  }

  Future<void> _rateCard(Rating rating) async {
    if (_currentItem == null) return;

    // Review the card with FSRS
    await reviewCard(ref, _currentItem!, rating);

    // Load next word
    _loadRandomWord();
  }

  /// Extract unique options for a classification section from form labels
  /// For 'Numerus': extracts unique number values
  /// For other sections (like 'Kasus', 'Person'): extracts unique name values
  List<String> _getOptionsForSection(String section) {
    if (_currentItem == null) return [];

    // Filter form labels based on settings
    final settingsValue = ref.read(settingsProvider);
    Settings? settings;
    if (settingsValue is AsyncData<Settings>) {
      settings = settingsValue.value;
    }
    final enabledForms =
        settings?.enabledForms[_currentItem!.dataFileId] ??
        Set<String>.from(_currentItem!.formOrder);
    final filteredData = _currentItem!.filterForms(enabledForms);
    final availableFormLabels = filteredData.labels;

    if (section == 'Numerus') {
      // Extract unique number values, preserving order (Singular before Plural)
      final numbers = availableFormLabels
          .map((label) => label.number)
          .toSet()
          .toList();
      numbers.sort((a, b) {
        // Ensure Singular comes before Plural
        if (a == 'Singular' && b == 'Plural') return -1;
        if (a == 'Plural' && b == 'Singular') return 1;
        return a.compareTo(b);
      });
      return numbers;
    } else {
      // Extract unique name values for sections like 'Kasus' or 'Person'
      // Preserve the order as they appear in formLabels (first occurrence)
      final seen = <String>{};
      final options = <String>[];
      for (final label in availableFormLabels) {
        if (!seen.contains(label.name)) {
          seen.add(label.name);
          options.add(label.name);
        }
      }
      return options;
    }
  }

  void _nextWord() {
    setState(() {
      _showRatingButtons = false;
      _suggestedRating = null;
    });
    _loadRandomWord();
  }

  /// Convert a combination Map to FormLabel for comparison
  FormLabel? _combinationToFormLabel(Map<String, String?> combination) {
    if (_currentItem == null) return null;

    // Find matching FormLabel
    for (final label in _currentItem!.formLabels) {
      bool matches = true;
      for (final section in _currentItem!.classificationSections) {
        final selectedValue = combination[section];
        if (selectedValue == null) {
          matches = false;
          break;
        }
        if (section == 'Numerus') {
          if (label.number != selectedValue) {
            matches = false;
            break;
          }
        } else {
          if (label.name != selectedValue) {
            matches = false;
            break;
          }
        }
      }
      if (matches) {
        return label;
      }
    }
    return null;
  }

  /// Format FormLabel for display (e.g., "Nominativ Plural")
  String _formatFormLabel(FormLabel label) {
    return '${label.name} ${label.number}';
  }

  /// Check if a combination is correct
  bool _isCombinationCorrect(Map<String, String?> combination) {
    final formLabel = _combinationToFormLabel(combination);
    if (formLabel == null) return false;
    return _correctAnswers.any(
      (correctLabel) =>
          correctLabel.name == formLabel.name &&
          correctLabel.number == formLabel.number,
    );
  }

  /// Build a combination selector widget
  Widget _buildCombinationSelector(int index) {
    if (_currentItem == null) return const SizedBox();

    final combination = _selectedAnswers[index];
    final isCorrect = _isChecked && _isCombinationCorrect(combination);
    final isIncorrect =
        _isChecked && !isCorrect && combination.values.every((v) => v != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isChecked
              ? (isCorrect
                    ? Colors.green
                    : (isIncorrect ? Colors.red : Colors.grey))
              : Colors.grey,
          width: _isChecked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _currentItem!.classificationSections.map((section) {
                final options = _getOptionsForSection(section);
                final selectedValue = combination[section];

                return SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: selectedValue,
                    decoration: InputDecoration(
                      labelText: section,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('--'),
                      ),
                      ...options.map(
                        (option) => DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        ),
                      ),
                    ],
                    onChanged: _isChecked
                        ? null
                        : (value) {
                            setState(() {
                              _selectedAnswers[index] =
                                  Map<String, String?>.from(combination)
                                    ..[section] = value;
                            });
                          },
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedAnswers.length > 1 && !_isChecked)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _selectedAnswers.removeAt(index);
                });
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings and reload word if current form becomes disabled
    ref.listen<AsyncValue<Settings>>(settingsProvider, (previous, next) {
      if (previous != next &&
          next is AsyncData<Settings> &&
          _currentItem != null &&
          _correctFormIndices.isNotEmpty) {
        final settings = next.value;
        final enabledForms =
            settings.enabledForms[_currentItem!.dataFileId] ??
            Set<String>.from(_currentItem!.formOrder);

        // Check if any of the current forms are still enabled
        bool anyFormEnabled = _correctFormIndices.any((index) {
          if (index < _currentItem!.formOrder.length) {
            final formKey = _currentItem!.formOrder[index];
            return enabledForms.contains(formKey);
          }
          return false;
        });

        if (!anyFormEnabled) {
          // All forms were disabled, reload word
          _loadRandomWord();
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      drawer: buildAppDrawer(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5E5E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentItem == null || _displayedWord == null
          ? const Center(
              child: Text('No words available', style: TextStyle(fontSize: 18)),
            )
          : Column(
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Text(
                    _isNoun ? 'Deklination' : 'Konjugation',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),

                // Word display
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _displayedWord!,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (_currentItem!.translation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _currentItem!.translation,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Combination selectors
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display all combination selectors
                        ...List.generate(_selectedAnswers.length, (index) {
                          return _buildCombinationSelector(index);
                        }),
                        // Add button to add new combination
                        if (!_isChecked)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  final newCombination = <String, String?>{};
                                  for (final section
                                      in _currentItem!.classificationSections) {
                                    newCombination[section] = null;
                                  }
                                  _selectedAnswers.add(newCombination);
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Kombination hinzufügen'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD0D0D0),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Display all correct combinations
                if (_isChecked && _correctAnswers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Alle richtigen Kombinationen:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _correctAnswers.map((label) {
                              // Check if this combination was selected
                              final wasSelected = _selectedAnswers.any((
                                combination,
                              ) {
                                final formLabel = _combinationToFormLabel(
                                  combination,
                                );
                                return formLabel != null &&
                                    formLabel.name == label.name &&
                                    formLabel.number == label.number;
                              });

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: wasSelected
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: wasSelected
                                        ? Colors.green
                                        : Colors.grey,
                                    width: wasSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (wasSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      )
                                    else
                                      const Icon(
                                        Icons.radio_button_unchecked,
                                        color: Colors.grey,
                                        size: 16,
                                      ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatFormLabel(label),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: wasSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Feedback message
                if (_isChecked)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: _isCorrect
                            ? Colors.green.withOpacity(0.2)
                            : (_isPartiallyCorrect
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isCorrect
                                ? Icons.check_circle
                                : (_isPartiallyCorrect
                                      ? Icons.info
                                      : Icons.cancel),
                            color: _isCorrect
                                ? Colors.green
                                : (_isPartiallyCorrect
                                      ? Colors.orange
                                      : Colors.red),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isCorrect
                                  ? 'Richtig!'
                                  : (_isPartiallyCorrect
                                        ? 'Teilweise richtig'
                                        : 'Falsch. Versuche es erneut!'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isCorrect
                                    ? Colors.green
                                    : (_isPartiallyCorrect
                                          ? Colors.orange
                                          : Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Rating buttons or check/next button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _showRatingButtons && _isChecked
                      ? Column(
                          children: [
                            const Text(
                              'How well did you know this?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildRatingButton(
                                  Rating.again,
                                  'Again',
                                  Colors.red,
                                ),
                                const SizedBox(width: 8),
                                _buildRatingButton(
                                  Rating.hard,
                                  'Hard',
                                  Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                _buildRatingButton(
                                  Rating.good,
                                  'Good',
                                  Colors.green,
                                ),
                                const SizedBox(width: 8),
                                _buildRatingButton(
                                  Rating.easy,
                                  'Easy',
                                  Colors.blue,
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isChecked)
                              ElevatedButton(
                                onPressed:
                                    _currentItem != null &&
                                        _selectedAnswers.any(
                                          (combination) => _currentItem!
                                              .classificationSections
                                              .every(
                                                (section) =>
                                                    combination[section] !=
                                                    null,
                                              ),
                                        )
                                    ? _checkAnswers
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD0D0D0),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Prüfen',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: _nextWord,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD0D0D0),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Nächstes Wort',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildRatingButton(Rating rating, String label, Color color) {
    final isSuggested = rating == _suggestedRating;
    return ElevatedButton(
      onPressed: () => _rateCard(rating),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSuggested ? color : const Color(0xFFD0D0D0),
        foregroundColor: isSuggested ? Colors.white : Colors.black,
        elevation: isSuggested ? 4 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSuggested ? color : Colors.grey,
            width: isSuggested ? 2 : 1,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSuggested ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
