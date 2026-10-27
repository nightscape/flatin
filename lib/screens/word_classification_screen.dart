import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:fsrs/fsrs.dart';
import '../data/attribution.dart' show attributeParadigm;
import '../data/esel_groups.dart';
import '../data/esel_steps.dart';
import '../models/derivation.dart' show norm;
import '../models/exercise.dart' show bundleOf;
import '../models/practice_item.dart';
import '../models/course_filter.dart';
import '../providers/curriculum_provider.dart';
import '../providers/fsrs_provider.dart';
import '../widgets/app_drawer.dart';
import '../models/reward.dart';
import '../providers/reward_provider.dart';
import '../widgets/reward_burst.dart';
import '../widgets/esel_panel.dart';
import '../widgets/explanation_lines.dart';
import 'dart:math';

/// The pick that says "this form has no value on that axis", e.g. the Person
/// of an Infinitiv.
const String absentValue = '';

/// The dropdowns the classification screen shows for one item: one per axis
/// whose value varies among the forms the learner may be asked about. An axis
/// the enabled forms agree on is not asked, it is [fixed].
class Selectors {
  final Axes axes;

  /// The axis ids with a dropdown, in axis order.
  final List<String> sections;

  /// Per shown axis, the codes it offers in axis order; [absentValue] comes
  /// first when some enabled form has no value on that axis.
  final Map<String, List<String>> options;

  /// Axis id → the single code every enabled form has; part of every pick.
  final Map<String, String> fixed;

  const Selectors({
    required this.axes,
    required this.sections,
    required this.options,
    required this.fixed,
  });

  /// The text of one option: the axis value's own text, never a label override
  /// (S17), so the Tempus dropdown reads "Futur I" under an Infinitiv too.
  String optionText(String section, String code) =>
      code == absentValue ? '—' : axes.byId(section).display(code);

  bool isComplete(Map<String, String?> picks) =>
      sections.every((section) => picks[section] != null);

  /// The label of [labels] that [picks] names, or null if there is none.
  FormLabel? labelFor(Map<String, String?> picks, List<FormLabel> labels) {
    assert(isComplete(picks));
    final features = {
      ...fixed,
      for (final section in sections)
        if (picks[section] != absentValue) section: picks[section]!,
    };
    final key = axes.formatKey(features);
    for (final label in labels) {
      if (label.key == key) return label;
    }
    return null;
  }

  /// The right dropdowns of [combinations]: each label of [correct] goes to
  /// at most one distinct combination, best match first, and counts the
  /// dropdowns that agree with it. Ties go to the earlier combination, then
  /// the earlier label.
  int rightPicks(
    List<Map<String, String?>> combinations,
    List<FormLabel> correct,
  ) {
    final distinct = {for (final c in combinations) textOf(c): c}.values;
    final pairs = [
      for (final (i, c) in distinct.indexed)
        for (final (j, label) in correct.indexed)
          (
            combination: i,
            label: j,
            agree: sections
                .where((s) => c[s] == (label.features[s] ?? absentValue))
                .length,
          ),
    ]..sort((a, b) => b.agree.compareTo(a.agree));
    final usedCombinations = <int>{};
    final usedLabels = <int>{};
    var right = 0;
    for (final p in pairs) {
      if (p.agree == 0) break;
      if (usedCombinations.contains(p.combination) ||
          usedLabels.contains(p.label)) {
        continue;
      }
      usedCombinations.add(p.combination);
      usedLabels.add(p.label);
      right += p.agree;
    }
    return right;
  }

  /// A pick in the words of the dropdowns, e.g. "Futur I 3. Person Singular".
  String textOf(Map<String, String?> picks) => [
    for (final section in sections)
      if (picks[section] != absentValue) optionText(section, picks[section]!),
  ].join(' ');

  /// [label] in the words of the dropdowns.
  String textOfLabel(FormLabel label) => textOf({
    for (final section in sections)
      section: label.features[section] ?? absentValue,
  });
}

/// The selectors for the forms the learner may be asked about.
Selectors selectorsFor(List<FormLabel> enabledLabels) {
  assert(enabledLabels.isNotEmpty);
  final axes = enabledLabels.first.axes;
  final sections = <String>[];
  final options = <String, List<String>>{};
  final fixed = <String, String>{};

  for (final axis in axes.axes) {
    final used = {
      for (final label in enabledLabels) label.features[axis.id] ?? absentValue,
    };
    if (used.length == 1) {
      if (used.single != absentValue) fixed[axis.id] = used.single;
      continue;
    }
    sections.add(axis.id);
    options[axis.id] = [
      if (used.contains(absentValue)) absentValue,
      ...axis.codes.where(used.contains),
    ];
  }

  return Selectors(
    axes: axes,
    sections: sections,
    options: options,
    fixed: fixed,
  );
}

