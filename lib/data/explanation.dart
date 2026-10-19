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
    (spelling) => norm(spelling) == norm(answer),
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

/// S14: per item class, the types whose endings its school grammar really
/// borrows — participle and comparative endings, the consonant endings of the
/// i-stems, the I-Konjugation endings of `capiō`. An unlisted pair is an
/// engine detail the learner is never told, so the form is named after its own
/// class: `habeō` is an E-Konjugation form, and the perfect endings belong to
/// no class at all.
const borrowedEndings = <String, Set<String>>{
  'A-Konjugation': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
  'E-Konjugation': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
  'I-Konjugation': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
  'Konsonantische': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
  'Mischkonjugation': {
    'I-Konjugation',
    '3-Endungen',
    '3-Endungen-Partizip',
    'a-o-Endungen',
  },
  'Unregelmäßig': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
  'esse-Typ': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
  'Adjektiv-a-o': {'Komparativ-Endungen', 'a-o-Endungen'},
  'Adjektiv-a-o-er': {
    'Adjektiv-a-o',
    'Komparativ-Endungen',
    'a-o-Endungen',
    'a-o-er-Endungen',
  },
  'Adjektiv-dreiendig': {
    'Adjektiv-3',
    'Komparativ-Endungen',
    '3-Endungen',
    'a-o-Endungen',
  },
  'Adjektiv-zweiendig': {
    'Adjektiv-3',
    'Komparativ-Endungen',
    '3-Endungen',
    'a-o-Endungen',
  },
  'I-Deklination-mf': {'Konsonantische-Deklination-mf'},
  'Konsonantische-Deklination-i-mf': {'Konsonantische-Deklination-mf'},
  'Konsonantische-Deklination-i-n': {'Konsonantische-Deklination-n'},
  'E-Deklination-Konsonantstamm': {'E-Deklination'},
};

/// The school-grammar phrase naming each type [borrowedEndings] can name; the
/// clause prints it as it stands.
const endingTypePhrases = <String, String>{
  '3-Endungen': 'Endung der 3. Deklination',
  '3-Endungen-Partizip': 'Endung der 3. Deklination (Partizip)',
  'a-o-Endungen': 'Endung der a-/o-Deklination',
  'a-o-er-Endungen': 'Endung der a-/o-Deklination auf -er',
  'Komparativ-Endungen': 'Komparativendung',
  'I-Konjugation': 'Endung der I-Konjugation',
  'Adjektiv-a-o': 'Adverbendung (Adjektiv der a-/o-Deklination)',
  'Adjektiv-3': 'Adverbendung (Adjektiv der 3. Deklination)',
  'Konsonantische-Deklination-mf':
      'Endung der konsonantischen Deklination (m/f)',
  'Konsonantische-Deklination-n': 'Endung der konsonantischen Deklination (n)',
  'E-Deklination': 'Endung der E-Deklination',
};

String endingTypePhrase(String type) =>
    endingTypePhrases[type] ??
    (throw StateError('no phrase for ending type $type'));

/// The phrase for each type a diagnosis can name that the ending clause never
/// does; [typePhrase] reads it after [endingTypePhrases].
const diagnosisOnlyTypePhrases = <String, String>{
  'A-Deklination': 'Endung der A-Deklination',
  'O-Deklination-maskulinum': 'Endung der O-Deklination (m)',
  'O-Deklination-neutrum': 'Endung der O-Deklination (n)',
  'U-Deklination': 'Endung der U-Deklination',
  'E-Deklination-Konsonantstamm': 'Endung der E-Deklination (Konsonantstamm)',
  'Konsonantische-Deklination-i-mf':
      'Endung der konsonantischen Deklination (i-Stamm, m/f)',
  'Konsonantische-Deklination-i-n':
      'Endung der konsonantischen Deklination (i-Stamm, n)',
  'A-Konjugation': 'Endung der A-Konjugation',
  'E-Konjugation': 'Endung der E-Konjugation',
  'Konsonantische': 'Endung der konsonantischen Konjugation',
  'Mischkonjugation': 'Endung der Mischkonjugation',
  'Perfekt-System': 'Endung des Perfekts',
  'Unregelmäßig': 'unregelmäßige Endung',
};

String typePhrase(String type) =>
    endingTypePhrases[type] ??
    diagnosisOnlyTypePhrases[type] ??
    (throw StateError('no phrase for type $type'));

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
        params: {'answer': answer, 'types': types.map(typePhrase).join(', ')},
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
