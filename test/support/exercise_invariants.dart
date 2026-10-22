import 'package:latin_practice/data/exercise_cube.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

/// What is wrong with [e], built by [spec] for [word] in [bundle]; empty when
/// it is a valid exercise: every option is a covered cell of an unlocked
/// bundle with the rating fields filled, exactly one option is right, and no
/// two options can be taken for each other.
List<String> violations(
  Exercise e,
  KindSpec spec,
  PracticeItem word,
  GrammarBundle bundle,
  ExerciseContext ctx,
) {
  final cube = Cube(ctx);
  final found = <String>[
    if (e.kind != spec.kind) 'kind ${e.kind}',
    if (e.wordCardId != word.id) 'word card ${e.wordCardId}',
    if (e.grammarCardId != GrammarCardId(word.dataFileId, bundle))
      'grammar card ${e.grammarCardId}',
  ];
  Cell cellOf(FormOption o) {
    if (o.lexemeId != word.id) found.add('${o.text} has lexeme ${o.lexemeId}');
    final real = cube.cell(word, o.formKey);
    if (!cube.unlocked(real)) found.add('${o.text}: ${real.bundle} is locked');
    return o.builtWrongBy == null
        ? real
        : BuiltWrong(word, o.formKey, o.text, o.builtWrongBy!);
  }

  switch ((spec.answer, e.answer)) {
    case (
      Choose(:final view, :final count),
      ChoiceAnswer(:final options, :final right),
    ):
      final cells = options.map(cellOf).toList();
      final target = cells[options.indexOf(right)];
      if (options.length != count) found.add('${options.length} options');
      for (final (i, c) in cells.indexed) {
        final o = options[i];
        if (!cube.view(view).covers(c)) found.add('$view does not cover $c');
        if (o.text != cube.view(view).accepted(c).first) {
          found.add('${o.text} is not the shown text of $c');
        }
        if (o.builtWrongBy == null && view == View.latin) {
          if (!word.accepts(word.formOrder.indexOf(o.formKey), o.text)) {
            found.add('${o.text} is no form of $c but has no diagnosis');
          }
        }
        for (final other in cells.take(i)) {
          if (cube.clash(view, other, c)) found.add('$other clashes with $c');
        }
      }
      final promptViews = [
        for (final p in spec.params.values)
          if (p case Show(of: Ref.target, :final view)) view,
      ];
      final fitting = switch (spec.select) {
        OddOneOut() => [
          for (final c in cells)
            if (_alone(cells.cast<FormCell>(), c as FormCell)) c,
        ],
        _ => [
          for (final c in cells)
            if (promptViews.every((v) => cube.clash(v, target, c))) c,
        ],
      };
      if (fitting.length != 1 || fitting.single != target) {
        found.add('right ones: $fitting, target $target');
      }
    case (Typed(:final view), TypedAnswer(:final expected, :final accepted)):
      final target = cellOf(expected);
      if (target is! FormCell || target.bundle != bundle) {
        found.add('target $target is not in $bundle');
      }
      if (expected.text != cube.view(view).accepted(target).first) {
        found.add('${expected.text} is not the shown text of $target');
      }
      if (!cube.view(view).accepted(target).every(accepted.contains)) {
        found.add('$accepted lacks a spelling of $target');
      }
    default:
      found.add('answer ${e.answer.runtimeType} for ${spec.answer}');
  }
  return found;
}

bool _alone(List<FormCell> group, FormCell c) {
  final axes = {for (final g in group) ...g.features.keys};
  return axes.any((axis) {
    final values = {
      for (final g in group)
        if (g != c) g.features[axis],
    };
    return values.length == 1 && c.features[axis] != values.single;
  });
}
