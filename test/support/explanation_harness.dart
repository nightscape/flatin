import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/widgets/explanation_lines.dart';

/// One hand-made line per `explain.*` key, every parameter filled.
const sampleLines = <ExplanationLine>[
  ExplanationLine(
    'explain.deponent',
    params: {'label': 'Präsens: 1. Person Singular'},
  ),
  ExplanationLine('explain.variants', params: {'variants': 'dominūm'}),
  ExplanationLine(
    'explain.correctWithMacrons',
    params: {'result': 'dominōrum'},
  ),
  ExplanationLine(
    'explain.pickedWouldBe',
    params: {'picked': 'Genitiv Plural', 'form': 'dominorum'},
  ),
  ExplanationLine(
    'explain.pickedMissing',
    params: {'picked': 'Vokativ Plural'},
  ),
  ExplanationLine(
    'explain.diag.regularInsteadOfIrregular',
    params: {'answer': 'deii', 'label': 'Nominativ Plural'},
  ),
  ExplanationLine(
    'explain.diag.otherForm',
    params: {'answer': 'dominis', 'labels': 'Dativ/Ablativ Plural'},
  ),
  ExplanationLine(
    'explain.diag.otherType',
    params: {'answer': 'rosorum', 'types': 'Endung der O-Deklination (m)'},
  ),
  ExplanationLine(
    'explain.diag.wrongStem',
    params: {
      'answer': 'dominusorum',
      'usedStem': 'dominus',
      'display': 'Stamm',
      'stem': 'domin',
    },
  ),
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

/// Stands in for the real [explainWrongAnswer] /
/// [explainPickedLabel] while the logic lane is open, and records its calls.
class ExplainerSpy {
  final List<(String formKey, String answer)> wrongAnswerCalls = [];
  final List<(String formKey, String answer)> correctAnswerCalls = [];
  final List<(FormLabel? picked, String pickedText)> pickedCalls = [];

  Explainer get explainer => (
    wrongAnswer: (PracticeItem item, String formKey, String answer) {
      wrongAnswerCalls.add((formKey, answer));
      return [
        ExplanationLine('explain.diag.noMatch', params: {'answer': answer}),
      ];
    },
    correctAnswer: (PracticeItem item, String formKey, String answer) {
      correctAnswerCalls.add((formKey, answer));
      return [
        ExplanationLine(
          'explain.correctWithMacrons',
          params: {'result': answer},
        ),
      ];
    },
    pickedLabel: (PracticeItem item, FormLabel? picked, String pickedText) {
      pickedCalls.add((picked, pickedText));
      return picked == null
          ? ExplanationLine(
              'explain.pickedMissing',
              params: {'picked': pickedText},
            )
          : ExplanationLine(
              'explain.pickedWouldBe',
              params: {'picked': pickedText, 'form': picked.displayName},
            );
    },
  );
}
