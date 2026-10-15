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
  FormKey formKey,
  String answer,
) {
  final String label = describeLabels([_labelOf(item, formKey)]);
  return [
    _typeLine(item),
    ..._deponentLine(item, formKey, label),
    ..._formLines(item, formKey, label),
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
String _headword(PracticeItem item) =>
    item.principalParts.map((part) => part.$2).join(', ');

FormLabel _labelOf(PracticeItem item, FormKey formKey) {
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

/// S10: the key is practised in the active, but the form is a passive one.
List<ExplanationLine> _deponentLine(
  PracticeItem item,
  FormKey formKey,
  String label,
) =>
    item.derivation.deponentKeys.contains(formKey)
        ? [ExplanationLine('explain.deponent', params: {'label': label})]
        : const [];

/// S9: the other spellings that count as correct.
List<ExplanationLine> _variantsLine(PracticeItem item, FormKey formKey) {
  final variants = item.derivation.forms[formKey]!.variants;
  if (variants.length == 1) return const [];
  return [
    ExplanationLine('explain.variants', params: {
      'variants': variants.skip(1).join(', '),
    }),
  ];
}

/// How the asked form itself follows from the rule: stem plus ending, the
/// parts it is composed of, the dictionary forms to memorise, or the
/// dictionary form as it stands.
List<ExplanationLine> _formLines(
  PracticeItem item,
  FormKey formKey,
  String label,
) {
  final derivation = item.derivation;
  final form = derivation.forms[formKey]!;
  switch (form) {
    case final GeneratedForm generated:
      return [
        _stemLine(item, derivation.stems[generated.stemName]!),
        _generatedLine(item, generated, label),
      ];
    case final ComposedForm composed:
      return [_composedLine(item, composed, label)];
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
  }
}

/// S18 a: a seam rule explains itself in place of the plain sum; S14: an
/// ending from another type names that type.
ExplanationLine _generatedLine(
  PracticeItem item,
  GeneratedForm form,
  String label,
) {
  final String stem = item.derivation.stems[form.stemName]!.stem;
  if (form.sandhiRule != null) {
    return _sandhiLine(
      label: label,
      before: '$stem + ${form.ending}',
      after: form.result,
      rule: form.sandhiRule!,
    );
  }
  final params = {
    'label': label,
    'stem': stem,
    'ending': form.ending,
    'result': form.result,
  };
  if (form.endingType == item.type) {
    return ExplanationLine('explain.generated', params: params);
  }
  return ExplanationLine(
    'explain.generatedOtherType',
    params: {...params, 'endingType': form.endingType},
  );
}

/// S13: the parts as they go in, the form as it comes out. An affix is named
/// by the stem it is cut from, so the seam rule has something to change.
ExplanationLine _composedLine(
  PracticeItem item,
  ComposedForm form,
  String label,
) {
  final stems = item.derivation.stems;
  final String pieces = form.parts
      .map((part) => part is AffixPart ? stems[part.stemName]!.stem : part.text)
      .join(' + ');
  final rule = form.parts
      .whereType<AffixPart>()
      .map((part) => part.sandhiRule)
      .nonNulls
      .firstOrNull;
  if (rule != null) {
    return _sandhiLine(
      label: label,
      before: pieces,
      after: form.result,
      rule: rule,
    );
  }
  return ExplanationLine('explain.composed', params: {
    'label': label,
    'parts': pieces,
    'result': form.result,
  });
}

ExplanationLine _sandhiLine({
  required String label,
  required String before,
  required String after,
  required SandhiRule rule,
}) =>
    ExplanationLine('explain.sandhi', params: {
      'label': label,
      'before': before,
      'after': after,
      'rule': rule.explain,
    });

ExplanationLine _stemLine(PracticeItem item, StemDerivation stem) {
  switch (stem) {
    // Naming the part the stem comes from only helps when it is not the first
    // spelling the learner sees anyway.
    case StemFromPart(:final sourceWord, :final removedSuffix)
        when sourceWord != item.principalParts.first.$2:
      return ExplanationLine('explain.stemSource', params: {
        'display': stem.display,
        'stem': stem.stem,
        'source': sourceWord,
        'suffix': removedSuffix,
      });
    case StemFromPart():
      return ExplanationLine('explain.stem', params: {
        'display': stem.display,
        'stem': stem.stem,
      });
    case StemFromDefault(:final template, :final base, :final sandhiRule):
      final String rest = template.replaceAll('{${base.name}}', '');
      if (sandhiRule != null) {
        return _sandhiLine(
          label: stem.display,
          before: '${base.stem} + $rest',
          after: stem.stem,
          rule: sandhiRule,
        );
      }
      return ExplanationLine('explain.stemDefault', params: {
        'display': stem.display,
        'stem': stem.stem,
        'base': _baseText(base),
        'rest': rest,
      });
  }
}

/// A stem cut from a principal part is shown as that cut, so the chain back to
/// the dictionary form stays visible: "amāre − āre" instead of "am".
String _baseText(StemDerivation base) => switch (base) {
      StemFromPart(:final sourceWord, :final removedSuffix) =>
        '$sourceWord − $removedSuffix',
      _ => base.stem,
    };

ExplanationLine _diagnosisLine(
  PracticeItem item,
  FormKey formKey,
  String answer,
) {
  final diagnosis = diagnose(item, formKey, answer);
  switch (diagnosis) {
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
    case WrongStem(:final usedStem, :final stemName):
      final stem = item.derivation.stems[stemName]!;
      return ExplanationLine('explain.diag.wrongStem', params: {
        'answer': answer,
        'usedStem': usedStem,
        'display': stem.display,
        'stem': stem.stem,
      });
    case NoMatch():
      return ExplanationLine('explain.diag.noMatch', params: {
        'answer': answer,
      });
  }
}

/// Classification screen: type and how the shown form follows from the rule.
/// [formKeys] are all keys whose form equals the shown string.
List<ExplanationLine> explainForm(PracticeItem item, List<FormKey> formKeys) {
  assert(formKeys.isNotEmpty);
  final String labels = describeLabels(
    formKeys.map((key) => _labelOf(item, key)).toList(),
  );
  final form = item.derivation.forms[formKeys.first]!;
  return [
    _typeLine(item),
    ..._deponentLine(item, formKeys.first, labels),
    switch (form) {
      // Here the derivation runs backwards: from the shown form to the rule.
      final GeneratedForm generated when generated.sandhiRule == null =>
        ExplanationLine('explain.formBackToRule', params: {
          'result': generated.result,
          'stem': item.derivation.stems[generated.stemName]!.stem,
          'ending': generated.ending,
          'labels': labels,
        }),
      final GeneratedForm generated => _generatedLine(item, generated, labels),
      final ComposedForm composed => _composedLine(item, composed, labels),
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
    },
    ..._variantsLine(item, formKeys.first),
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
