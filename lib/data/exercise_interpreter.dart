/// Builds the exercises of a [KindSpec]: draws slices of the cube until one
/// is covered by every view the spec reads and gives an answer under the
/// clash rule.
library;

import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals, mapEquals;

import '../models/exercise.dart';
import '../models/practice_item.dart';
import 'exercise_cube.dart';
import 'exercise_spec.dart';

/// The cells one exercise is about.
final class Slice {
  final FormCell target;

  /// [AxisPath]: start … target.
  final List<FormCell> path;

  /// [OddOneOut]: the majority and the target.
  final List<FormCell> group;

  /// [Spoil]: the wrong text built for the target's key.
  final BuiltWrong? spoiled;

  /// [LookAlikes]: the set the group is drawn from.
  final List<GrammarBundle> lookAlikes;

  Slice(
    this.target, {
    List<FormCell>? path,
    this.group = const [],
    this.spoiled,
    this.lookAlikes = const [],
  }) : path = path ?? [target];

  @override
  String toString() =>
      'Slice(${path.join(' → ')}, group: $group, spoiled: $spoiled)';
}

/// The generator of one spec.
/// Produced in `exercise_kinds.dart`; read by the selection.
final class SpecGenerator implements ExerciseGenerator {
  const SpecGenerator(this.spec, {this.vocab});

  final KindSpec spec;

  /// How the kind asks a vocab item; null when it asks none.
  final KindSpec? vocab;

  @override
  ExerciseKind get kind => spec.kind;

  KindSpec _specFor(PracticeItem word) => word.isVocab
      ? vocab ?? (throw CannotBuild('${kind.name} asks no vocab item'))
      : spec;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    if (!ctx.unlocked.contains(bundle)) throw CannotBuild('$bundle is locked');
    final spec = _specFor(word);
    final cube = Cube(ctx);
    final reasons = <String>{};
    for (final slice in _slices(spec.select, cube, word, bundle, rng)) {
      final missing = _uncovered(spec, slice, cube);
      if (missing != null) {
        reasons.add(missing);
        continue;
      }
      final answer = _answerOf(spec, slice, cube, rng);
      if (answer == null) {
        reasons.add('too few options for ${slice.target.key}');
        continue;
      }
      return Exercise(
        wordCardId: word.id,
        grammarCardId: GrammarCardId(word.dataFileId, bundle),
        kind: spec.kind,
        questionKey: spec.questionKey,
        questionParams: _paramsOf(spec, slice, cube),
        answer: answer,
      );
    }
    throw CannotBuild(
      '${word.id} in $bundle: '
      '${reasons.isEmpty ? 'no ${spec.select.runtimeType}' : reasons.take(3).join('; ')}',
    );
  }

  /// Why [spec] could not have made [exercise] for [word] in [bundle]; empty
  /// when it could. Draws nothing.
  List<String> objections(
    Exercise exercise,
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
  ) {
    final spec = _specFor(word);
    if (exercise.kind != spec.kind ||
        exercise.questionKey != spec.questionKey ||
        exercise.wordCardId != word.id ||
        exercise.grammarCardId != GrammarCardId(word.dataFileId, bundle)) {
      return ['kind, question or cards differ'];
    }
    final cube = Cube(ctx);
    final target = cube.cell(word, switch (exercise.answer) {
      ChoiceAnswer(:final right) => right.formKey,
      TypedAnswer(:final expected) => expected.formKey,
      MatchingAnswer(:final pairs) => pairs.first.$1.formKey,
      SortingAnswer(:final forms) =>
        forms
            .firstWhere(
              (f) =>
                  f.$1.lexemeId == word.id &&
                  bundleOf(word, f.$1.formKey) == bundle,
            )
            .$1
            .formKey,
    });
    final objections = <String>[];
    for (final slice in _slicesInto(spec, cube, target, bundle, exercise)) {
      final missing = _uncovered(spec, slice, cube);
      if (missing != null) {
        objections.add(missing);
      } else if (!mapEquals(
        _paramsOf(spec, slice, cube),
        exercise.questionParams,
      )) {
        objections.add(
          'params ${exercise.questionParams} are not those of $slice',
        );
      } else {
        final why = _answerObjection(spec, slice, cube, exercise.answer);
        if (why == null) return [];
        objections.add(why);
      }
    }
    return objections.isEmpty
        ? ['no ${spec.select.runtimeType} into $target']
        : objections;
  }
}

