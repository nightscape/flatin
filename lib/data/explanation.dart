import '../models/practice_item.dart';

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
  throw UnimplementedError('L1 logic lane');
}

/// Classification screen: type and how the shown form follows from the rule.
/// [formKeys] are all keys whose form equals the shown string.
List<ExplanationLine> explainForm(PracticeItem item, List<String> formKeys) {
  throw UnimplementedError('L1 logic lane');
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
  throw UnimplementedError('L1 logic lane');
}
