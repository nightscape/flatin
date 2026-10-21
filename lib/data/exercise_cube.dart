/// The form cube: every form of a word is a cell, every way to show a cell is
/// a view. The clash rule and [optionOf] are the one place that decides when
/// two texts can be taken for each other and how a cell becomes an option.
library;

import '../models/exercise.dart';
import '../models/practice_item.dart';
import 'diagnosis.dart';
import 'german_forms.dart';

/// A form of a word, or a text built wrong for one of its keys.
sealed class Cell {
  PracticeItem get word;
  FormKey get key;
}

/// A real form: row [index] of [word].
final class FormCell extends Cell {
  @override
  final PracticeItem word;
  final int index;

  FormCell(this.word, this.index);

  @override
  FormKey get key => word.formOrder[index];

  Map<String, String> get features => word.formLabels[index].features;

  late final GrammarBundle bundle = bundleOf(word, key);

  @override
  bool operator ==(Object other) =>
      other is FormCell && other.word.id == word.id && other.index == index;

  @override
  int get hashCode => Object.hash(word.id, index);

  @override
  String toString() => '${word.id}@$key';
}

/// [text] is no form of [word]; [why] tells how it was built for [key].
final class BuiltWrong extends Cell {
  @override
  final PracticeItem word;
  @override
  final FormKey key;
  final String text;
  final Diagnosis why;

  BuiltWrong(this.word, this.key, this.text, this.why);

  @override
  String toString() => '${word.id}@$key:$text';
}

enum View { latin, german, lemma }

/// Turns a cell into the texts a learner may read or give for it.
abstract interface class ViewProvider {
  bool covers(Cell c);

  /// The first element is the shown text. Texts compare with their macrons:
  /// only learner input is read without them.
  List<String> accepted(Cell c);

  /// The options of one exercise share it, so the form of a text does not
  /// tell the right option.
  Object styleOf(Cell c);
}

final class _LatinView implements ViewProvider {
  const _LatinView();

  @override
  bool covers(Cell c) => true;

  @override
  List<String> accepted(Cell c) => switch (c) {
    FormCell(:final word, :final index) => word.acceptedForms[index],
    BuiltWrong(:final text) => [text],
  };

  @override
  Object styleOf(Cell c) => ();
}

/// The indirect question that makes a German subjunctive text unambiguous;
/// `{}` takes the text, the key is the tempus of the Latin form.
const _subjunctiveFrame = {
  'praes': 'Ich frage, ob {}.',
  'perf': 'Ich frage, ob {}.',
  'impf': 'Ich fragte, ob {}.',
  'plusq': 'Ich fragte, ob {}.',
};

final class _GermanView implements ViewProvider {
  const _GermanView(this.german);

  final GermanForms german;

  @override
  bool covers(Cell c) => c is FormCell && german.covers(c.word, c.key);

  @override
  List<String> accepted(Cell c) {
    final texts = german.accepted(c.word, c.key);
    if (!_framed(c)) return texts;
    final frame = _subjunctiveFrame[c.key.split('.')[1]]!;
    return [for (final t in texts) frame.replaceFirst('{}', t)];
  }

  @override
  Object styleOf(Cell c) => _framed(c);

  bool _framed(Cell c) => c.key.startsWith('konj.');
}

final class _LemmaView implements ViewProvider {
  const _LemmaView();

  @override
  bool covers(Cell c) => true;

  @override
  List<String> accepted(Cell c) => [c.word.lemma];

  @override
  Object styleOf(Cell c) => ();
}

/// An index over the words of an [ExerciseContext]; built per call.
final class Cube {
  Cube(this.ctx) : _german = _GermanView(ctx.german);

  final ExerciseContext ctx;
  final _GermanView _german;

  ViewProvider view(View v) => switch (v) {
    View.latin => const _LatinView(),
    View.german => _german,
    View.lemma => const _LemmaView(),
  };

  FormCell cell(PracticeItem word, FormKey key) {
    final index = word.formOrder.indexOf(key);
    assert(index >= 0, '"$key" is not a form of ${word.id}');
    return FormCell(word, index);
  }

  final _cells = <String, List<FormCell>>{};

  /// The cells of [word], of [bundle] only when given.
  Iterable<FormCell> cellsOf(PracticeItem word, {GrammarBundle? bundle}) {
    final cells = _cells.putIfAbsent(
      word.id,
      () => [for (var i = 0; i < word.formOrder.length; i++) FormCell(word, i)],
    );
    return bundle == null ? cells : cells.where((c) => c.bundle == bundle);
  }

  bool unlocked(FormCell c) => ctx.unlocked.contains(c.bundle);

  /// The cells of [c]'s word in an unlocked bundle that differ from [c] on
  /// exactly [k] axes.
  Iterable<FormCell> neighbours(FormCell c, {required int k}) =>
      cellsOf(c.word).where((n) => distance(c, n) == k && unlocked(n));

  /// The wrong texts that the endings of the word's other types give for
  /// [c]'s key.
  Iterable<BuiltWrong> builtWrong(FormCell c) sync* {
    final derivation = c.word.derivation;
    for (final entry in derivation.grammar.templatesByType.entries) {
      final template = entry.value[c.key];
      if (entry.key == derivation.type || template == null) continue;
      final stem = template.stemName == null
          ? ''
          : derivation.stems[template.stemName]?.stem;
      if (stem == null) continue;
      final text = stem + template.endings.first;
      if (c.word.accepts(c.index, text)) continue;
      final diagnosis = diagnose(c.word, c.key, text);
      if (diagnosis is EndingOfOtherType) {
        yield BuiltWrong(c.word, c.key, text, diagnosis);
      }
    }
  }

  /// Whether the shown text of [a] or [b] in [v] is accepted for the other.
  bool clash(View v, Cell a, Cell b) => fits(v, a, b) || fits(v, b, a);

  /// Whether the shown text of [target] in [v] is accepted for [c].
  bool fits(View v, Cell target, Cell c) =>
      _acceptedSet(v, c).contains(_shownText(v, target));

  final _accepted = {for (final v in View.values) v: <Cell, Set<String>>{}};
  final _shown = {for (final v in View.values) v: <Cell, String>{}};

  Set<String> _acceptedSet(View v, Cell c) => _accepted[v]!.putIfAbsent(c, () {
    final provider = view(v);
    return provider.accepted(c).toSet();
  });

  String _shownText(View v, Cell c) =>
      _shown[v]!.putIfAbsent(c, () => view(v).accepted(c).first);
}

/// The number of axes on which [a] and [b] differ; an axis only one of them
/// has counts.
int distance(FormCell a, FormCell b) {
  var n = 0;
  for (final MapEntry(:key, :value) in a.features.entries) {
    if (b.features[key] != value) n++;
  }
  for (final key in b.features.keys) {
    if (!a.features.containsKey(key)) n++;
  }
  return n;
}

/// The axes on which [a] and [b] differ; an axis only one of them has counts.
Set<String> differingAxes(FormCell a, FormCell b) => {
  ...a.features.keys,
  ...b.features.keys,
}.where((axis) => a.features[axis] != b.features[axis]).toSet();

/// The option that shows [c] in [v].
FormOption optionOf(Cell c, View v, Cube cube) => FormOption(
  text: cube.view(v).accepted(c).first,
  formKey: c.key,
  lexemeId: c.word.id,
  builtWrongBy: switch (c) {
    BuiltWrong(:final why) => why,
    FormCell() => null,
  },
);