Iterable<Slice> _slices(
  Selection select,
  Cube cube,
  PracticeItem word,
  GrammarBundle bundle,
  Random rng,
) => switch (select) {
  OneCell() => (cube.cellsOf(word, bundle: bundle).toList()..shuffle(rng)).map(
    Slice.new,
  ),
  OddOneOut() => _oddOneOut(select, cube, word, bundle, rng),
  Spoil(:final ways) => [
    for (final target in cube.cellsOf(word, bundle: bundle))
      for (final spoiled in _spoilings(cube, target, ways))
        Slice(target, spoiled: spoiled),
  ]..shuffle(rng),
  Sample() => _sample(
    word.isVocab
        ? [
            ...cube.cellsOf(word, bundle: bundle),
            ...(cube.neighbours(cube.allCellsOf(word).single, k: 0).toList()
              ..shuffle(rng)),
          ]
        : (cube.cellsOf(word, bundle: bundle).toList()..shuffle(rng)),
  ),
  LookAlikes() => _lookAlikes(select, cube, word, bundle, rng),
  AxisPath(:final axes, :final lengths) =>
    (cube.cellsOf(word, bundle: bundle).toList()..shuffle(rng)).expand(
      (target) => (lengths.toList()..shuffle(rng)).expand(
        (n) => _routes(
          cube,
          target,
          n,
          axes,
          rng,
        ).map((path) => Slice(target, path: path)),
      ),
    ),
};

/// One slice of all [cells]; the answer takes the cells it can use.
Iterable<Slice> _sample(List<FormCell> cells) => [
  if (cells.isNotEmpty) Slice(cells.first, group: cells),
];

/// Every slice of [select] whose target is [target], read from [exercise]
/// where the selection is random.
Iterable<Slice> _slicesInto(
  KindSpec spec,
  Cube cube,
  FormCell target,
  GrammarBundle bundle,
  Exercise exercise,
) => switch (spec.select) {
  OneCell() => [if (target.bundle == bundle) Slice(target)],
  OddOneOut select => [
    if (exercise.answer case ChoiceAnswer(:final options))
      if (options.every((o) => o.builtWrongBy == null))
        if ([for (final o in options) cube.cell(target.word, o.formKey)]
            case final group
            when group.every(cube.practised) &&
                _isOddOneOut(select, cube, group, target, bundle))
          Slice(target, group: group),
  ],
  Spoil(:final ways) => [
    if (target.bundle == bundle)
      for (final spoiled in _spoilings(cube, target, ways))
        if (spoiled.text == exercise.questionParams[_spoiledParam(spec)])
          Slice(target, spoiled: spoiled),
  ],
  Sample() => [
    if (exercise.answer case MatchingAnswer(:final pairs))
      if ([for (final (l, _) in pairs) cube.cellOf(l, target.word)]
          case final group
          when group.every((c) => c.bundle == bundle && cube.practised(c)))
        Slice(target, group: group),
  ],
  LookAlikes(:final sets) => [
    if (exercise.answer case SortingAnswer(:final forms))
      if ([
            for (final (o, _) in forms)
              cube.cell(
                cube.ctx.pool.singleWhere((w) => w.id == o.lexemeId),
                o.formKey,
              ),
          ]
          case final group
          when group.every(cube.practised) && group.contains(target))
        for (final lookAlikes in sets)
          if (lookAlikes.contains(bundle) &&
              group.every((c) => lookAlikes.contains(c.bundle)))
            Slice(target, group: group, lookAlikes: lookAlikes),
  ],
  AxisPath(:final axes, :final lengths) => [
    if (target.bundle == bundle)
      for (final n in lengths)
        for (final path in _routes(cube, target, n, axes, null))
          Slice(target, path: path),
  ],
};

