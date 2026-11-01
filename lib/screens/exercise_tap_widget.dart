import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/exercise_feedback.dart';
import '../models/exercise.dart';
import '../models/practice_item.dart';
import '../widgets/explanation_lines.dart';

/// Shows one marking [Exercise]: the learner taps a pill of the tray, then
/// the word it marks; a tap on a placed pill puts it back. After the
/// feedback, "next" hands the placements to [onResponse] once.
class ExerciseTapWidget extends StatefulWidget {
  final PracticeItem word;
  final Exercise exercise;

  /// The app bar title; null shows the standard exercise title.
  final String? title;
  final void Function(MarksResponse response) onResponse;

  const ExerciseTapWidget({
    super.key,
    required this.word,
    required this.exercise,
    this.title,
    required this.onResponse,
  });

  @override
  State<ExerciseTapWidget> createState() => _ExerciseTapWidgetState();
}

class _ExerciseTapWidgetState extends State<ExerciseTapWidget> {
  static const _contentWidth = 600.0;

  /// Pill index → word index.
  final _placed = <int, int>{};
  int? _held;
  bool _checked = false;
  bool _reported = false;

  MarksAnswer get _answer => widget.exercise.answer as MarksAnswer;

  @override
  void didUpdateWidget(ExerciseTapWidget old) {
    super.didUpdateWidget(old);
    if (old.exercise != widget.exercise) {
      _placed.clear();
      _held = null;
      _checked = false;
      _reported = false;
    }
  }

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  String _pillName(int pill) =>
      _t('exercise.tap.pill.${_answer.pills[pill].role}');

  bool get _complete => _placed.length == _answer.pills.length;

  MarksResponse get _response => MarksResponse([
    for (var p = 0; p < _answer.pills.length; p++) _placed[p]!,
  ]);

  bool _right(int pill) => _placed[pill] == _answer.pills[pill].word;

  void _place(int word) => setState(() {
    final pill = _held!;
    _placed.removeWhere((_, w) => w == word);
    _placed[pill] = word;
    _held = null;
  });

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
              const SizedBox(height: 4),
              Text(_t('exercise.tap.hint')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var w = 0; w < _answer.words.length; w++) _word(w),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                key: const Key('exercise.tap.tray'),
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var p = 0; p < _answer.pills.length; p++)
                    if (!_placed.containsKey(p)) _trayPill(p),
                ],
              ),
              if (!_checked) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const Key('exercise.check.button'),
                  onPressed: _complete
                      ? () => setState(() => _checked = true)
                      : null,
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

  Widget _trayPill(int p) => ChoiceChip(
    key: Key('exercise.tap.pill.$p'),
    label: Text(_pillName(p)),
    selected: _held == p,
    onSelected: (_) => setState(() => _held = _held == p ? null : p),
  );

  Widget _placedPill(int p) => Semantics(
    button: true,
    label: _pillName(p),
    excludeSemantics: true,
    child: GestureDetector(
      key: Key('exercise.tap.placed.$p'),
      onTap: _checked ? null : () => setState(() => _placed.remove(p)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: !_checked
              ? Theme.of(context).colorScheme.secondaryContainer
              : _right(p)
              ? Colors.green.shade100
              : Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _pillName(p),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    ),
  );

  Widget _word(int w) {
    final pill = _placed.entries.where((e) => e.value == w).firstOrNull?.key;
    final held = _held != null && !_checked;
    return Semantics(
      container: true,
      button: held,
      label: _answer.words[w],
      child: GestureDetector(
        key: Key('exercise.tap.word.$w'),
        onTap: held ? () => _place(w) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: held
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _answer.words[w],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (pill != null) ...[
                const SizedBox(height: 2),
                _placedPill(pill),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feedback() {
    final right = _placed.keys.every(_right);
    return [
      const SizedBox(height: 16),
      Text(
        right
            ? _t('exercise.screen.right')
            : _t('exercise.screen.wrong', {
                'answer': [
                  for (final (p, pill) in _answer.pills.indexed)
                    if (!_right(p))
                      '${_answer.words[pill.word]}: ${_pillName(p)}',
                ].join(', '),
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
