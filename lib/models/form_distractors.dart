import 'dart:math';

import '../data/diagnosis.dart';
import '../data/german_forms.dart';
import 'derivation.dart' show norm;
import 'exercise.dart';
import 'practice_item.dart';

/// The choice between the right form of [item] at [target] and [count]
/// distractors, shuffled.
///
/// A distractor is another form of [item] that differs from [target] in exactly
/// one axis, or the ending another type uses for [target]. It lies in a bundle
/// of [unlocked], and neither it nor its German text can be taken for the right
/// answer. A form without German text is no distractor. Throws [CannotBuild]
/// when [target] has no German text or fewer than [count] distractors exist.
ChoiceAnswer formChoice(
  PracticeItem item,
  FormKey target,
  Set<GrammarBundle> unlocked,
  GermanForms german,
  int count,
  Random rng,
) {
  if (!german.covers(item, target)) {
    throw CannotBuild('no German text for ${item.id} $target');
  }
  final targetIndex = item.formOrder.indexOf(target);
  assert(
    unlocked.contains(bundleOf(item, target)),
    'the bundle of $target is not unlocked',
  );
  final right = FormOption(
    text: item.forms[targetIndex],
    formKey: target,
    lexemeId: item.id,
  );
  final taken = {
    for (final spelling in item.acceptedForms[targetIndex]) norm(spelling),
  };
  final germanTaken = {german.render(item, target)};

  final candidates = [
    ..._neighbours(item, target, unlocked),
    ..._endingsOfOtherTypes(item, target),
  ]..shuffle(rng);
  final distractors = <FormOption>[];
  for (final option in candidates) {
    if (distractors.length == count) break;
    if (taken.contains(norm(option.text))) continue;
    final realForm = option.builtWrongBy == null;
    if (realForm && !german.covers(item, option.formKey)) continue;
    if (realForm && germanTaken.contains(german.render(item, option.formKey))) {
      continue;
    }
    taken.add(norm(option.text));
    if (realForm) germanTaken.add(german.render(item, option.formKey));
    distractors.add(option);
  }
  if (distractors.length < count) {
    throw CannotBuild(
      'only ${distractors.length} distractors for $count of ${item.id} $target',
    );
  }
  return ChoiceAnswer([right, ...distractors]..shuffle(rng), right);
}

Iterable<FormOption> _neighbours(
  PracticeItem item,
  FormKey target,
  Set<GrammarBundle> unlocked,
) sync* {
  final asked = item.formLabels[item.formOrder.indexOf(target)].features;
  for (int j = 0; j < item.formOrder.length; j++) {
    final key = item.formOrder[j];
    final features = item.formLabels[j].features;
    final differing = {
      ...asked.keys,
      ...features.keys,
    }.where((axis) => asked[axis] != features[axis]);
    if (differing.length == 1 && unlocked.contains(bundleOf(item, key))) {
      yield FormOption(text: item.forms[j], formKey: key, lexemeId: item.id);
    }
  }
}

Iterable<FormOption> _endingsOfOtherTypes(
  PracticeItem item,
  FormKey target,
) sync* {
  final derivation = item.derivation;
  final targetIndex = item.formOrder.indexOf(target);
  for (final entry in derivation.grammar.templatesByType.entries) {
    final template = entry.value[target];
    if (entry.key == derivation.type || template == null) continue;
    final stem = template.stemName == null
        ? ''
        : derivation.stems[template.stemName]?.stem;
    if (stem == null) continue;
    final text = stem + template.endings.first;
    if (item.accepts(targetIndex, text)) continue;
    final diagnosis = diagnose(item, target, text);
    if (diagnosis is EndingOfOtherType) {
      yield FormOption(
        text: text,
        formKey: target,
        lexemeId: item.id,
        builtWrongBy: diagnosis,
      );
    }
  }
}