/// Up to [OddOneOut.maxDraws] groups: a cell of [bundle], cells of [bundle]
/// that share one of its axis values, and a cell that differs from it on that
/// axis only.
Iterable<Slice> _oddOneOut(
  OddOneOut select,
  Cube cube,
  PracticeItem word,
  GrammarBundle bundle,
  Random rng,
) sync* {
  final inBundle = cube.cellsOf(word, bundle: bundle).toList();
  if (inBundle.length < select.majority) return;
  final reachable = cube.cellsOf(word).where(cube.unlocked).toList();
  for (var draw = 0; draw < select.maxDraws; draw++) {
    final m0 = inBundle[rng.nextInt(inBundle.length)];
    final axes = m0.features.keys.toList();
    final axis = axes[rng.nextInt(axes.length)];
    final sharing = [
      for (final c in inBundle)
        if (c != m0 && c.features[axis] == m0.features[axis]) c,
    ];
    final odds = [
      for (final c in reachable)
        if (distance(m0, c) == 1 && c.features[axis] != m0.features[axis]) c,
    ];
    if (sharing.length < select.majority - 1 || odds.isEmpty) continue;
    final majority = [m0, ...(sharing..shuffle(rng)).take(select.majority - 1)];
    final odd = odds[rng.nextInt(odds.length)];
    final group = [...majority, odd];
    if (_aloneOnlyOdd(group, odd)) yield Slice(odd, group: group);
  }
}

/// For each set of [select] that holds [bundle] and is unlocked, one group:
/// cells of [word] and up to [LookAlikes.words] - 1 other words of the pool,
/// taken from the bundles of the set in turn, the first a cell of [word] in
/// [bundle].
Iterable<Slice> _lookAlikes(
  LookAlikes select,
  Cube cube,
  PracticeItem word,
  GrammarBundle bundle,
  Random rng,
) sync* {
  final targets = cube.cellsOf(word, bundle: bundle).toList()..shuffle(rng);
  final others = [
    for (final w in cube.ctx.pool)
      if (w.id != word.id) w,
  ]..shuffle(rng);
  final words = [word, ...others.take(select.words - 1)];
  final sets = [
    for (final s in select.sets)
      if (s.contains(bundle) && s.every(cube.ctx.unlocked.contains)) s,
  ]..shuffle(rng);
  for (final lookAlikes in sets) {
    final n =
        select.count.min + rng.nextInt(select.count.max - select.count.min + 1);
    final picked = <FormCell>[];
    bool fits(FormCell c) =>
        !_readsAsOther(cube, c, lookAlikes) &&
        !picked.any((p) => _alike(cube, View.latin, p, c));
    final target = targets.where(fits).firstOrNull;
    if (target == null) continue;
    picked.add(target);
    final queues = [
      for (final b in lookAlikes)
        [for (final w in words) ...cube.cellsOf(w, bundle: b)]..shuffle(rng),
    ];
    var added = true;
    while (picked.length < n && added) {
      added = false;
      for (final queue in queues) {
        if (picked.length == n) break;
        while (queue.isNotEmpty) {
          final c = queue.removeLast();
          if (fits(c)) {
            picked.add(c);
            added = true;
            break;
          }
        }
      }
    }
    if (picked.length < select.count.min ||
        lookAlikes.any((b) => picked.where((c) => c.bundle == b).length < 2)) {
      continue;
    }
    picked.shuffle(rng);
    final first = picked.firstWhere(
      (c) => c.word == word && c.bundle == bundle,
    );
    yield Slice(first, group: picked, lookAlikes: lookAlikes);
  }
}

/// Whether [c] reads like a cell of its word in another bundle of
/// [lookAlikes], so it would belong to two groups.
bool _readsAsOther(Cube cube, FormCell c, List<GrammarBundle> lookAlikes) =>
    cube
        .allCellsOf(c.word)
        .any(
          (o) =>
              o.bundle != c.bundle &&
              lookAlikes.contains(o.bundle) &&
              _alike(cube, View.latin, c, o),
        );

