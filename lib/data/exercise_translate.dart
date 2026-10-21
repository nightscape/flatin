/// Kinds A2, A3 and A7: a Latin form and its German text, in both directions.
library;

import 'dart:math';

import '../models/exercise.dart';
import 'german_forms.dart';
import '../models/form_distractors.dart';
import '../models/practice_item.dart';

const _optionCount = 4;
const _drawLimit = 8;

/// The indirect question that makes a German subjunctive text unambiguous;
/// `{}` takes the text, the key is the tempus of the Latin form.
const _subjunctiveFrame = {
  'praes': 'Ich frage, ob {}.',
  'perf': 'Ich frage, ob {}.',
  'impf': 'Ich fragte, ob {}.',
  'plusq': 'Ich fragte, ob {}.',
};

bool _framed(String keyOrBundle) => keyOrBundle.startsWith('konj.');

/// What the learner reads for the German text of [key]: the text itself, or
/// for a subjunctive form the text inside the indirect-question frame.
String germanShown(PracticeItem word, FormKey key, ExerciseContext ctx) {
  final text = ctx.german.render(word, key);
  return _framed(key)
      ? _subjunctiveFrame[key.split('.')[1]]!.replaceFirst('{}', text)
      : text;
}

/// Every text a learner may give for [key], each shown the way
/// [germanShown] shows it.
Set<String> acceptedShown(PracticeItem word, FormKey key, ExerciseContext ctx) {
  final german = ctx.german;
  final texts = german is GrammarGermanForms
      ? german.accepted(word, key)
      : [german.render(word, key)];
  return {
    for (final t in texts)
      _framed(key)
          ? _subjunctiveFrame[key.split('.')[1]]!.replaceFirst('{}', t)
          : t,
  };
}

/// The right form of [target] and every distractor that [formChoice] can
/// give, minus real forms for which [conflicts] holds. Wrong spellings are
/// kept when [realOnly] is false.
({FormOption right, List<FormOption> others}) _distractors(
  PracticeItem word,
  FormKey target,
  Set<GrammarBundle> unlocked,
  ExerciseContext ctx,
  Random rng, {
  required bool realOnly,
  required bool Function(FormKey) conflicts,
}) {
  var drawn = formChoice(
    word,
    target,
    unlocked,
    ctx.german,
    _optionCount - 1,
    rng,
  );
  try {
    for (var count = _optionCount; count <= _drawLimit; count++) {
      drawn = formChoice(word, target, unlocked, ctx.german, count, rng);
    }
  } on CannotBuild {
    // drawn holds the most distractors formChoice could give.
  }
  final others = [
    for (final o in drawn.options)
      if (!identical(o, drawn.right) &&
          (o.builtWrongBy != null ? !realOnly : !conflicts(o.formKey)))
        o,
  ]..shuffle(rng);
  if (others.length < _optionCount - 1) {
    throw CannotBuild(
      '${word.id} $target has only ${others.length} distractors with other German',
    );
  }
  return (right: drawn.right, others: others);
}

List<FormKey> _askable(
  PracticeItem word,
  GrammarBundle bundle,
  ExerciseContext ctx,
) {
  if (!ctx.unlocked.contains(bundle)) throw CannotBuild('$bundle is locked');
  final keys = [
    for (final key in word.formOrder)
      if (bundleOf(word, key) == bundle && ctx.german.covers(word, key)) key,
  ];
  if (keys.isEmpty) {
    throw CannotBuild('${word.id} has no German form in $bundle');
  }
  return keys;
}

String _latinOf(PracticeItem word, FormKey key) =>
    word.forms[word.formOrder.indexOf(key)];

/// A Latin form; the learner picks its German text among the texts of forms
/// that differ from it in one feature.
/// Produced here for the registry in `exerciseGenerators`; read by the
/// generic exercise screen and `attribute`.
class LatDeChoiceGenerator implements ExerciseGenerator {
  const LatDeChoiceGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.latDeWahl;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final keys = _askable(word, bundle, ctx);
    final target = keys[rng.nextInt(keys.length)];
    // The frame must not tell the right option from the others, so the
    // options are all framed or none is.
    final sameFraming = {
      for (final b in ctx.unlocked)
        if (_framed(b) == _framed(bundle)) b,
    };
    final drawn = _distractors(
      word,
      target,
      sameFraming,
      ctx,
      rng,
      realOnly: true,
      conflicts: (key) =>
          acceptedShown(
            word,
            target,
            ctx,
          ).contains(germanShown(word, key, ctx)) ||
          acceptedShown(
            word,
            key,
            ctx,
          ).contains(germanShown(word, target, ctx)),
    );
    final latin = [drawn.right, ...drawn.others.take(_optionCount - 1)]
      ..shuffle(rng);
    final options = [
      for (final o in latin)
        FormOption(
          text: germanShown(word, o.formKey, ctx),
          formKey: o.formKey,
          lexemeId: o.lexemeId,
        ),
    ];
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.translate.latDe.question',
      questionParams: {'form': _latinOf(word, target), 'word': word.lemma},
      answer: ChoiceAnswer(options, options[latin.indexOf(drawn.right)]),
    );
  }
}

/// A German text; the learner picks the Latin form among forms that differ
/// from it in one feature.
/// Produced here for the registry in `exerciseGenerators`; read by the
/// generic exercise screen and `attribute`.
class DeLatChoiceGenerator implements ExerciseGenerator {
  const DeLatChoiceGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.deLatWahl;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final keys = _askable(word, bundle, ctx);
    final target = keys[rng.nextInt(keys.length)];
    final drawn = _distractors(
      word,
      target,
      ctx.unlocked,
      ctx,
      rng,
      realOnly: false,
      conflicts: (key) => acceptedShown(
        word,
        key,
        ctx,
      ).contains(germanShown(word, target, ctx)),
    );
    final options = [drawn.right, ...drawn.others.take(_optionCount - 1)]
      ..shuffle(rng);
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.translate.deLat.question',
      questionParams: {
        'german': germanShown(word, target, ctx),
        'word': word.lemma,
      },
      answer: ChoiceAnswer(options, drawn.right),
    );
  }
}

/// A German text; the learner types the Latin form. Every form of the word
/// whose accepted German texts contain the shown text is a right answer.
/// Produced here for the registry in `exerciseGenerators`; read by the
/// generic exercise screen and `attribute`.
class DeLatTypeGenerator implements ExerciseGenerator {
  const DeLatTypeGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.deLatTippen;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final keys = _askable(word, bundle, ctx);
    final target = keys[rng.nextInt(keys.length)];
    final index = word.formOrder.indexOf(target);
    final shown = germanShown(word, target, ctx);
    final accepted = {
      ...word.acceptedForms[index],
      for (final key in word.formOrder)
        if (ctx.german.covers(word, key) &&
            acceptedShown(word, key, ctx).contains(shown))
          ...word.acceptedForms[word.formOrder.indexOf(key)],
    }.toList();
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.translate.deLatType.question',
      questionParams: {
        'german': germanShown(word, target, ctx),
        'word': word.lemma,
      },
      answer: TypedAnswer(
        FormOption(text: word.forms[index], formKey: target, lexemeId: word.id),
        accepted,
      ),
    );
  }
}
