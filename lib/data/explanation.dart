import '../models/derivation.dart';
import '../models/practice_item.dart';
import 'diagnosis.dart';

/// One line of an explanation, as an i18n key plus its parameters.
/// The screens translate it; the logic stays language-free.
final class ExplanationLine {
  final String key;
  final Map<String, String> params;

  const ExplanationLine(this.key, {this.params = const {}});
}

/// Practice screen: what the asked form needs to be told besides its ESEL
/// steps, and what the answer is.
List<ExplanationLine> explainWrongAnswer(
  PracticeItem item,
  FormKey formKey,
  String answer,
) {
  final String label = describeLabels([_labelOf(item, formKey)]);
  return [
    ..._deponentLine(item, formKey, label),
    ..._variantsLine(item, formKey),
    _diagnosisLine(item, formKey, answer),
  ];
}

/// Practice screen, Q11 A: an answer that differs from the shown spelling only
/// in quantity marks is correct and gets the marked spelling as an info line.
/// Empty when the learner wrote the spelling as it stands.
///
/// Precondition: [answer] is accepted for [formKey] ([PracticeItem.accepts]).
List<ExplanationLine> explainCorrectAnswer(
  PracticeItem item,
  FormKey formKey,
  String answer,
) {
  final int index = item.formOrder.indexOf(formKey);
  assert(index >= 0, '"$formKey" is not a form of "${item.translation}"');
  assert(item.accepts(index, answer), 'a wrong answer gets a diagnosis');

  final String accepted = item.acceptedForms[index].firstWhere(
    (spelling) => item.lang.norm(spelling) == item.lang.norm(answer),
  );
  if (accepted.toLowerCase() == answer.trim().toLowerCase()) return const [];
  return [
    ExplanationLine('explain.correctWithMacrons', params: {'result': accepted}),
  ];
}

/// The dictionary entry of the item: nominative and genitive, or 1st person
/// and infinitive, whichever the data gives.
String headword(PracticeItem item) =>
    item.principalParts.map((part) => part.$2).join(', ');

FormLabel _labelOf(PracticeItem item, FormKey formKey) {
  final int index = item.formOrder.indexOf(formKey);
  assert(index >= 0, '"$formKey" is not a form of "${item.translation}"');
  return item.formLabels[index];
}

/// S10: the key is practised in the active, but the form is a passive one.
List<ExplanationLine> _deponentLine(
  PracticeItem item,
  FormKey formKey,
  String label,
) => item.derivation.deponentKeys.contains(formKey)
    ? [
        ExplanationLine('explain.deponent', params: {'label': label}),
      ]
    : const [];

/// S9: the other spellings that count as correct.
List<ExplanationLine> _variantsLine(PracticeItem item, FormKey formKey) {
  final variants = item.derivation.forms[formKey]!.variants;
  if (variants.length == 1) return const [];
  return [
    ExplanationLine(
      'explain.variants',
      params: {'variants': variants.skip(1).join(', ')},
    ),
  ];
}

/// S40: the school-grammar phrase naming the endings of [type] in the data
/// language; the clause prints it as it stands.
String typePhrase(Grammar grammar, String type) =>
    (grammar.phraseByType[type] ??
    (throw StateError('no phrase for type $type')))[grammar.language]!;

ExplanationLine _diagnosisLine(
  PracticeItem item,
  FormKey formKey,
  String answer,
) {
  final diagnosis = diagnose(item, formKey, answer);
  switch (diagnosis) {
    case RegularInsteadOfIrregular():
      return ExplanationLine(
        'explain.diag.regularInsteadOfIrregular',
        params: {
          'answer': answer,
          'label': describeLabels([_labelOf(item, formKey)]),
        },
      );
    case OtherFormOfWord(:final formKeys):
      return ExplanationLine(
        'explain.diag.otherForm',
        params: {
          'answer': answer,
          'labels': describeLabels(
            formKeys.map((key) => _labelOf(item, key)).toList(),
          ),
        },
      );
    case EndingOfOtherType(:final types):
      return ExplanationLine(
        'explain.diag.otherType',
        params: {
          'answer': answer,
          'types': types
              .map((type) => typePhrase(item.derivation.grammar, type))
              .join(', '),
        },
      );
    case WrongStem(:final usedStem, :final stemName):
      final stem = item.derivation.stems[stemName]!;
      return ExplanationLine(
        'explain.diag.wrongStem',
        params: {
          'answer': answer,
          'usedStem': usedStem,
          'display': stem.display,
          'stem': stem.stem,
        },
      );
    case NoMatch():
      return ExplanationLine(
        'explain.diag.noMatch',
        params: {'answer': answer},
      );
  }
}

/// Classification screen: what the picked label would be for this item.
/// [picked] is null when the chosen combination maps to no label.
/// [pickedText] is that combination as the screen shows it ("Vokativ Plural");
/// it fills `{picked}` in both `explain.pickedWouldBe` and
/// `explain.pickedMissing`, and is the only source for the null case.
ExplanationLine explainPickedLabel(
  PracticeItem item,
  FormLabel? picked,
  String pickedText,
) {
  if (picked == null) {
    return ExplanationLine(
      'explain.pickedMissing',
      params: {'picked': pickedText},
    );
  }

  final int index = item.formLabels.indexOf(picked);
  assert(index >= 0, '"$pickedText" is not a form of "${item.translation}"');
  final form = item.derivation.forms[item.formOrder[index]]!;
  final String text = form is GeneratedForm
      ? '${form.result} '
            '(${item.derivation.stems[form.stemName]!.stem} + ${form.ending})'
      : form.result;

  return ExplanationLine(
    'explain.pickedWouldBe',
    params: {'picked': pickedText, 'form': text},
  );
}