const _bundleAxes = ['modus', 'tempus', 'genus_verbi'];

/// The name of [c]'s bundle, e.g. "Indikativ Futur I Aktiv".
String _bundleName(FormCell c) {
  final name = [
    for (final axis in _bundleAxes) c.word.formLabels[c.index].display(axis),
  ].nonNulls.join(' ');
  assert(name.isNotEmpty, '${c.bundle} has no name');
  return name;
}

/// The param that shows the spoiled text.
String _spoiledParam(KindSpec spec) => spec.params.entries
    .singleWhere(
      (e) => switch (e.value) {
        Show(of: Ref.spoiled) => true,
        _ => false,
      },
    )
    .key;

/// The texts [ways] build for [target]; none is a form of its word.
Iterable<BuiltWrong> _spoilings(
  Cube cube,
  FormCell target,
  Set<SpoilWay> ways,
) => [
  for (final way in ways)
    ...switch (way) {
      SpoilWay.compoundSwap => cube.compoundSwaps(target),
      SpoilWay.otherTypeEnding => cube.builtWrong(target),
    },
];

bool _isOddOneOut(
  OddOneOut select,
  Cube cube,
  List<FormCell> group,
  FormCell odd,
  GrammarBundle bundle,
) {
  final majority = group.where((c) => c != odd).toList();
  return majority.length == select.majority &&
      majority.every((c) => c.bundle == bundle) &&
      cube.unlocked(odd) &&
      majority.any((m) {
        final axes = differingAxes(m, odd);
        return axes.length == 1 &&
            majority.every(
              (c) => c.features[axes.single] == m.features[axes.single],
            );
      }) &&
      _aloneOnlyOdd(group, odd);
}

/// Whether [odd] is the only cell of [group] alone on an axis.
bool _aloneOnlyOdd(List<FormCell> group, FormCell odd) {
  final axes = {for (final c in group) ...c.features.keys};
  for (final axis in axes) {
    for (final lone in group) {
      final values = {
        for (final c in group)
          if (c != lone) c.features[axis],
      };
      if (values.length == 1 &&
          lone.features[axis] != values.single &&
          lone != odd) {
        return false;
      }
    }
  }
  return true;
}

/// The [_paths] whose start cannot be taken for [to].
Iterable<List<FormCell>> _routes(
  Cube cube,
  FormCell to,
  int steps,
  List<String> axes,
  Random? rng,
) => _paths(
  cube,
  to,
  steps,
  axes,
  rng,
).where((path) => !_alike(cube, View.latin, path.first, to));

/// The paths of [steps] axis changes into [to], start first; shuffled with
/// [rng], in cell order without.
Iterable<List<FormCell>> _paths(
  Cube cube,
  FormCell to,
  int steps,
  List<String> axes,
  Random? rng, [
  Set<String> used = const {},
]) sync* {
  if (steps == 0) {
    yield [to];
    return;
  }
  final order = [...axes];
  if (rng != null) order.shuffle(rng);
  for (final axis in order) {
    if (used.contains(axis) || !to.features.containsKey(axis)) continue;
    final froms = [
      for (final from in _changedOn(cube, to, axis))
        if (cube.practised(from) &&
            cube.unlocked(from) &&
            !cube.clash(View.latin, from, to))
          from,
    ];
    if (rng != null) froms.shuffle(rng);
    for (final from in froms) {
      for (final rest in _paths(cube, from, steps - 1, axes, rng, {
        ...used,
        axis,
      })) {
        yield [...rest, to];
      }
    }
  }
}

/// The cells of [c]'s word that differ from it on [axis] only.
Iterable<FormCell> _changedOn(Cube cube, FormCell c, String axis) => cube
    .allCellsOf(c.word)
    .where(
      (n) =>
          c.features.containsKey(axis) &&
          n.features.containsKey(axis) &&
          n.features[axis] != c.features[axis] &&
          distance(c, n) == 1,
    );

