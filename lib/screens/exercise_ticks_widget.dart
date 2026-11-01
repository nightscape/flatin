import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/attribution.dart';
import '../data/exercise_feedback.dart';
import '../models/exercise.dart';
import '../models/practice_item.dart';
import '../widgets/explanation_lines.dart';

/// Shows one [TickAnswer] exercise: the learner ticks every right rendering
/// and checks; after the feedback, "next" hands the ticks to [onResponse]
/// once.
class ExerciseTicksWidget extends StatefulWidget {
  final PracticeItem word;
  final Exercise exercise;

  /// The app bar title; null shows the standard exercise title.
  final String? title;
  final void Function(TickedOptions response) onResponse;

  const ExerciseTicksWidget({
    super.key,
    required this.word,
    required this.exercise,
    this.title,
    required this.onResponse,
  });

  @override
  State<ExerciseTicksWidget> createState() => _ExerciseTicksWidgetState();
}

class _ExerciseTicksWidgetState extends State<ExerciseTicksWidget> {
  static const _contentWidth = 600.0;

  final _ticked = <int>{};
  bool _checked = false;
  bool _reported = false;

  TickAnswer get _answer => widget.exercise.answer as TickAnswer;

  @override
  void didUpdateWidget(ExerciseTicksWidget old) {
    super.didUpdateWidget(old);
    if (old.exercise != widget.exercise) {
      _ticked.clear();
      _checked = false;
      _reported = false;
    }
  }

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  TickedOptions get _response => TickedOptions({..._ticked});

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? _t('exercise.screen.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: ListView(
            // A new exercise starts at the top.
            key: ObjectKey(exercise),
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                _t(exercise.questionKey, exercise.questionParams),
                key: const Key('exercise.question'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final (i, (:text, :mistake)) in _answer.options.indexed)
                _tickRow(i, text, right: mistake == null),
              if (!_checked) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('exercise.check.button'),
                  onPressed: _ticked.isEmpty
                      ? null
                      : () => setState(() => _checked = true),
                  child: Text(_t('exercise.screen.check')),
                ),
              ],
              if (_checked) ..._feedback(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tickRow(int i, String text, {required bool right}) => Card(
    color: !_checked
        ? null
        : _ticked.contains(i) == right
        ? Colors.green.shade100
        : Colors.red.shade100,
    child: CheckboxListTile(
      key: Key('exercise.ticks.option.$i'),
      title: Text(text),
      value: _ticked.contains(i),
      onChanged: _checked
          ? null
          : (ticked) =>
                setState(() => ticked! ? _ticked.add(i) : _ticked.remove(i)),
    ),
  );

  List<Widget> _feedback() {
    final right = isRight(attribute(widget.word, widget.exercise, _response));
    return [
      const SizedBox(height: 16),
      Text(
        right
            ? _t('exercise.screen.right')
            : _t('exercise.screen.wrong', {
                'answer': [
                  for (final i in _answer.right) _answer.options[i].text,
                ].join(' / '),
              }),
        key: const Key('exercise.feedback'),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: right ? Colors.green.shade800 : null,
        ),
      ),
      const SizedBox(height: 8),
      ExplanationLines(
        feedbackLines(widget.word, widget.exercise, _response),
        key: const Key('exercise.feedback.lines'),
      ),
      const SizedBox(height: 8),
      ElevatedButton(
        key: const Key('exercise.next.button'),
        onPressed: () {
          if (_reported) return;
          setState(() => _reported = true);
          widget.onResponse(_response);
        },
        child: Text(_t('exercise.screen.next')),
      ),
    ];
  }
}
