import '../data/languages/language.dart' show Codes;
import 'form_label.dart';

/// The pick that says "this form has no value on that axis", e.g. the Person
/// of an Infinitiv.
const String absentValue = '';

/// The dropdowns the classification screen shows for one item: one per axis
/// whose value varies among the forms the learner may be asked about. An axis
/// the enabled forms agree on is not asked, it is [fixed].
class Selectors {
  final Axes axes;

  /// The axis ids with a dropdown, in axis order.
  final List<String> sections;

  /// Per shown axis, the codes it offers in axis order; [absentValue] comes
  /// first when some enabled form has no value on that axis.
  final Map<String, List<String>> options;

  /// Axis id → the single code every enabled form has; part of every pick.
  final Map<String, String> fixed;

  const Selectors({
    required this.axes,
    required this.sections,
    required this.options,
    required this.fixed,
  });

  /// The text of one option: the axis value's own text, never a label override
  /// (S17), so the Tempus dropdown reads "Futur I" under an Infinitiv too.
  String optionText(String section, String code) =>
      code == absentValue ? '—' : axes.byId(section).display(code);

  /// The dropdowns for exactly the axes [ids]: each offers every code of its
  /// axis, nothing is fixed.
  factory Selectors.forAxes(Axes axes, Iterable<String> ids) {
    final shown = axes.axes.map((a) => a.id).where(ids.contains).toList();
    assert(shown.length == ids.length, 'an id names no axis of $axes');
    return Selectors(
      axes: axes,
      sections: shown,
      options: {for (final id in shown) id: axes.byId(id).codes.toList()},
      fixed: const {},
    );
  }

  bool isComplete(Map<String, String?> picks) =>
      sections.every((section) => picks[section] != null);

  /// The label of [labels] that [picks] names, or null if there is none.
  FormLabel? labelFor(Map<String, String?> picks, List<FormLabel> labels) {
    assert(isComplete(picks));
    final features = {
      ...fixed,
      for (final section in sections)
        if (picks[section] != absentValue) section: picks[section]!,
    };
    final key = axes.formatKey(features);
    for (final label in labels) {
      if (label.key == key) return label;
    }
    return null;
  }

  /// The right dropdowns of [combinations]: each label of [correct] goes to
  /// at most one distinct combination, best match first, and counts the
  /// dropdowns that agree with it. Ties go to the earlier combination, then
  /// the earlier label.
  int rightPicks(
    List<Map<String, String?>> combinations,
    List<FormLabel> correct,
  ) {
    final distinct = {for (final c in combinations) textOf(c): c}.values;
    final pairs = [
      for (final (i, c) in distinct.indexed)
        for (final (j, label) in correct.indexed)
          (
            combination: i,
            label: j,
            agree: sections
                .where((s) => c[s] == (label.features[s] ?? absentValue))
                .length,
          ),
    ]..sort((a, b) => b.agree.compareTo(a.agree));
    final usedCombinations = <int>{};
    final usedLabels = <int>{};
    var right = 0;
    for (final p in pairs) {
      if (p.agree == 0) break;
      if (usedCombinations.contains(p.combination) ||
          usedLabels.contains(p.label)) {
        continue;
      }
      usedCombinations.add(p.combination);
      usedLabels.add(p.label);
      right += p.agree;
    }
    return right;
  }

  /// A pick in the words of the dropdowns, e.g. "Futur I 3. Person Singular".
  String textOf(Map<String, String?> picks) => [
    for (final section in sections)
      if (picks[section] != absentValue) optionText(section, picks[section]!),
  ].join(' ');

  /// [label] in the words of the dropdowns.
  String textOfLabel(FormLabel label) => textOf({
    for (final section in sections)
      section: label.features[section] ?? absentValue,
  });
}

/// The selectors for the forms the learner may be asked about.
Selectors selectorsFor(List<FormLabel> enabledLabels) {
  assert(enabledLabels.isNotEmpty);
  final axes = enabledLabels.first.axes;
  final sections = <String>[];
  final options = <String, List<String>>{};
  final fixed = <String, String>{};

  for (final axis in axes.axes) {
    final used = {
      for (final label in enabledLabels) label.features[axis.id] ?? absentValue,
    };
    if (used.length == 1) {
      if (used.single != absentValue) fixed[axis.id] = used.single;
      continue;
    }
    sections.add(axis.id);
    options[axis.id] = [
      if (used.contains(absentValue)) absentValue,
      ...axis.codes.where(used.contains),
    ];
  }

  return Selectors(
    axes: axes,
    sections: sections,
    options: options,
    fixed: fixed,
  );
}

/// What a classification question asks and which answers it accepts, with no
/// vocabulary card behind it: practice builds it from the forms of an item,
/// the exam from the analysis of a token.
class AnswerDescription {
  final Selectors selectors;

  /// The accepted combinations: shown axis id → code ([absentValue] for no
  /// value).
  final List<Map<String, String>> expected;

  AnswerDescription(this.selectors, this.expected) {
    assert(expected.isNotEmpty);
    assert(
      expected.every(
        (e) => selectors.sections.every(
          (s) => selectors.options[s]!.contains(e[s]),
        ),
      ),
      'an expected value is not on offer',
    );
  }

  /// The question "which of [correct] is this?" among [enabled] forms.
  factory AnswerDescription.ofLabels(
    List<FormLabel> enabled,
    List<FormLabel> correct,
  ) {
    final selectors = selectorsFor(enabled);
    return AnswerDescription(selectors, [
      for (final label in correct)
        {
          for (final s in selectors.sections)
            s: label.features[s] ?? absentValue,
        },
    ]);
  }

  /// The axes of the grammar file of [files] that has most of [merkmale] as
  /// axes, the first on a tie: its order is the order of the dropdowns of the
  /// token's word class.
  static Axes _fit(List<Axes> files, Iterable<String> merkmale) {
    int covered(Axes a) => a.axes.where((x) => merkmale.contains(x.id)).length;
    return files.reduce((a, b) => covered(b) > covered(a) ? b : a);
  }

  /// The merkmale of [merkmale] that have a dropdown in [files].
  static List<String> askable(List<Axes> files, Iterable<String> merkmale) {
    if (files.isEmpty) return const [];
    final ids = _fit(files, merkmale).axes.map((a) => a.id).toSet();
    return merkmale.where(ids.contains).toList();
  }

  /// The question for the [askable] merkmale of a token with analysis
  /// [codes].
  factory AnswerDescription.ofToken(
    List<Axes> files,
    Codes codes,
    Iterable<String> merkmale,
  ) {
    final ids = askable(files, merkmale);
    final selectors = Selectors.forAxes(_fit(files, merkmale), ids);
    return AnswerDescription(selectors, [
      {for (final id in selectors.sections) id: '${codes[id]!}'},
    ]);
  }

  bool accepts(Map<String, String?> picks) =>
      selectors.isComplete(picks) &&
      expected.any((e) => selectors.sections.every((s) => e[s] == picks[s]));
}