String _axisOf(FormCell from, FormCell to) => differingAxes(from, to).single;

String _changeLabel(FormCell from, FormCell to) =>
    to.word.formLabels.first.axes.displayOf(_axisOf(from, to), to.features);

Cell _ref(Slice slice, Ref ref) => switch (ref) {
  Ref.target => slice.target,
  Ref.start => slice.path.first,
  Ref.spoiled => slice.spoiled!,
};

String? _uncovered(KindSpec spec, Slice slice, Cube cube) {
  for (final param in spec.params.values) {
    if (param case Show(:final of, :final view)) {
      final cell = _ref(slice, of);
      if (!cube.view(view).covers(cell)) return '$view does not cover $cell';
    }
  }
  final view = switch (spec.answer) {
    Choose(:final view) || Typed(:final view) || Sort(:final view) => view,
    Match() => null,
  };
  return view == null || cube.view(view).covers(slice.target)
      ? null
      : '$view does not cover ${slice.target}';
}

Map<String, String> _paramsOf(KindSpec spec, Slice slice, Cube cube) => {
  for (final MapEntry(:key, :value) in spec.params.entries)
    key: switch (value) {
      Show(:final of, :final view) =>
        cube.view(view).accepted(_ref(slice, of)).first,
      AxisChanges() => [
        for (var i = 1; i < slice.path.length; i++)
          _changeLabel(slice.path[i - 1], slice.path[i]),
      ].join(' → '),
      BundleName() => _bundleName(slice.target),
    },
};

/// Whether [c] would also be right: it clashes with the target in every view
/// the prompt shows the target in.
bool _fitsPrompt(KindSpec spec, Slice slice, Cell c, Cube cube) {
  final views = [
    for (final param in spec.params.values)
      if (param case Show(of: Ref.target, :final view)) view,
  ];
  return views.isNotEmpty && views.every((v) => cube.clash(v, slice.target, c));
}

/// Whether [c] may stand next to the target as a wrong option of [choose].
bool _wrongOption(
  KindSpec spec,
  Choose choose,
  Slice slice,
  Cell c,
  Cube cube,
) {
  final view = cube.view(choose.view);
  return view.covers(c) &&
      view.styleOf(c) == view.styleOf(slice.target) &&
      !_fitsPrompt(spec, slice, c, cube);
}

ExerciseAnswer? _answerOf(KindSpec spec, Slice slice, Cube cube, Random rng) =>
    switch (spec.answer) {
      final Choose choose => _choose(spec, choose, slice, cube, rng),
      Typed(:final view) => TypedAnswer(
        optionOf(slice.target, view, cube),
        _accepted(spec, view, slice, cube),
      ),
      final Match match => _match(spec, match, slice, cube),
      final Sort sort => _sort(sort, slice, cube),
    };

/// The groups of [slice]'s set, the target's first with [Sort.tick], and
/// each cell of the group with its group.
SortingAnswer _sort(Sort sort, Slice slice, Cube cube) {
  final asked = slice.target.bundle;
  final bundles = sort.tick
      ? [asked, ...slice.lookAlikes.where((b) => b != asked)]
      : slice.lookAlikes;
  String name(GrammarBundle b) =>
      _bundleName(slice.group.firstWhere((c) => c.bundle == b));
  return SortingAnswer(
    sort.tick
        ? [name(asked), bundles.skip(1).map(name).join(' / ')]
        : bundles.map(name).toList(),
    [
      for (final c in slice.group)
        (
          optionOf(c, sort.view, cube),
          sort.tick ? (c.bundle == asked ? 0 : 1) : bundles.indexOf(c.bundle),
        ),
    ],
    tick: sort.tick,
  );
}

