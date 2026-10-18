import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/explanation.dart';
import '../models/practice_item.dart';

/// The explanation functions the screens call. Widget tests override
/// [explainerProvider] with hand-made lines.
typedef Explainer = ({
  List<ExplanationLine> Function(PracticeItem item, String formKey, String answer)
      wrongAnswer,
  // Q11 A: a correct answer is explained too when its spelling differs.
  List<ExplanationLine> Function(PracticeItem item, String formKey, String answer)
      correctAnswer,
  ExplanationLine Function(
          PracticeItem item, FormLabel? picked, String pickedText)
      pickedLabel,
});

final explainerProvider = Provider<Explainer>(
  (ref) => (
    wrongAnswer: explainWrongAnswer,
    correctAnswer: explainCorrectAnswer,
    pickedLabel: explainPickedLabel,
  ),
);

/// Renders explanation lines as small grey-blue text, one line per entry.
class ExplanationLines extends StatelessWidget {
  final List<ExplanationLine> lines;

  const ExplanationLines(this.lines, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map(
            (line) => Text(
              FlutterI18n.translate(
                context,
                line.key,
                translationParams: line.params,
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A6572)),
            ),
          )
          .toList(),
    );
  }
}
