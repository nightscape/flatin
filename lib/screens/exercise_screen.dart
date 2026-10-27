import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../models/derivation.dart' show norm;
import '../data/exercise_feedback.dart';
import '../models/exercise.dart';
import '../models/input_strategy.dart';
import '../models/practice_item.dart';
import '../widgets/explanation_lines.dart';

/// Shows one multiple-choice or typed [Exercise]; after the feedback, the
/// "next" button hands the learner's response to [onResponse] once.
/// Produced here for the caller that wires the exercises into the app.
class ExerciseScreen extends StatefulWidget {
  final PracticeItem word;
  final Exercise exercise;

  /// The app bar title; null shows the standard exercise title.
  final String? title;

  /// How [inputKinds] take the answer: the input setting of [word]'s data file.
  final InputStrategy inputStrategy;

  /// The forms of [word] the dropdowns offer.
  final Set<FormKey> optionForms;
  final void Function(ExerciseResponse response) onResponse;

  /// The typed kinds that follow [inputStrategy]; the others always take text.
  static const inputKinds = {
    ExerciseKind.formBilden,
    ExerciseKind.umformen,
    ExerciseKind.fehlerFinden,
    ExerciseKind.formenKette,
  };

  const ExerciseScreen({
    super.key,
    required this.word,
    required this.exercise,
    this.title,
    required this.inputStrategy,
    required this.optionForms,
    required this.onResponse,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  static const _contentWidth = 600.0;

  final _input = TextEditingController();
  ExerciseResponse? _response;
  bool _reported = false;

  @override
  void didUpdateWidget(ExerciseScreen old) {
    super.didUpdateWidget(old);
    if (old.exercise != widget.exercise) {
      _response = null;
      _reported = false;
      _input.clear();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _isRight => switch ((widget.exercise.answer, _response!)) {
    (ChoiceAnswer(:final right), ChosenOption(:final chosen)) => identical(
      chosen,
      right,
    ),
    (TypedAnswer(:final accepted), TypedText(:final text)) => accepted.any(
      (form) => norm(form) == norm(text),
    ),
    _ => throw StateError('response does not fit the answer'),
  };

  String get _rightText => switch (widget.exercise.answer) {
    ChoiceAnswer(:final right) => right.text,
    TypedAnswer(:final accepted) => accepted.join(' / '),
    MatchingAnswer() => throw UnsupportedError('matching'),
  };

  void _respond(ExerciseResponse response) =>
      setState(() => _response = response);

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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _t(exercise.questionKey, exercise.questionParams),
                key: const Key('exercise.question'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              switch (exercise.answer) {
                ChoiceAnswer() => _choices(exercise.answer as ChoiceAnswer),
                TypedAnswer() => _typed(),
                MatchingAnswer() => throw UnsupportedError('matching'),
              },
              if (_response != null) ..._feedback(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choices(ChoiceAnswer answer) {
    final chosen = (_response as ChosenOption?)?.chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, option) in answer.options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              key: Key('exercise.option.$i'),
              style: _response == null
                  ? null
                  : OutlinedButton.styleFrom(
                      backgroundColor: identical(option, answer.right)
                          ? Colors.green.shade100
                          : identical(option, chosen)
                          ? Colors.red.shade100
                          : null,
                    ),
              onPressed: _response == null
                  ? () => _respond(ChosenOption(option))
                  : null,
              child: Text(option.text),
            ),
          ),
      ],
    );
  }

  Widget _typed() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // A dropdown offers the word's own forms; a vocab item has only one.
      if (widget.inputStrategy is! TextFieldStrategy &&
          !widget.word.isVocab &&
          ExerciseScreen.inputKinds.contains(widget.exercise.kind))
        KeyedSubtree(
          key: const Key('exercise.input'),
          child: widget.inputStrategy.buildInput(_inputContext()),
        )
      else
        TextField(
          key: const Key('exercise.input'),
          controller: _input,
          enabled: _response == null,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _t('exercise.screen.inputHint'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _check(),
        ),
      if (_response == null) ...[
        const SizedBox(height: 8),
        ElevatedButton(
          key: const Key('exercise.check.button'),
          onPressed: _check,
          child: Text(_t('exercise.screen.check')),
        ),
      ],
    ],
  );

  InputContext _inputContext() {
    final expected = (widget.exercise.answer as TypedAnswer).expected;
    assert(expected.lexemeId == widget.word.id, 'the target is another word');
    final offered = widget.word.filterForms(widget.optionForms);
    final index = offered.keys.indexOf(expected.formKey);
    assert(index >= 0, '${expected.formKey} is not offered');
    return InputContext(
      index: index,
      correctAnswer: expected.text,
      allForms: offered.forms,
      inferredForms: offered.inferredForms,
      isChecked: _response != null,
      borderColor: Theme.of(context).colorScheme.outline,
      labelFontSize: 16,
      isMobile: MediaQuery.sizeOf(context).width < 600,
      currentValue: _input.text,
      onChanged: (value) => setState(() => _input.text = value),
    );
  }

  void _check() => _respond(TypedText(_input.text));

  List<Widget> _feedback() => [
    const SizedBox(height: 16),
    Text(
      _isRight
          ? _t('exercise.screen.right')
          : _t('exercise.screen.wrong', {'answer': _rightText}),
      key: const Key('exercise.feedback'),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: _isRight ? Colors.green.shade800 : null,
      ),
    ),
    const SizedBox(height: 8),
    ExplanationLines(
      feedbackLines(widget.word, widget.exercise, _response!),
      key: const Key('exercise.feedback.lines'),
    ),
    const SizedBox(height: 8),
    ElevatedButton(
      key: const Key('exercise.next.button'),
      onPressed: () {
        if (_reported) return;
        setState(() => _reported = true);
        widget.onResponse(_response!);
      },
      child: Text(_t('exercise.screen.next')),
    ),
  ];
}