/// The first [Sample.n] covered cells of the group that nobody can take for
/// another in either view.
MatchingAnswer? _match(KindSpec spec, Match match, Slice slice, Cube cube) {
  final n = (spec.select as Sample).n;
  final picked = <FormCell>[];
  for (final c in slice.group) {
    if (picked.length == n) break;
    if (!cube.view(match.left).covers(c) || !cube.view(match.right).covers(c)) {
      continue;
    }
    if (picked.any((p) => _clashes(match, p, c, cube))) continue;
    picked.add(c);
  }
  if (picked.length < n) return null;
  return MatchingAnswer([
    for (final c in picked)
      (optionOf(c, match.left, cube), optionOf(c, match.right, cube)),
  ]);
}

bool _clashes(Match match, Cell a, Cell b, Cube cube) =>
    _alike(cube, match.left, a, b) || cube.clash(match.right, a, b);

/// Whether [a] and [b] clash in [view]; Latin texts that differ only in
/// macrons clash too while the context avoids macron twins.
bool _alike(Cube cube, View view, Cell a, Cell b) =>
    view == View.latin && cube.ctx.avoidMacronTwins
    ? cube.lookAlike(a, b)
    : cube.clash(view, a, b);

ChoiceAnswer? _choose(
  KindSpec spec,
  Choose choose,
  Slice slice,
  Cube cube,
  Random rng,
) {
  final candidates = switch (choose.from) {
    Neighbours(:final k, :final withBuiltWrong) => <Cell>[
      ...cube.neighbours(slice.target, k: k),
      if (withBuiltWrong) ...cube.builtWrong(slice.target),
    ]..shuffle(rng),
    TheSelection() => [
      for (final c in slice.group)
        if (c != slice.target) c,
    ],
  };
  final picked = <Cell>[slice.target];
  for (final c in candidates) {
    if (picked.length == choose.count) break;
    if (!_wrongOption(spec, choose, slice, c, cube)) continue;
    if (picked.any((p) => cube.clash(choose.view, p, c))) continue;
    picked.add(c);
  }
  if (picked.length < choose.count) return null;
  picked.shuffle(rng);
  final options = [for (final c in picked) optionOf(c, choose.view, cube)];
  return ChoiceAnswer(options, options[picked.indexOf(slice.target)]);
}

/// The [view] texts of every cell the prompt can name, the target's first.
List<String> _accepted(KindSpec spec, View view, Slice slice, Cube cube) {
  final readings = _readings(spec, slice, cube);
  assert(readings.contains(slice.target), '$slice does not name its target');
  return {
    ...cube.view(view).accepted(slice.target),
    for (final c in readings) ...cube.view(view).accepted(c),
  }.toList();
}

/// The cells of the word that the prompt of [slice] can name.
Set<FormCell> _readings(KindSpec spec, Slice slice, Cube cube) {
  final word = slice.target.word;
  switch (spec.select) {
    case OneCell() || Spoil():
      return {
        for (final c in cube.allCellsOf(word))
          if (spec.params.values.every(
            (p) =>
                p is! Show ||
                p.of != Ref.target ||
                cube.fits(p.view, slice.target, c),
          ))
            c,
      };
    case AxisPath():
      var cells = {
        for (final c in cube.allCellsOf(word))
          if (cube.fits(View.latin, slice.path.first, c)) c,
      };
      for (var i = 1; i < slice.path.length; i++) {
        final axis = _axisOf(slice.path[i - 1], slice.path[i]);
        final label = _changeLabel(slice.path[i - 1], slice.path[i]);
        cells = {
          for (final from in cells)
            for (final to in _changedOn(cube, from, axis))
              if (_changeLabel(from, to) == label) to,
        };
      }
      return cells;
    case OddOneOut():
      throw ArgumentError('an odd one out has no typed answer');
    case Sample():
      throw ArgumentError('a sample has no typed answer');
    case LookAlikes():
      throw ArgumentError('look-alikes have no typed answer');
  }
}

