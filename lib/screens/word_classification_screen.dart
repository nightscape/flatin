import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:fsrs/fsrs.dart';
import '../models/practice_item.dart';
import '../models/settings.dart';
import '../providers/settings_provider.dart';
import '../providers/fsrs_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/explanation_lines.dart';
import 'dart:math';

class WordClassificationScreen extends ConsumerStatefulWidget {
  /// Test seam: when given, these replace the random item and form pick.
  final PracticeItem? item;
  final String? formKey;

  const WordClassificationScreen({super.key, this.item, this.formKey})
      : assert((item == null) == (formKey == null),
            'item and formKey are given together');

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

      // Fall back to the same filtered items the due list is drawn from
      final practicable = await ref.read(practicableItemsByTypeProvider.future);
      final allItems = [...practicable['nouns']!, ...practicable['verbs']!];

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
      final item = widget.item ??
          (allDueItems.isNotEmpty
              ? allDueItems[random.nextInt(allDueItems.length)]
              : allItems[random.nextInt(allItems.length)]);
      _isNoun = item.dataFileId == 'nouns';

      // Filter forms based on settings
      final enabledForms =
          settings.enabledFormsOf(item.dataFileId, item.formOrder);
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
      _displayedWord = widget.formKey != null
          ? item.forms[item.formOrder.indexOf(widget.formKey!)]
          : filteredData.forms[random.nextInt(filteredData.forms.length)];

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
      for (final section in _sectionsOf(item)) {
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
      (combination) =>
          _sections.every((section) => combination[section] != null),
    );

    if (!atLeastOneComplete) return;

    // Count correct and incorrect combinations
    int correctSelected = 0;
    int incorrectSelected = 0;