class WordClassificationScreen extends ConsumerStatefulWidget {
  /// Test seam: when given, these replace the random item and form pick.
  final PracticeItem? item;
  final String? formKey;

  const WordClassificationScreen({super.key, this.item, this.formKey})
    : assert(
        (item == null) == (formKey == null),
        'item and formKey are given together',
      );

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
  ({int coins, num factor, int serial})? _burst;

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

      final filter = await ref.read(courseFilterProvider.future);

      // Pick from due items if available, otherwise random
      final random = Random();
      final item =
          widget.item ??
          (allDueItems.isNotEmpty
              ? allDueItems[random.nextInt(allDueItems.length)]
              : allItems[random.nextInt(allItems.length)]);
      _isNoun = item.dataFileId == 'nouns';

      final enabledForms = filter.practicedForms(
        item.dataFileId,
        item.formLabels,
      );
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

      // Every enabled form that the shown spelling can stand for
      for (int i = 0; i < item.forms.length; i++) {
        final formKey = item.formOrder[i];
        if (!enabledForms.contains(formKey)) continue;
        if (item.acceptedForms[i].any(
          (f) => norm(f) == norm(_displayedWord!),
        )) {
          _correctFormIndices.add(i);
          _correctAnswers.add(item.formLabels[i]);
        }
      }

      _currentItem = item;
      _selectedAnswers = [_emptyCombination()];
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

    final selectors = _selectors;
    if (!_selectedAnswers.any(selectors.isComplete)) return;

    // Count correct and incorrect combinations
    int correctSelected = 0;
    int incorrectSelected = 0;

    for (final combination in _selectedAnswers) {
      if (!selectors.isComplete(combination)) continue;

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
    _payChoices(
      selectors.rightPicks(
        _selectedAnswers.where(selectors.isComplete).toList(),
        _correctAnswers,
      ),
    );
  }

  /// Sends one [ChoicesChecked] per check; a check locks the answer, so the
  /// same answer is never paid twice.
  Future<void> _payChoices(int right) async {
    if (right == 0) return;
    // Every ref use comes before the first await: the learner may leave
    // the screen while the coins are saved.
    final rewards = ref.read(rewardsProvider.notifier);
    final rules = ref.read(gameRulesProvider.future);
    final ledger = ref.read(rewardsProvider.future);
    final effects = await rewards.send(ChoicesChecked(right));
    final factor = (await rules).multiplierOf(await ledger, coins);
    final gained = effects
        .whereType<ResourceGained>()
        .where((e) => e.resource == coins)
        .fold(0, (sum, e) => sum + e.amount);
    if (!mounted) return;
    setState(
      () => _burst = (
        coins: gained,
        factor: factor,
        serial: (_burst?.serial ?? 0) + 1,
      ),
    );
  }

  Future<void> _rateCard(Rating rating) async {
    if (_currentItem == null) return;

    if (!await reviewCardReportingErrors(
      context,
      ref,
      _currentItem!,
      rating,
      _shownBundleRatings(),
    )) {
      return;
    }

    // Load next word
    _loadRandomWord();
  }

  /// Each bundle of the shown spelling is rated on its own: Again when one
  /// of its forms was not picked or a wrong combination of that bundle was
  /// picked, otherwise Good. Wrong picks in other bundles rate nothing.
  Map<String, Rating> _shownBundleRatings() {
    final item = _currentItem!;
    final picked = {
      for (final c in _selectedAnswers.where(_selectors.isComplete))
        _combinationToFormLabel(c),
    };
    final wrongBundles = {
      for (final c in _wrongCombinations)
        if (_combinationToFormLabel(c) case final label?)
          bundleOf(item, item.formOrder[item.formLabels.indexOf(label)]),
    };
    return attributeParadigm([
      for (final i in _correctFormIndices)
        (
          bundle: bundleOf(item, item.formOrder[i]),
          rating: (
            word: Rating.good,
            grammar:
                picked.contains(item.formLabels[i]) &&
                    !wrongBundles.contains(bundleOf(item, item.formOrder[i]))
                ? Rating.good
                : Rating.again,
          ),
        ),
    ]).grammar;
  }

