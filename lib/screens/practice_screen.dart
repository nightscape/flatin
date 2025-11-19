import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsrs/fsrs.dart';
import '../models/practice_item.dart';
import '../providers/practice_providers.dart';
import '../providers/settings_provider.dart';
import '../providers/fsrs_provider.dart';
import '../widgets/app_drawer.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  final PracticeItem item;

  const PracticeScreen({super.key, required this.item});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  final List<TextEditingController> _controllers = [];
  List<String> _filteredForms = [];
  List<FormLabel> _filteredLabels = [];
  Rating? _suggestedRating;
  bool _showRatingButtons = false;

  @override
  void initState() {
    super.initState();
    // Controllers will be initialized in build based on filtered forms
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateControllers(int newCount) {
    // Dispose old controllers if count decreased
    while (_controllers.length > newCount) {
      _controllers.removeLast().dispose();
    }
    // Add new controllers if count increased
    while (_controllers.length < newCount) {
      _controllers.add(TextEditingController());
    }
  }

  void _checkAnswers() {
    final notifier = ref.read(practiceProvider(widget.item).notifier);
    final userAnswers = _controllers.map((c) => c.text).toList();
    final correctAnswers = _filteredForms;
    notifier.checkAnswers(userAnswers, correctAnswers);

    // Calculate auto-suggested rating based on results
    final state = ref.read(practiceProvider(widget.item));
    final results = state.validationResults;
    final totalAnswers = results.where((r) => r != null).length;
    final correctCount = results.where((r) => r == true).length;

    if (totalAnswers == 0) {
      _suggestedRating = Rating.again;
    } else if (correctCount == totalAnswers) {
      _suggestedRating = Rating.good;
    } else if (correctCount > 0) {
      _suggestedRating = Rating.hard;
    } else {
      _suggestedRating = Rating.again;
    }

    setState(() {
      _showRatingButtons = true;
    });
  }

  void _hideAnswers() {
    final notifier = ref.read(practiceProvider(widget.item).notifier);
    notifier.hideAnswers();
    setState(() {
      _showRatingButtons = false;
      _suggestedRating = null;
    });
  }

  Future<void> _rateCard(Rating rating) async {
    // Review the card with FSRS
    await reviewCard(ref, widget.item, rating);

    // Navigate to next due item or return to home
    final nextItem = await ref.read(
      nextDueItemProvider(widget.item.dataFileId).future,
    );

    if (mounted) {
      if (nextItem != null && nextItem != widget.item) {
        // Navigate to next due item
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) {
              if (widget.item.dataFileId == 'nouns') {
                return PracticeScreen(item: nextItem);
              } else {
                return PracticeScreen(item: nextItem);
              }
            },
          ),
        );
      } else {
        // No more due items, return to home
        Navigator.of(context).pop();
      }
    }
  }

  Color _getBorderColor(int index, PracticeState state) {
    if (!state.isChecked || state.validationResults[index] == null) {
      return Colors.grey;
    }
    return state.validationResults[index]! ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceProvider(widget.item));
    final settingsAsync = ref.watch(settingsProvider);

    // Filter forms based on settings
    final filteredData = settingsAsync.when(
      data: (settings) {
        final enabledForms =
            settings.enabledForms[widget.item.dataFileId] ??
            Set<String>.from(widget.item.formOrder);
        return widget.item.filterForms(enabledForms);
      },
      loading: () =>
          widget.item.filterForms(Set<String>.from(widget.item.formOrder)),
      error: (_, __) =>
          widget.item.filterForms(Set<String>.from(widget.item.formOrder)),
    );

    _filteredForms = filteredData.forms;
    _filteredLabels = filteredData.labels;
    _updateControllers(_filteredForms.length);

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
      body: Column(
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Text(
              widget.item.type,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          // Practice table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        if (state.isTranslationVisible)
                          Expanded(
                            flex: 1,
                            child: const Text(
                              'Translation:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        if (state.isTranslationVisible)
                          const SizedBox(width: 24),
                        Expanded(
                          flex: state.isTranslationVisible ? 1 : 2,
                          child: Text(
                            widget.item.translation,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Base form row (if applicable, e.g., infinitive for verbs)
                  if (widget.item.baseForm != null &&
                      widget.item.baseFormLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          if (state.isTranslationVisible)
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${widget.item.baseFormLabel}:',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          if (state.isTranslationVisible)
                            const SizedBox(width: 24),
                          Expanded(
                            flex: state.isTranslationVisible ? 1 : 2,
                            child: Text(
                              widget.item.baseForm!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Table with aligned rows
                  Expanded(
                    child: Table(
                      columnWidths: state.isTranslationVisible
                          ? {
                              0: const FlexColumnWidth(1),
                              1: const FlexColumnWidth(1),
                            }
                          : {
                              0: const FlexColumnWidth(0),
                              1: const FlexColumnWidth(2),
                            },
                      children: List.generate(_filteredForms.length, (index) {
                        final correctAnswer = _filteredForms[index];
                        return TableRow(
                          children: [
                            // Left column - Form label
                            Padding(
                              padding: EdgeInsets.only(
                                right: state.isTranslationVisible ? 24.0 : 0.0,
                                bottom: 12.0,
                              ),
                              child: SizedBox(
                                height: 40, // Match input field height
                                child: state.isTranslationVisible
                                    ? Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _filteredLabels[index].displayName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            // Right column - Input field and answer
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _controllers[index],
                                      enabled: !state.isChecked,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          borderSide: BorderSide(
                                            color: _getBorderColor(
                                              index,
                                              state,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          borderSide: BorderSide(
                                            color: _getBorderColor(
                                              index,
                                              state,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          borderSide: BorderSide(
                                            color: _getBorderColor(
                                              index,
                                              state,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      ),
                                    ),
                                  ),
                                  if (state.isChecked &&
                                      index < state.validationResults.length &&
                                      state.validationResults[index] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12.0,
                                      ),
                                      child: Text(
                                        correctAnswer,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: state.validationResults[index]!
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rating buttons or check/hide button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _showRatingButtons && state.isChecked
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
                          _buildRatingButton(Rating.again, 'Again', Colors.red),
                          const SizedBox(width: 8),
                          _buildRatingButton(
                            Rating.hard,
                            'Hard',
                            Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _buildRatingButton(Rating.good, 'Good', Colors.green),
                          const SizedBox(width: 8),
                          _buildRatingButton(Rating.easy, 'Easy', Colors.blue),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: state.isChecked
                            ? _hideAnswers
                            : _checkAnswers,
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
                        child: Text(
                          state.isChecked ? 'hide' : 'check',
                          style: const TextStyle(
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
