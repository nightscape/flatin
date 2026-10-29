import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/exercise_feedback.dart';
import '../models/exercise.dart';
import '../models/practice_item.dart';
import '../widgets/explanation_lines.dart';

/// Shows one sorting [Exercise]: the learner ticks the forms of the asked
/// group, or drags every form into its group; after the feedback, "next" hands
/// the groups to [onResponse] once.
/// Produced here for the caller that wires the exercises into the app.
class ExerciseSortWidget extends StatefulWidget {
  final PracticeItem word;
  final Exercise exercise;

  /// The app bar title; null shows the standard exercise title.
  final String? title;
  final void Function(SortedForms response) onResponse;

  const ExerciseSortWidget({
    super.key,
    required this.word,
    required this.exercise,
    this.title,
    required this.onResponse,
  });

  @override
  State<ExerciseSortWidget> createState() => _ExerciseSortWidgetState();
}

class _ExerciseSortWidgetState extends State<ExerciseSortWidget> {
  static const _contentWidth = 600.0;

  /// Form index → group index.
  final _given = <int, int>{};
  bool _checked = false;
  bool _reported = false;

  SortingAnswer get _answer => widget.exercise.answer as SortingAnswer;

  @override
  void didUpdateWidget(ExerciseSortWidget old) {
    super.didUpdateWidget(old);
    if (old.exercise != widget.exercise) {
      _given.clear();
      _checked = false;
      _reported = false;
    }
  }

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  /// An unticked form of a tick answer is in the second group.
  int? _groupOf(int form) => _answer.tick ? _given[form] ?? 1 : _given[form];

  SortedForms get _response => SortedForms({
    for (final (i, (option, _)) in _answer.forms.indexed) option: _groupOf(i)!,
  });

  bool get _isRight =>
      _answer.forms.indexed.every((e) => _groupOf(e.$1) == e.$2.$2);

  bool get _complete => _answer.tick || _given.length == _answer.forms.length;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? _t('exercise.screen.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                _t(exercise.questionKey, exercise.questionParams),
                key: const Key('exercise.question'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!_answer.tick) ...[
                const SizedBox(height: 8),
                Text(_t('exercise.sort.hint')),
              ],
              const SizedBox(height: 16),
              if (_answer.tick)
                for (final (i, (option, right)) in _answer.forms.indexed)
                  _tickRow(i, option, right)
              else
                _sortBoard(),
              if (!_checked && _complete) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('exercise.check.button'),
                  onPressed: () => setState(() => _checked = true),
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

  Color? _verdict(int form, int right) => !_checked
      ? null
      : _groupOf(form) == right
      ? Colors.green.shade100
      : Colors.red.shade100;

  Widget _tickRow(int i, FormOption option, int right) => Card(
    color: _verdict(i, right),
    child: CheckboxListTile(
      key: Key('exercise.sort.form.$i'),
      title: Text(option.text),
      value: _groupOf(i) == 0,
      onChanged: _checked
          ? null
          : (ticked) => setState(() => _given[i] = ticked! ? 0 : 1),
    ),
  );

  Widget _formChip(FormOption option, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(option.text, style: Theme.of(context).textTheme.bodySmall),
    ),
  );

  Widget _draggableForm(int i, FormOption option, int right) {
    final chip = _formChip(option, color: _verdict(i, right));
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: option.text,
      child: Draggable<int>(
        key: Key('exercise.sort.form.$i'),
        data: i,
        maxSimultaneousDrags: _checked ? 0 : 1,
        onDraggableCanceled: (_, _) => setState(() => _given.remove(i)),
        feedback: Material(color: Colors.transparent, child: chip),
        childWhenDragging: Opacity(opacity: 0.3, child: chip),
        child: chip,
      ),
    );
  }

  Widget _pool() => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final (i, (option, right)) in _answer.forms.indexed)
        if (!_given.containsKey(i)) _draggableForm(i, option, right),
    ],
  );

  Widget _groupBox(int g) => Expanded(
    child: DragTarget<int>(
      onWillAcceptWithDetails: (_) => !_checked,
      onAcceptWithDetails: (d) => setState(() => _given[d.data] = g),
      builder: (context, candidates, _) => Semantics(
        container: true,
        label: _answer.groups[g],
        child: Container(
          key: Key('exercise.sort.group.$g'),
          constraints: const BoxConstraints(minHeight: 170),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(
              color: candidates.isEmpty
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.primary,
              width: candidates.isEmpty ? 1 : 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _answer.groups[g],
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final (i, (option, right)) in _answer.forms.indexed)
                    if (_given[i] == g) _draggableForm(i, option, right),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _sortBoard() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _pool(),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var g = 0; g < _answer.groups.length; g++) ...[
            if (g > 0) const SizedBox(width: 8),
            _groupBox(g),
          ],
        ],
      ),
    ],
  );

  List<Widget> _feedback() => [
    const SizedBox(height: 16),
    Text(
      _isRight
          ? _t('exercise.screen.right')
          : _t('exercise.screen.wrong', {
              'answer': [
                for (final (i, (option, group)) in _answer.forms.indexed)
                  if (_groupOf(i) != group)
                    '${option.text}: ${_answer.groups[group]}',
              ].join(', '),
            }),
      key: const Key('exercise.feedback'),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: _isRight ? Colors.green.shade800 : null,
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