  /// The form keys the course leaves on for [item].
  Set<String> _practicedFormsOf(PracticeItem item) {
    final filterValue = ref.read(courseFilterProvider);
    if (filterValue is! AsyncData<CourseFilter>) {
      return Set<String>.from(item.formOrder);
    }
    return filterValue.value.practicedForms(item.dataFileId, item.formLabels);
  }

  /// The labels the learner may be asked about right now.
  List<FormLabel> get _enabledLabels =>
      _currentItem!.filterForms(_practicedFormsOf(_currentItem!)).labels;

  Selectors get _selectors => selectorsFor(_enabledLabels);

  Map<String, String?> _emptyCombination() => {
    for (final section in _selectors.sections) section: null,
  };

  void _nextWord() {
    setState(() {
      _showRatingButtons = false;
      _suggestedRating = null;
    });
    _loadRandomWord();
  }

  /// The form the learner picked, or null if the item has no such form.
  FormLabel? _combinationToFormLabel(Map<String, String?> combination) =>
      _selectors.labelFor(combination, _currentItem!.formLabels);

  /// Check if a combination is correct
  bool _isCombinationCorrect(Map<String, String?> combination) {
    final formLabel = _combinationToFormLabel(combination);
    return formLabel != null && _correctAnswers.contains(formLabel);
  }

  /// Complete combinations the learner got wrong, including those that map to
  /// no label at all.
  List<Map<String, String?>> get _wrongCombinations => _selectedAnswers
      .where(_selectors.isComplete)
      .where((combination) => !_isCombinationCorrect(combination))
      .toList();

