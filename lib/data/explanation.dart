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

/// Practice screen: type, derivation of the asked form, and what the answer is.
List<ExplanationLine> explainWrongAnswer(
  PracticeItem item,
  String formKey,
  String answer,
) {
  final String label = describeLabels([_labelOf(item, formKey)]);
  return [
    _typeLine(item),
    ..._formLines(item, formKey, label),
    _diagnosisLine(item, formKey, answer),
  ];
}

/// The dictionary entry of the item: nominative and genitive, or 1st person
/// and infinitive, whichever the data gives.
String _headword(PracticeItem item) =>
    item.principalParts.map((part) => part.$2).join(', ');

/// The one stem the v1 loader builds.
StemDerivation _theStem(PracticeItem item) => item.derivation.stems.values.single;

FormLabel _labelOf(PracticeItem item, String formKey) {
  final int index = item.formOrder.indexOf(formKey);
  assert(index >= 0, '"$formKey" is not a form of "${item.translation}"');
  return item.formLabels[index];
}

ExplanationLine _typeLine(PracticeItem item) {
  final recognition = item.derivation.recognition;
  final String word = _headword(item);
  switch (recognition) {
    case TypeByRule(:final suffix, :final candidateTypes):
      if (candidateTypes.length > 1) {
        return ExplanationLine('explain.typeByRuleAmbiguous', params: {
          'word': word,
          'suffix': suffix,
          'candidates': candidateTypes.join(', '),
          'type': item.type,
        });
      }
      return ExplanationLine('explain.typeByRule', params: {
        'word': word,
        'suffix': suffix,
        'type': item.type,
      });
    case TypeDeclared():
      return ExplanationLine('explain.typeDeclared', params: {
        'word': word,
        'type': item.type,
      });
  }
}

/// How the asked form itself follows from the rule: stem plus ending, the
/// dictionary forms to memorise, or the dictionary form as it stands.
List<ExplanationLine> _formLines(
  PracticeItem item,
  String formKey,
  String label,
) {
  final derivation = item.derivation;
  final form = derivation.forms[formKey]!;
  switch (form) {
    case GeneratedForm(:final ending, :final result, :final stemName):
      final stem = derivation.stems[stemName]!;
      return [
        _stemLine(item, stem),
        ExplanationLine('explain.generated', params: {
          'label': label,
          'stem': stem.stem,
          'ending': ending,
          'result': result,
        }),
      ];
    case IrregularForm(:final result):
      return [
        ExplanationLine('explain.irregular', params: {
          'dictionary': _headword(item),
          'label': label,
          'result': result,
        }),
      ];
    case GivenForm(:final result):
      return [
        ExplanationLine('explain.given', params: {
          'result': result,
          'label': label,
        }),
      ];
    case ComposedForm():
      throw UnimplementedError('a composed form reads out its parts');
  }
}

ExplanationLine _stemLine(PracticeItem item, StemDerivation stem) {
  switch (stem) {
    // Naming the part the stem comes from only helps when it is not the first
    // spelling the learner sees anyway.
    case StemFromPart(:final sourceWord, :final removedSuffix)
        when sourceWord != item.principalParts.first.$2:
      return ExplanationLine('explain.stemSource', params: {
        'stem': stem.stem,
        'source': sourceWord,
        'suffix': removedSuffix,
      });
    case StemFromPart():
      return ExplanationLine('explain.stem', params: {'stem': stem.stem});
    case StemFromDefault(:final template, :final base):
      return ExplanationLine('explain.stemDefault', params: {
        'stem': stem.stem,
        'template': template,
        'base': base.stem,
      });
  }
}

ExplanationLine _diagnosisLine(
  PracticeItem item,
  String formKey,
  String answer,
) {
  final diagnosis = diagnose(item, formKey, answer);
  switch (diagnosis) {
    case OnlyDiacritics():
      return ExplanationLine('explain.diag.onlyDiacritics', params: {
        'answer': answer,
      });
    case RegularInsteadOfIrregular():
      return ExplanationLine('explain.diag.regularInsteadOfIrregular', params: {
        'answer': answer,
        'label': describeLabels([_labelOf(item, formKey)]),
      });
    case OtherFormOfWord(:final formKeys):
      return ExplanationLine('explain.diag.otherForm', params: {
        'answer': answer,
        'labels': describeLabels(
          formKeys.map((key) => _labelOf(item, key)).toList(),
        ),
      });
    case EndingOfOtherType(:final types):
      return ExplanationLine('explain.diag.otherType', params: {
        'answer': answer,
        'types': types.join(', '),
      });
    case WrongStem(:final usedStem):
      return ExplanationLine('explain.diag.wrongStem', params: {
        'answer': answer,
        'usedStem': usedStem,
        'stem': _theStem(item).stem,
      });
    case NoMatch():
      return ExplanationLine('explain.diag.noMatch', params: {
        'answer': answer,
      });
  }
}

/// Classification screen: type and how the shown form follows from the rule.
/// [formKeys] are all keys whose form equals the shown string.
List<ExplanationLine> explainForm(PracticeItem item, List<String> formKeys) {
  assert(formKeys.isNotEmpty);
  final String labels = describeLabels(
    formKeys.map((key) => _labelOf(item, key)).toList(),
  );
  final form = item.derivation.forms[formKeys.first]!;
  return [
    _typeLine(item),
    switch (form) {
      // Here the derivation runs backwards: from the shown form to the rule.
      GeneratedForm(:final ending, :final result, :final stemName) =>
        ExplanationLine('explain.formBackToRule', params: {
          'result': result,
          'stem': item.derivation.stems[stemName]!.stem,
          'ending': ending,
          'labels': labels,
        }),
      IrregularForm(:final result) =>
        ExplanationLine('explain.irregular', params: {
          'dictionary': _headword(item),
          'label': labels,
          'result': result,
        }),
      GivenForm(:final result) => ExplanationLine('explain.given', params: {
          'result': result,
          'label': labels,
        }),
      ComposedForm() =>
        throw UnimplementedError('a composed form reads out its parts'),
    },
  ];
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
    return ExplanationLine('explain.pickedMissing', params: {
      'picked': pickedText,
    });
  }

  final int index = item.formLabels.indexOf(picked);
  assert(index >= 0, '"$pickedText" is not a form of "${item.translation}"');
  final form = item.derivation.forms[item.formOrder[index]]!;
  final String text = form is GeneratedForm
      ? '${form.result} '
          '(${item.derivation.stems[form.stemName]!.stem} + ${form.ending})'
      : form.result;

  return ExplanationLine('explain.pickedWouldBe', params: {
    'picked': pickedText,
    'form': text,
  });
}
