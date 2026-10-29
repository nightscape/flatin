import 'package:flutter/foundation.dart' show listEquals;
import 'package:latin_practice/data/exercise_choice.dart' show knowsWell;
import 'package:latin_practice/data/exercise_cube.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/models/derivation.dart' show norm;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';

/// The bundles a context unlocks so that [spec] can build in [bundle]: a chain
/// of several steps starts outside the asked bundle.
Set<GrammarBundle> unlockedFor(
  KindSpec spec,
  PracticeItem word,
  GrammarBundle bundle,
) => switch (spec.select) {
  AxisPath(:final lengths) when lengths.any((n) => n > 1) => {
    for (final key in word.formOrder) bundleOf(word, key),
  },
  PrincipalParts() => {for (final key in word.formOrder) bundleOf(word, key)},
  LookAlikes(:final sets) => {
    for (final s in sets)
      if (s.contains(bundle)) ...s,
  },
  _ => {bundle},
};

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
      for (final MapEntry(:key, :value) in spec.params.entries) {
        if (value case Show(of: Ref.spoiled)) {
          final text = e.questionParams[key]!;
          if (cube.isFormOf(word, text)) found.add('$text is a form of $word');
          if (accepted.contains(text)) found.add('$accepted accept $text');
        }
      }
      if (spec.select is AxisPath &&
          (ctx.avoidMacronTwins
              ? norm(e.questionParams['start']!) == norm(expected.text)
              : e.questionParams['start'] == expected.text)) {
        found.add('the start ${expected.text} is the answer');
      }
    case (Match(:final left, :final right), MatchingAnswer(:final pairs)):
      final n = (spec.select as Sample).n;
      if (pairs.length != n) found.add('${pairs.length} pairs');
      final cells = <Cell>[];
      for (final (l, r) in pairs) {
        if (l.builtWrongBy != null || r.builtWrongBy != null) {
          found.add('${l.text} is a wrong text');
        }
        final c = cellOf(l);
        if (r.formKey != l.formKey || r.lexemeId != l.lexemeId) {
          found.add('${l.text} and ${r.text} are not one cell');
        }
        if (c is! FormCell || c.bundle != bundle) {
          found.add('$c is not in $bundle');
        }
        for (final (v, o) in [(left, l), (right, r)]) {
          if (!cube.view(v).covers(c)) found.add('$v does not cover $c');
          if (o.text != cube.view(v).accepted(c).first) {
            found.add('${o.text} is not the shown text of $c');
          }
        }
        for (final other in cells) {
          if ((left == View.latin && ctx.avoidMacronTwins
                  ? cube.lookAlike(other, c)
                  : cube.clash(left, other, c)) ||
              cube.clash(right, other, c)) {
            found.add('$other clashes with $c');
          }
        }
        cells.add(c);
      }
    case (
      Sort(:final view, :final tick),
      SortingAnswer(:final groups, :final forms),
    ):
      final select = spec.select as LookAlikes;
      if (forms.length < select.count.min || forms.length > select.count.max) {
        found.add('${forms.length} forms');
      }
      if (tick && groups.length != 2) found.add('tick with $groups');
      final cells = [
        for (final (o, _) in forms)
          cube.cell(ctx.pool.singleWhere((w) => w.id == o.lexemeId), o.formKey),
      ];
      final lookAlikes = select.sets.where(
        (s) => s.contains(bundle) && cells.every((c) => s.contains(c.bundle)),
      );
      if (lookAlikes.isEmpty) found.add('no set holds $bundle and the forms');
      if (!cells.any((c) => c.word.id == word.id && c.bundle == bundle)) {
        found.add('no form of ${word.id} in $bundle');
      }
      for (final (i, c) in cells.indexed) {
        final (o, group) = forms[i];
        if (o.builtWrongBy != null) found.add('${o.text} is a wrong text');
        if (o.text != cube.view(view).accepted(c).first) {
          found.add('${o.text} is not the shown text of $c');
        }
        if (!cube.unlocked(c)) found.add('$c is locked');
        final same = [
          for (final (j, d) in cells.indexed)
            if (d.bundle == c.bundle) forms[j].$2,
        ];
        if (same.toSet().length != 1) found.add('$c splits its bundle');
        if (tick && (group == 0) != (c.bundle == bundle)) {
          found.add('$c is ticked wrong');
        }
        for (final other in cells.take(i)) {
          if (cube.lookAlike(other, c)) found.add('$other clashes with $c');
        }
        for (final o2 in cube.allCellsOf(c.word)) {
          if (o2.bundle != c.bundle &&
              lookAlikes.any((s) => s.contains(o2.bundle)) &&
              cube.lookAlike(c, o2)) {
            found.add('$c reads like $o2');
          }
        }
      }
    case (
      Parts(:final view),
      PartsAnswer(:final prompt, :final slots, :final given),
    ):
      final select = spec.select as PrincipalParts;
      final deponent = select.row.any(
        (p) => word.derivation.deponentKeys.contains(p.key),
      );
      final row = [
        for (final (:key, name: _) in select.row)
          if (word.formOrder.contains(key) &&
              !(deponent && key == select.supine) &&
              cube.practised(cube.cell(word, key)))
            key,
      ];
      final known = knowsWell([
        ctx.stabilityOf(word.id),
        for (final k in row) ctx.stabilityOf(GrammarCardId.of(word, k)),
      ]);
      final promptCell = cube.cell(word, prompt.formKey);
      final cells = [
        for (final s in slots) cube.cell(word, s.answer.expected.formKey),
      ];
      for (final c in [
        promptCell,
        ...cells,
        for (final g in given) cube.cell(word, g.form.formKey),
      ]) {
        if (!cube.unlocked(c)) found.add('$c is locked');
      }
      final shown = [for (final c in cells) c.key];
      for (final g in given) {
        shown.insert(g.at, g.form.formKey);
        if (g.form.text != prompt.text) {
          found.add('given ${g.form.text} is not spelt like ${prompt.text}');
        }
        if (g.name !=
            select.row.singleWhere((p) => p.key == g.form.formKey).name) {
          found.add('given ${g.form.text} is named ${g.name}');
        }
      }
      for (final s in slots) {
        if (s.answer.expected.text == prompt.text) {
          found.add('slot ${s.answer.expected.text} is spelt like the prompt');
        }
      }
      if (known) {
        if (!select.promptsFrom.any(prompt.formKey.startsWith)) {
          found.add('prompt ${prompt.formKey} is no prompt form');
        }
        if (!cube.practised(promptCell)) {
          found.add('prompt $promptCell is not practised');
        }
        final plain = norm(prompt.text);
        for (final other in ctx.pool) {
          // The length test only skips the slow norm of most forms.
          if (other.id != word.id &&
              other.acceptedForms.any(
                (fs) => fs.any(
                  (f) => f.length == prompt.text.length && norm(f) == plain,
                ),
              )) {
            found.add('prompt ${prompt.text} is also a form of ${other.id}');
          }
        }
      } else {
        if (prompt.formKey != select.row.first.key) {
          found.add('prompt ${prompt.formKey} is not the first part');
        }
        if (cells.any((c) => cube.lookAlike(c, promptCell))) {
          found.add('prompt ${prompt.text} is the answer of a slot');
        }
      }
      if (!listEquals(shown, known ? row : row.skip(1).toList())) {
        found.add('parts $shown are not the row $row');
      }
      if ({
            for (final k in row) norm(word.forms[word.formOrder.indexOf(k)]),
          }.length <
          select.minParts) {
        found.add('the row $row has too few distinct parts');
      }
      if (!cells.any((c) => c.bundle == bundle)) {
        found.add('no asked slot in the rated bundle $bundle');
      }
      for (final (i, (:name, :answer)) in slots.indexed) {
        final c = cells[i];
        if (name != select.row.singleWhere((p) => p.key == c.key).name) {
          found.add('slot $i is named $name');
        }
        if (answer.expected.text != cube.view(view).accepted(c).first ||
            !listEquals(answer.accepted, cube.view(view).accepted(c))) {
          found.add('slot ${answer.expected.text} is not the text of $c');
        }
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
