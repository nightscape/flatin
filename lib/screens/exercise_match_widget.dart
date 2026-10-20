import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../models/exercise.dart';

/// Shows one matching [Exercise]: the learner pairs each Latin form with a
/// German text; after the feedback, "next" hands the pairs to [onResponse]
/// once. The pairs carry the exercise's own [FormOption]s, as `attribute`
/// compares them by identity.
/// Produced here for the caller that wires the exercises into the app.
class ExerciseMatchWidget extends StatefulWidget {
  final Exercise exercise;
  final void Function(MatchedPairs response) onResponse;

  const ExerciseMatchWidget({
    super.key,
    required this.exercise,
    required this.onResponse,
  });

  @override
  State<ExerciseMatchWidget> createState() => _ExerciseMatchWidgetState();
}

class _ExerciseMatchWidgetState extends State<ExerciseMatchWidget> {
  static const _contentWidth = 600.0;

  late List<(FormOption, FormOption)> _right;
  late List<int> _leftOrder;
  late List<int> _rightOrder;

  /// Left index → right index, both as positions in [_right].
  final _paired = <int, int>{};
  int? _selectedLeft;
  bool _checked = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(ExerciseMatchWidget old) {
    super.didUpdateWidget(old);
    if (old.exercise != widget.exercise) _reset();
  }

  void _reset() {
    _right = (widget.exercise.answer as MatchingAnswer).pairs;
    final indices = List.generate(_right.length, (i) => i);
    _leftOrder = [...indices]..shuffle(Random());
    _rightOrder = [...indices]..shuffle(Random());
    _paired.clear();
    _selectedLeft = null;
    _checked = false;
    _reported = false;
  }

  bool get _isRight => _paired.entries.every((e) => e.key == e.value);

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  void _tapLeft(int left) => setState(() {
    if (_paired.remove(left) != null) return;
    _selectedLeft = left;
  });

  void _tapRight(int right) => setState(() {
    final left = _selectedLeft;
    if (left == null) {
      _paired.removeWhere((_, r) => r == right);
      return;
    }
    _paired.removeWhere((_, r) => r == right);
    _paired[left] = right;
    _selectedLeft = null;
  });

  MatchedPairs get _response => MatchedPairs([
    for (final e in _paired.entries) (_right[e.key].$1, _right[e.value].$2),
  ]);

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(_t('exercise.screen.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _t(exercise.questionKey, exercise.questionParams),
                key: const Key('exercise.question'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_t('exercise.match.hint')),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _column([
                      for (final i in _leftOrder) _leftButton(i),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _column([
                      for (final i in _rightOrder) _rightButton(i),
                    ]),
                  ),
                ],
              ),
              if (!_checked && _paired.length == _right.length) ...[
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

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );

  /// The 1-based number of the pair that [left] belongs to, shown on both of
  /// its buttons; null while unpaired.
  int? _number(int? left) =>
      left == null || !_paired.containsKey(left) ? null : left + 1;

  Widget _leftButton(int left) => _button(
    key: Key('exercise.match.left.$left'),
    text: _right[left].$1.text,
    number: _number(left),
    selected: _selectedLeft == left,
    verdict: _checked ? _paired[left] == left : null,
    onPressed: _checked ? null : () => _tapLeft(left),
  );

  Widget _rightButton(int right) {
    final left = _paired.entries
        .where((e) => e.value == right)
        .map((e) => e.key)
        .firstOrNull;
    return _button(
      key: Key('exercise.match.right.$right'),
      text: _right[right].$2.text,
      number: _number(left),
      selected: false,
      verdict: _checked && left != null ? left == right : null,
      onPressed: _checked ? null : () => _tapRight(right),
    );
  }

  Widget _button({
    required Key key,
    required String text,
    required int? number,
    required bool selected,
    required bool? verdict,
    required VoidCallback? onPressed,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton(
      key: key,
      style: OutlinedButton.styleFrom(
        backgroundColor: switch (verdict) {
          true => Colors.green.shade100,
          false => Colors.red.shade100,
          null => selected ? Colors.blue.shade100 : null,
        },
      ),
      onPressed: onPressed,
      child: Text(number == null ? text : '$number · $text'),
    ),
  );

  List<Widget> _feedback() => [
    const SizedBox(height: 16),
    Text(
      _isRight
          ? _t('exercise.screen.right')
          : _t('exercise.screen.wrong', {
              'answer': _right
                  .map((p) => '${p.$1.text} = ${p.$2.text}')
                  .join(', '),
            }),
      key: const Key('exercise.feedback'),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: _isRight ? Colors.green.shade800 : Colors.red.shade800,
      ),
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
