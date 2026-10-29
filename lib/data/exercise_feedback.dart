import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';
import 'diagnosis.dart';
import 'explanation.dart';

/// The lines under the verdict of one answered exercise, as i18n keys.
/// Produced here from the data; read by the exercise screens.
List<ExplanationLine> feedbackLines(
  PracticeItem word,
  Exercise exercise,
  ExerciseResponse response,
) => switch ((exercise.answer, response)) {
  _ when word.isVocab => _vocabLines(word, exercise.answer, response),
  (final TypedAnswer answer, TypedText(:final text)) => _typed(
    word,
    answer,
    text,
  ),
  (final ChoiceAnswer answer, ChosenOption(:final chosen)) => [
    for (final option in answer.options)
      _optionLine(
        word,
        option,
        option.text,
        right: identical(option, answer.right),
        chosen: identical(option, chosen),
      ),
    if (exercise.kind == ExerciseKind.irrlaeufer)
      ExplanationLine(
        'exercise.feedback.oddAxes',
        params: {'values': _oddValues(word, answer)},
      ),
  ],
  (MatchingAnswer(:final pairs), MatchedPairs()) => [
    for (final (latin, _) in pairs)
      _optionLine(word, latin, latin.text, right: false, chosen: false),
  ],
  (SortingAnswer(:final groups, :final forms), SortedForms(:final groupOf)) => [
    for (final (option, group) in forms)
      groupOf[option] == group
          ? ExplanationLine(
              'exercise.feedback.option',
              params: {'form': option.text, 'label': groups[group]},
            )
          : ExplanationLine(
              'exercise.feedback.misplaced',
              params: {
                'form': option.text,
                'label': groups[group],
                'chosen': groups[groupOf[option]!],
              },
            ),
  ],
  _ => throw ArgumentError(
    '${response.runtimeType} does not answer ${exercise.answer.runtimeType}',
  ),
};

/// A vocab item has no forms to tell apart: its feedback pairs Latin texts
/// with their meanings.
List<ExplanationLine> _vocabLines(
  PracticeItem word,
  ExerciseAnswer answer,
  ExerciseResponse response,
) => switch ((answer, response)) {
  (MatchingAnswer(:final pairs), MatchedPairs()) => [
    for (final (latin, german) in pairs)
      ExplanationLine(
        'exercise.feedback.option',
        params: {'form': latin.text, 'label': german.text},
      ),
  ],
  (ChoiceAnswer(:final right), ChosenOption(:final chosen)) => [
    _vocabLine(word, chosen: identical(chosen, right)),
  ],
  (TypedAnswer(), TypedText()) => [_vocabLine(word, chosen: false)],
  _ => throw ArgumentError(
    '${response.runtimeType} does not answer ${answer.runtimeType}',
  ),
};

ExplanationLine _vocabLine(PracticeItem word, {required bool chosen}) =>
    ExplanationLine(
      chosen
          ? 'exercise.feedback.optionRightChosen'
          : 'exercise.feedback.optionRight',
      params: {'form': word.lemma, 'label': word.translation},
    );

/// The axis ids on which the three options other than [answer.right] share
/// one value and [answer.right] has another, in axis declaration order.
/// Throws StateError when there is none.
List<String> oddAxes(PracticeItem word, ChoiceAnswer answer) {
  final others = answer.options.where((o) => !identical(o, answer.right));
  assert(others.length == 3, 'odd one out has four options');
  final labels = [for (final o in others) _labelOf(word, o.formKey)];
  final right = _labelOf(word, answer.right.formKey);
  final odd = [
    for (final axis in labels.first.axes.axes)
      if (labels.first.features[axis.id] != null &&
          labels.every(
            (l) => l.features[axis.id] == labels.first.features[axis.id],
          ) &&
          right.features[axis.id] != labels.first.features[axis.id])
        axis.id,
  ];
  if (odd.isEmpty) throw StateError('no axis tells the right option apart');
  return odd;
}

String _oddValues(PracticeItem word, ChoiceAnswer answer) {
  final majority = _labelOf(
    word,
    answer.options.firstWhere((o) => !identical(o, answer.right)).formKey,
  );
  return oddAxes(word, answer).map((id) => majority.display(id)!).join(', ');
}

List<ExplanationLine> _typed(
  PracticeItem word,
  TypedAnswer answer,
  String text,
) {
  final key = answer.expected.formKey;
  final accepted = answer.accepted.any((s) => norm(s) == norm(text));
  return [
    _optionLine(word, answer.expected, answer.expected.text, right: true),
    if (!accepted && text.trim().isNotEmpty)
      ...explainWrongAnswer(word, key, text),
  ];
}

ExplanationLine _optionLine(
  PracticeItem word,
  FormOption option,
  String form, {
  required bool right,
  bool chosen = false,
}) {
  assert(option.lexemeId == word.id, 'option of another word than ${word.id}');
  final diagnosis = option.builtWrongBy;
  final String label;
  if (diagnosis == null) {
    label = describeLabels([_labelOf(word, option.formKey)]);
  } else {
    assert(diagnosis is EndingOfOtherType, 'unexpected $diagnosis');
    label = (diagnosis as EndingOfOtherType).types
        .map((t) => typePhrase(t, word.derivation.grammar.language))
        .join(', ');
  }
  final suffix = switch ((right, chosen)) {
    (true, true) => 'optionRightChosen',
    (true, false) => 'optionRight',
    (false, true) => 'optionChosen',
    (false, false) => 'option',
  };
  return ExplanationLine(
    'exercise.feedback.$suffix',
    params: {'form': form, 'label': label},
  );
}

FormLabel _labelOf(PracticeItem word, FormKey key) =>
    word.formLabels[word.formOrder.indexOf(key)];
