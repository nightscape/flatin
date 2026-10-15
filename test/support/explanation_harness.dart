import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/widgets/explanation_lines.dart';

/// One hand-made line per `explain.*` key, every parameter filled.
const sampleLines = <ExplanationLine>[
  ExplanationLine('explain.typeByRule', params: {
    'word': 'dominus',
    'suffix': 'us',
    'type': 'O-Deklination-maskulinum',
  }),
  ExplanationLine('explain.typeByRuleAmbiguous', params: {
    'word': 'monēre',
    'suffix': 'ēre',
    'candidates': 'E-Konjugation, Mischkonjugation',
    'type': 'E-Konjugation',
  }),
  ExplanationLine('explain.typeDeclared', params: {
    'word': 'manus',
    'type': 'U-Deklination',
  }),
  ExplanationLine('explain.stem', params: {'stem': 'domin'}),
  ExplanationLine('explain.stemSource', params: {
    'stem': 'domin',
    'source': 'dominus',
    'suffix': 'us',
  }),
  ExplanationLine('explain.stemDefault', params: {
    'stem': 'amā',
    'template': 'wurzel + ā',
    'base': 'am',
  }),
  ExplanationLine('explain.sandhi', params: {
    'before': 'amā + ō',
    'after': 'amō',
    'rule': 'ā fällt vor Vokal aus',
  }),
  ExplanationLine('explain.composed', params: {
    'label': 'Perfekt: 1. Person Singular',
    'parts': 'amātus + sum',
    'result': 'amātus sum',
  }),
  ExplanationLine('explain.deponent', params: {
    'label': 'Präsens: 1. Person Singular',
  }),
  ExplanationLine('explain.variants', params: {'variants': 'dominūm'}),
  ExplanationLine('explain.correctWithMacrons', params: {
    'result': 'dominōrum',
  }),
  ExplanationLine('explain.generated', params: {
    'label': 'Genitiv Plural',
    'stem': 'domin',
    'ending': 'orum',
    'result': 'dominorum',
  }),
  ExplanationLine('explain.given', params: {
    'result': 'dominus',
    'label': 'Nominativ Singular',
  }),
  ExplanationLine('explain.irregular', params: {
    'dictionary': 'deus',
    'label': 'Nominativ Plural',
    'result': 'dei',
  }),
  ExplanationLine('explain.formBackToRule', params: {
    'result': 'dominis',
    'stem': 'domin',
    'ending': 'is',
    'labels': 'Dativ/Ablativ Plural',
  }),
  ExplanationLine('explain.pickedWouldBe', params: {
    'picked': 'Genitiv Plural',
    'form': 'dominorum',
  }),
  ExplanationLine('explain.pickedMissing', params: {'picked': 'Vokativ Plural'}),
  ExplanationLine('explain.diag.onlyDiacritics',
      params: {'answer': 'dominōrum'}),
  ExplanationLine('explain.diag.regularInsteadOfIrregular', params: {
    'answer': 'deii',
    'label': 'Nominativ Plural',
  }),
  ExplanationLine('explain.diag.otherForm', params: {
    'answer': 'dominis',
    'labels': 'Dativ/Ablativ Plural',
  }),
  ExplanationLine('explain.diag.otherType', params: {
    'answer': 'rosorum',
    'types': 'O-Deklination-maskulinum',
  }),
  ExplanationLine('explain.diag.wrongStem', params: {
    'answer': 'dominusorum',
    'usedStem': 'dominus',
    'stem': 'domin',
  }),
  ExplanationLine('explain.diag.noMatch', params: {'answer': 'zzz'}),
];

/// Picks [value] in the [index]-th dropdown of the classification selectors.
Future<void> pickOption(WidgetTester tester, int index, String value) async {
  final dropdown = find.byType(DropdownButtonFormField<String>).at(index);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

/// Stands in for the real [explainWrongAnswer] / [explainForm] /
/// [explainPickedLabel] while the logic lane is open, and records its calls.
class ExplainerSpy {
  final List<(String formKey, String answer)> wrongAnswerCalls = [];
  final List<List<String>> formCalls = [];
  final List<(FormLabel? picked, String pickedText)> pickedCalls = [];

  Explainer get explainer => (
        wrongAnswer: (PracticeItem item, String formKey, String answer) {
          wrongAnswerCalls.add((formKey, answer));
          return [
            ExplanationLine('explain.diag.noMatch', params: {'answer': answer}),
          ];
        },
        form: (PracticeItem item, List<String> formKeys) {
          formCalls.add(formKeys);
          return [
            ExplanationLine('explain.typeDeclared',
                params: {'word': 'shown', 'type': formKeys.join('+')}),
          ];
        },
        pickedLabel:
            (PracticeItem item, FormLabel? picked, String pickedText) {
          pickedCalls.add((picked, pickedText));
          return picked == null
              ? ExplanationLine('explain.pickedMissing',
                  params: {'picked': pickedText})
              : ExplanationLine('explain.pickedWouldBe',
                  params: {'picked': pickedText, 'form': picked.displayName});
        },
      );
}
