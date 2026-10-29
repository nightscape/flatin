import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/attribution.dart';
import '../data/exercise_feedback.dart';
import '../models/exercise.dart';
import '../models/input_strategy.dart';
import '../models/practice_item.dart';
import '../widgets/explanation_lines.dart';

/// Shows one principal-parts [Exercise]: one input per part, each following
/// [inputStrategy]; after the feedback, "next" hands the texts to
/// [onResponse] once.
class ExercisePartsWidget extends StatefulWidget {
  final PracticeItem word;
  final Exercise exercise;

  /// The app bar title; null shows the standard exercise title.
  final String? title;
  final InputStrategy inputStrategy;

  /// The forms of [word] the dropdowns offer besides the asked parts.
  final Set<FormKey> optionForms;
  final void Function(TypedTexts response) onResponse;

  const ExercisePartsWidget({
    super.key,
    required this.word,
    required this.exercise,
    this.title,
    required this.inputStrategy,
    required this.optionForms,
    required this.onResponse,
  });

  @override
  State<ExercisePartsWidget> createState() => _ExercisePartsWidgetState();
}

class _ExercisePartsWidgetState extends State<ExercisePartsWidget> {
  static const _contentWidth = 600.0;

  late List<String> _texts = _empty();
  bool _checked = false;
  bool _reported = false;

  PartsAnswer get _answer => widget.exercise.answer as PartsAnswer;

  List<String> _empty() => List.filled(_answer.slots.length, '');

  @override
  void didUpdateWidget(ExercisePartsWidget old) {
    super.didUpdateWidget(old);
    if (old.exercise != widget.exercise) {
      _texts = _empty();
      _checked = false;
      _reported = false;
    }
  }

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? _t('exercise.screen.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          // A new exercise starts with new input fields.
          child: ListView(
            key: ValueKey(exercise),
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                _t(exercise.questionKey, exercise.questionParams),
                key: const Key('exercise.question'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ..._row(),
              if (!_checked)
                ElevatedButton(
                  key: const Key('exercise.check.button'),
                  onPressed: () => setState(() => _checked = true),
                  child: Text(_t('exercise.screen.check')),
                ),
              if (_checked) ..._feedback(),
            ],
          ),
        ),
      ),
    );
  }

  /// The parts in the order of the row: a given part as its text, an asked
  /// part as its input.
  List<Widget> _row() {
    final given = {for (final g in _answer.given) g.at: g};
    final widgets = <Widget>[];
    var i = 0;
    for (var at = 0; at < _answer.slots.length + given.length; at++) {
      if (given[at] case (:final name, :final form, at: _)) {
        widgets.addAll([
          Text(_t(name)),
          const SizedBox(height: 4),
          Text(
            form.text,
            key: Key('exercise.given.$at'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ]);
      } else {
        widgets.addAll([
          Text(_t(_answer.slots[i].name)),
          const SizedBox(height: 4),
          _input(i++),
        ]);
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _input(int i) {
    final answer = _answer.slots[i].answer;
    final offered = widget.word.filterForms({
      ...widget.optionForms,
      for (final (name: _, :answer) in _answer.slots) answer.expected.formKey,
    });
    return KeyedSubtree(
      key: Key('exercise.slot.$i'),
      child: widget.inputStrategy.buildInput(
        InputContext(
          index: offered.keys.indexOf(answer.expected.formKey),
          correctAnswer: answer.expected.text,
          allForms: offered.forms,
          inferredForms: offered.inferredForms,
          isChecked: _checked,
          borderColor: Theme.of(context).colorScheme.outline,
          labelFontSize: 16,
          isMobile: MediaQuery.sizeOf(context).width < 600,
          currentValue: _texts[i],
          onChanged: (value) => setState(() => _texts[i] = value),
        ),
      ),
    );
  }

  List<Widget> _feedback() {
    final response = TypedTexts([..._texts]);
    final right = isRight(attribute(widget.word, widget.exercise, response));
    return [
      const SizedBox(height: 8),
      Text(
        right
            ? _t('exercise.screen.right')
            : _t('exercise.screen.wrong', {
                'answer': [
                  for (final (name: _, :answer) in _answer.slots)
                    answer.expected.text,
                ].join(', '),
              }),
        key: const Key('exercise.feedback'),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: right ? Colors.green.shade800 : null,
        ),
      ),
      const SizedBox(height: 8),
      ExplanationLines(
        feedbackLines(widget.word, widget.exercise, response),
        key: const Key('exercise.feedback.lines'),
      ),
      const SizedBox(height: 8),
      ElevatedButton(
        key: const Key('exercise.next.button'),
        onPressed: () {
          if (_reported) return;
          setState(() => _reported = true);
          widget.onResponse(response);
        },
        child: Text(_t('exercise.screen.next')),
      ),
    ];
  }
}