    for (final combination in _selectedAnswers) {
      // Only check complete combinations
      final isComplete =
          _sections.every((section) => combination[section] != null);

      if (!isComplete) continue;

      final formLabel = _combinationToFormLabel(combination);
      if (formLabel != null) {
        if (_correctAnswers.contains(formLabel)) {
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
    if (!await reviewCardReportingErrors(context, ref, _currentItem!, rating)) {
      return;
    }

    // Load next word
    _loadRandomWord();
  }

  /// The feature axes of [item], in the order the selectors appear.
  static List<String> _sectionsOf(PracticeItem item) =>
      item.formLabels.first.axes.axes.map((axis) => axis.id).toList();

  List<String> get _sections => _sectionsOf(_currentItem!);

  /// The value texts a selector offers, in the order the enabled forms first
  /// name them.
  List<String> _getOptionsForSection(String section) {
    if (_currentItem == null) return [];

    // Filter form labels based on settings
    final settingsValue = ref.read(settingsProvider);
    Settings? settings;
    if (settingsValue is AsyncData<Settings>) {
      settings = settingsValue.value;
    }
    final enabledForms = settings?.enabledFormsOf(
          _currentItem!.dataFileId,
          _currentItem!.formOrder,
        ) ??
        Set<String>.from(_currentItem!.formOrder);
    final filteredData = _currentItem!.filterForms(enabledForms);
    final availableFormLabels = filteredData.labels;

    final options = <String>[];
    for (final label in availableFormLabels) {
      final text = label.display(section);
      if (text != null && !options.contains(text)) options.add(text);
    }
    return options;
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
      if (_sections.every(
        (section) => label.display(section) == combination[section],
      )) {
        return label;
      }
    }
    return null;
  }

  /// Format FormLabel for display (e.g., "Nominativ Plural" or "Präsens 1. Person Singular")
  String _formatFormLabel(FormLabel label) =>
      _sections.map(label.display).nonNulls.join(' ');

  /// Check if a combination is correct
  bool _isCombinationCorrect(Map<String, String?> combination) {
    final formLabel = _combinationToFormLabel(combination);
    return formLabel != null && _correctAnswers.contains(formLabel);
  }

  /// Complete combinations the learner got wrong, including those that map to
  /// no label at all.
  List<Map<String, String?>> get _wrongCombinations => _selectedAnswers
      .where((combination) =>
          _sections.every((section) => combination[section] != null))
      .where((combination) => !_isCombinationCorrect(combination))
      .toList();

  /// A combination as the screen shows it, e.g. "Vokativ Plural".
  String _combinationText(Map<String, String?> combination) =>
      _sections.map((section) => combination[section]!).join(' ');

  Widget _buildExplanationBox(bool isMobile, double horizontalPadding) {
    final item = _currentItem!;
    final explainer = ref.watch(explainerProvider);
    final shownKeys =
        _correctFormIndices.map((i) => item.formOrder[i]).toList();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isMobile ? 6.0 : 8.0,
      ),
      child: Container(
        key: const Key('explanation.classification'),
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExplanationLines(explainer.form(item, shownKeys)),
            ..._wrongCombinations.map(
              (combination) => ExplanationLines([
                explainer.pickedLabel(
                  item,
                  _combinationToFormLabel(combination),
                  _combinationText(combination),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a combination selector widget
  Widget _buildCombinationSelector(int index, bool isMobile) {
    if (_currentItem == null) return const SizedBox();

    final combination = _selectedAnswers[index];
    final isCorrect = _isChecked && _isCombinationCorrect(combination);
    final isIncorrect =
        _isChecked && !isCorrect && combination.values.every((v) => v != null);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
              spacing: isMobile ? 8 : 12,
              runSpacing: isMobile ? 8 : 12,
              children: _sections.map((section) {
                final options = _getOptionsForSection(section);
                final selectedValue = combination[section];

                return SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedValue,
                    decoration: InputDecoration(
                      labelText: _currentItem!.formLabels.first.axes
                          .byId(section)
                          .name,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 12 : 16,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Watch settings and reload word if current form becomes disabled
    ref.listen<AsyncValue<Settings>>(settingsProvider, (previous, next) {
      if (previous != next &&
          next is AsyncData<Settings> &&
          _currentItem != null &&
          _correctFormIndices.isNotEmpty) {
        final settings = next.value;
        final enabledForms = settings.enabledFormsOf(
          _currentItem!.dataFileId,
          _currentItem!.formOrder,
        );

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

    // Responsive values
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 16.0;
    final titleFontSize = isMobile ? 24.0 : 32.0;
    final wordFontSize = isMobile ? 36.0 : 48.0;
    final translationFontSize = isMobile ? 14.0 : 18.0;
    final buttonPadding = isMobile ? 16.0 : 24.0;

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
          ? Center(
              child: Text(
                FlutterI18n.translate(context, 'wordClassification.noWordsAvailable'),
                style: TextStyle(fontSize: isMobile ? 16.0 : 18.0),
              ),
            )
          : Column(
              children: [
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Text(
                    key: Key(_isNoun
                        ? 'wordClassification.declension'
                        : 'wordClassification.conjugation'),
                    _isNoun
                        ? FlutterI18n.translate(context, 'wordClassification.declension')
                        : FlutterI18n.translate(context, 'wordClassification.conjugation'),
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),

                // Word display
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: isMobile ? 16.0 : 24.0,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          key: const Key('wordClassification.word'),
                          _displayedWord!,
                          style: TextStyle(
                            fontSize: wordFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (_currentItem!.translation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _currentItem!.translation,
                              style: TextStyle(
                                fontSize: translationFontSize,
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
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display all combination selectors
                        ...List.generate(_selectedAnswers.length, (index) {
                          return _buildCombinationSelector(index, isMobile);
                        }),
                        // Add button to add new combination
                        if (!_isChecked)
                          Padding(
                            padding: EdgeInsets.only(top: isMobile ? 8.0 : 8.0),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  final newCombination = <String, String?>{};
                                  for (final section in _sections) {
                                    newCombination[section] = null;
                                  }
                                  _selectedAnswers.add(newCombination);
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: Text(
                                FlutterI18n.translate(context, 'wordClassification.addCombination'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD0D0D0),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 10 : 12,
                                ),
                                minimumSize: Size(0, isMobile ? 44 : 48),
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
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
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
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: isMobile ? 18 : 24,
                              ),
                              SizedBox(width: isMobile ? 6 : 8),
                              Expanded(
                                child: Text(
                                  FlutterI18n.translate(context, 'wordClassification.allCorrectCombinations'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 14.0 : 16.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          Wrap(
                            spacing: isMobile ? 6 : 8,
                            runSpacing: isMobile ? 6 : 8,
                            children: _correctAnswers.map((label) {
                              // Check if this combination was selected
                              final wasSelected = _selectedAnswers.any((
                                combination,
                              ) {
                                final formLabel = _combinationToFormLabel(
                                  combination,
                                );
                                return formLabel == label;
                              });

                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 10 : 12,
                                  vertical: isMobile ? 6 : 8,
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
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: isMobile ? 14 : 16,
                                      )
                                    else
                                      Icon(
                                        Icons.radio_button_unchecked,
                                        color: Colors.grey,
                                        size: isMobile ? 14 : 16,
                                      ),
                                    SizedBox(width: isMobile ? 4 : 6),
                                    Text(
                                      _formatFormLabel(label),
                                      style: TextStyle(
                                        fontSize: isMobile ? 12.0 : 14.0,
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

                // How the shown form follows from the rule, and what the wrong
                // picks would have been
                if (_isChecked && _wrongCombinations.isNotEmpty)
                  _buildExplanationBox(isMobile, horizontalPadding),

                // Feedback message
                if (_isChecked)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isMobile ? 6.0 : 8.0,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
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
                            size: isMobile ? 20 : 24,
                          ),
                          SizedBox(width: isMobile ? 8 : 12),
                          Expanded(
                            child: Text(
                              _isCorrect
                                  ? FlutterI18n.translate(context, 'wordClassification.correct')
                                  : (_isPartiallyCorrect
                                        ? FlutterI18n.translate(context, 'wordClassification.partiallyCorrect')
                                        : FlutterI18n.translate(context, 'wordClassification.incorrect')),
                              style: TextStyle(
                                fontSize: isMobile ? 14.0 : 16.0,
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
                  padding: EdgeInsets.all(buttonPadding),
                  child: _showRatingButtons && _isChecked
                      ? Column(
                          children: [
                            Text(
                              FlutterI18n.translate(context, 'wordClassification.howWellDidYouKnow'),
                              style: TextStyle(
                                fontSize: isMobile ? 14.0 : 16.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: isMobile ? 12.0 : 16.0),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: isMobile ? 4.0 : 8.0,
                              runSpacing: isMobile ? 8.0 : 0.0,
                              children: [
                                _buildRatingButton(
                                  Rating.again,
                                  FlutterI18n.translate(context, 'wordClassification.rating.again'),
                                  Colors.red,
                                  isMobile,
                                ),
                                _buildRatingButton(
                                  Rating.hard,
                                  FlutterI18n.translate(context, 'wordClassification.rating.hard'),
                                  Colors.orange,
                                  isMobile,
                                ),
                                _buildRatingButton(
                                  Rating.good,
                                  FlutterI18n.translate(context, 'wordClassification.rating.good'),
                                  Colors.green,
                                  isMobile,
                                ),
                                _buildRatingButton(
                                  Rating.easy,
                                  FlutterI18n.translate(context, 'wordClassification.rating.easy'),
                                  Colors.blue,
                                  isMobile,
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
                                key: const Key('wordClassification.check.button'),
                                onPressed:
                                    _currentItem != null &&
                                        _selectedAnswers.any(
                                          (combination) => _sections.every(
                                            (section) =>
                                                combination[section] != null,
                                          ),
                                        )
                                    ? _checkAnswers
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD0D0D0),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 32 : 48,
                                    vertical: isMobile ? 10 : 12,
                                  ),
                                  minimumSize: Size(0, isMobile ? 44 : 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  FlutterI18n.translate(context, 'wordClassification.check'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 14.0 : 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              ElevatedButton(
                                key: const Key('wordClassification.nextWord.button'),
                                onPressed: _nextWord,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD0D0D0),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 32 : 48,
                                    vertical: isMobile ? 10 : 12,
                                  ),
                                  minimumSize: Size(0, isMobile ? 44 : 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  FlutterI18n.translate(context, 'wordClassification.nextWord'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 14.0 : 16.0,
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

  Widget _buildRatingButton(Rating rating, String label, Color color, bool isMobile) {
    final isSuggested = rating == _suggestedRating;
    final key = Key('rating.${rating.name}');
    return ElevatedButton(
      key: key,
      onPressed: () => _rateCard(rating),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSuggested ? color : const Color(0xFFD0D0D0),
        foregroundColor: isSuggested ? Colors.white : Colors.black,
        elevation: isSuggested ? 4 : 0,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 10 : 12,
        ),
        minimumSize: Size(0, isMobile ? 44 : 48),
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
          fontSize: isMobile ? 12.0 : 14.0,
          fontWeight: isSuggested ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