  Widget _buildExplanationBox(bool isMobile) {
    final item = _currentItem!;
    final explainer = ref.watch(explainerProvider);
    final shownKeys = _correctFormIndices
        .map((i) => item.formOrder[i])
        .toList();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6.0 : 8.0),
      child: Container(
        key: const Key('explanation.classification'),
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: outlineColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, group) in groupReadings(item, shownKeys).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EselStaticSteps(
                  scope: i == 0
                      ? 'esel.classification'
                      : 'esel.classification.$i',
                  title: groupTitle(item, group),
                  steps: eselSteps(item, group.first),
                ),
              ),
            ..._wrongCombinations.map(
              (combination) => ExplanationLines([
                explainer.pickedLabel(
                  item,
                  _combinationToFormLabel(combination),
                  _selectors.textOf(combination),
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

    final selectors = _selectors;
    final combination = _selectedAnswers[index];
    final isComplete = selectors.isComplete(combination);
    final isCorrect =
        _isChecked && isComplete && _isCombinationCorrect(combination);
    final isIncorrect = _isChecked && !isCorrect && isComplete;

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
                    : (isIncorrect ? Colors.red : mutedText))
              : mutedText,
          width: _isChecked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: isMobile ? 8 : 12,
              runSpacing: isMobile ? 8 : 12,
              children: selectors.sections.map((section) {
                return SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: DropdownButtonFormField<String>(
                    key: Key('classification.$index.$section'),
                    isExpanded: true,
                    value: combination[section],
                    decoration: InputDecoration(
                      labelText: selectors.axes.byId(section).name,
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
                      ...selectors.options[section]!.map(
                        (code) => DropdownMenuItem<String>(
                          value: code,
                          child: Text(selectors.optionText(section, code)),
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

    // Watch the course filter and reload the word if its form becomes hidden
    ref.listen<AsyncValue<CourseFilter>>(courseFilterProvider, (
      previous,
      next,
    ) {
      if (previous != next &&
          next is AsyncData<CourseFilter> &&
          _currentItem != null &&
          _correctFormIndices.isNotEmpty) {
        final enabledForms = next.value.practicedForms(
          _currentItem!.dataFileId,
          _currentItem!.formLabels,
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
      drawer: buildAppDrawer(context),
      // The burst rides in the button slot so it floats above the page.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      floatingActionButton: switch (_burst) {
        (:final coins, :final factor, :final serial) => RewardBurst(
          coins,
          factor: factor,
          key: ValueKey(serial),
        ),
        null => null,
      },
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_drop_down),
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
                FlutterI18n.translate(
                  context,
                  'wordClassification.noWordsAvailable',
                ),
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
                    key: Key(
                      _isNoun
                          ? 'wordClassification.declension'
                          : 'wordClassification.conjugation',
                    ),
                    _isNoun
                        ? FlutterI18n.translate(
                            context,
                            'wordClassification.declension',
                          )
                        : FlutterI18n.translate(
                            context,
                            'wordClassification.conjugation',
                          ),
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
                      border: Border.all(color: outlineColor, width: 2),
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
                                color: mutedText,
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
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
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
                                  _selectedAnswers.add(_emptyCombination());
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: Text(
                                FlutterI18n.translate(
                                  context,
                                  'wordClassification.addCombination',
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
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

                        // Display all correct combinations
                        if (_isChecked && _correctAnswers.isNotEmpty)
                          Container(
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
                                        FlutterI18n.translate(
                                          context,
                                          'wordClassification.allCorrectCombinations',
                                        ),
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
                                    final wasSelected = _selectedAnswers
                                        .where(_selectors.isComplete)
                                        .any(
                                          (combination) =>
                                              _combinationToFormLabel(
                                                combination,
                                              ) ==
                                              label,
                                        );

                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 10 : 12,
                                        vertical: isMobile ? 6 : 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: wasSelected
                                            ? Colors.green.withOpacity(0.2)
                                            : outlineColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: wasSelected
                                              ? Colors.green
                                              : mutedText,
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
                                              color: mutedText,
                                              size: isMobile ? 14 : 16,
                                            ),
                                          SizedBox(width: isMobile ? 4 : 6),
                                          Flexible(
                                            child: Text(
                                              _selectors.textOfLabel(label),
                                              style: TextStyle(
                                                fontSize: isMobile
                                                    ? 12.0
                                                    : 14.0,
                                                fontWeight: wasSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: Colors.black,
                                              ),
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

                        // How the shown form follows from the rule, and what the wrong
                        // picks would have been
                        if (_isChecked && _wrongCombinations.isNotEmpty)
                          _buildExplanationBox(isMobile),

                        // Feedback message
                        if (_isChecked)
                          Padding(
                            padding: EdgeInsets.symmetric(
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
                                          ? FlutterI18n.translate(
                                              context,
                                              'wordClassification.correct',
                                            )
                                          : (_isPartiallyCorrect
                                                ? FlutterI18n.translate(
                                                    context,
                                                    'wordClassification.partiallyCorrect',
                                                  )
                                                : FlutterI18n.translate(
                                                    context,
                                                    'wordClassification.incorrect',
                                                  )),
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
                              FlutterI18n.translate(
                                context,
                                'wordClassification.howWellDidYouKnow',
                              ),
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
                                  FlutterI18n.translate(
                                    context,
                                    'wordClassification.rating.again',
                                  ),
                                  Colors.red,
                                  isMobile,
                                ),
                                _buildRatingButton(
                                  Rating.hard,
                                  FlutterI18n.translate(
                                    context,
                                    'wordClassification.rating.hard',
                                  ),
                                  Colors.orange,
                                  isMobile,
                                ),
                                _buildRatingButton(
                                  Rating.good,
                                  FlutterI18n.translate(
                                    context,
                                    'wordClassification.rating.good',
                                  ),
                                  Colors.green,
                                  isMobile,
                                ),
                                _buildRatingButton(
                                  Rating.easy,
                                  FlutterI18n.translate(
                                    context,
                                    'wordClassification.rating.easy',
                                  ),
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
                                key: const Key(
                                  'wordClassification.check.button',
                                ),
                                onPressed:
                                    _selectedAnswers.any(_selectors.isComplete)
                                    ? _checkAnswers
                                    : null,
                                style: ElevatedButton.styleFrom(
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
                                  FlutterI18n.translate(
                                    context,
                                    'wordClassification.check',
                                  ),
                                  style: TextStyle(
                                    fontSize: isMobile ? 14.0 : 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              ElevatedButton(
                                key: const Key(
                                  'wordClassification.nextWord.button',
                                ),
                                onPressed: _nextWord,
                                style: ElevatedButton.styleFrom(
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
                                  FlutterI18n.translate(
                                    context,
                                    'wordClassification.nextWord',
                                  ),
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

  Widget _buildRatingButton(
    Rating rating,
    String label,
    Color color,
    bool isMobile,
  ) {
    final isSuggested = rating == _suggestedRating;
    final key = Key('rating.${rating.name}');
    return ElevatedButton(
      key: key,
      onPressed: () => _rateCard(rating),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSuggested ? color : null,
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
            color: isSuggested ? color : mutedText,
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