/// Why [answer] is no answer [spec] gives for [slice]; null when it is one.
String? _answerObjection(
  KindSpec spec,
  Slice slice,
  Cube cube,
  ExerciseAnswer answer,
) {
  switch ((spec.answer, answer)) {
    case (Typed(:final view), TypedAnswer(:final expected, :final accepted)):
      final shown = optionOf(slice.target, view, cube);
      if (expected.text != shown.text) return 'expected ${expected.text}';
      final ours = _accepted(spec, view, slice, cube).toSet();
      final extra = accepted.where((t) => !ours.contains(t));
      return extra.isEmpty ? null : 'accepts $extra beyond $ours';
    case (final Choose choose, ChoiceAnswer(:final options, :final right)):
      if (options.length != choose.count) return '${options.length} options';
      final cells = [
        for (final o in options)
          o.builtWrongBy == null
              ? cube.cellOf(o, slice.target.word)
              : BuiltWrong(
                  slice.target.word,
                  o.formKey,
                  o.text,
                  o.builtWrongBy!,
                ),
      ];
      if (cells[options.indexOf(right)] != slice.target) {
        return 'right is ${right.text}';
      }
      for (final (i, c) in cells.indexed) {
        if (options[i].text != optionOf(c, choose.view, cube).text) {
          return '${options[i].text} does not show $c';
        }
        if (c == slice.target) continue;
        final fromSource = switch ((choose.from, c)) {
          (Neighbours(:final k), final FormCell f) =>
            cube.neighbours(slice.target, k: k).contains(f),
          (Neighbours(:final withBuiltWrong), final BuiltWrong b) =>
            withBuiltWrong &&
                cube.builtWrong(slice.target).any((w) => w.text == b.text),
          (TheSelection(), final FormCell f) => slice.group.contains(f),
          (TheSelection(), BuiltWrong()) => false,
        };
        if (!fromSource) return '$c is no option source cell';
        if (!_wrongOption(spec, choose, slice, c, cube)) {
          return '$c is no wrong option';
        }
        for (final other in cells.take(i)) {
          if (cube.clash(choose.view, other, c)) {
            return '$other clashes with $c';
          }
        }
      }
      return null;
    case (Match match, MatchingAnswer(:final pairs)):
      final n = (spec.select as Sample).n;
      if (pairs.length != n) return '${pairs.length} pairs';
      final cells = <FormCell>[];
      String? unshown;
      for (final (l, r) in pairs) {
        final c = cube.cellOf(l, slice.target.word);
        if (r.formKey != l.formKey) return '${l.text} and ${r.text} differ';
        if (!slice.group.contains(c)) return '$c is not in the sample';
        if (!cube.view(match.left).covers(c) ||
            !cube.view(match.right).covers(c)) {
          return '$c is not covered';
        }
        if (cells.any((p) => _clashes(match, p, c, cube))) {
          return '$c clashes with a pair';
        }
        if (l.text != optionOf(c, match.left, cube).text ||
            r.text != optionOf(c, match.right, cube).text) {
          unshown ??= '${l.text} or ${r.text} does not show $c';
        }
        cells.add(c);
      }
      return unshown;
    case (final Sort sort, SortingAnswer(:final groups, :final forms)):
      final select = spec.select as LookAlikes;
      final ours = _sort(sort, slice, cube);
      if (!listEquals(groups, ours.groups)) return 'groups $groups';
      if (forms.length < select.count.min || forms.length > select.count.max) {
        return '${forms.length} forms';
      }
      if ({for (final c in slice.group) c.word.id}.length > select.words) {
        return 'too many words';
      }
      for (final (i, c) in slice.group.indexed) {
        if (forms[i].$1.text != ours.forms[i].$1.text ||
            forms[i].$2 != ours.forms[i].$2) {
          return '${forms[i].$1.text} is not in its group';
        }
        if (!cube.unlocked(c)) return '$c is locked';
        if (_readsAsOther(cube, c, slice.lookAlikes)) {
          return '$c reads like another group';
        }
        for (final other in slice.group.take(i)) {
          if (_alike(cube, View.latin, other, c)) {
            return '$other clashes with $c';
          }
        }
      }
      return null;
    default:
      return 'answer is a ${answer.runtimeType}';
  }
}
