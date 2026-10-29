/// Builds the exercises of a [KindSpec]: draws slices of the cube until one
/// is covered by every view the spec reads and gives an answer under the
/// clash rule.
library;

import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals, mapEquals;

import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';
import 'exercise_choice.dart' show knowsWell;
import 'exercise_cube.dart';
import 'exercise_spec.dart';

/// The cells one exercise is about.
final class Slice {
  final FormCell target;

  /// [AxisPath]: start … target.
  final List<FormCell> path;

  /// [OddOneOut]: the majority and the target; [PrincipalParts]: the asked
  /// row cells.
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
  const SpecGenerator(this.spec, {this.vocab, this.agreement});

  final KindSpec spec;

  /// How the kind asks a vocab item; null when it asks none.
  final KindSpec? vocab;

  /// How the kind also asks a word of the [Match.agreeing] types; null when
  /// it has no such way.
  final KindSpec? agreement;

  @override
  ExerciseKind get kind => spec.kind;

  List<KindSpec> _specsFor(PracticeItem word) => word.isVocab
      ? [vocab ?? (throw CannotBuild('${kind.name} asks no vocab item'))]
      : [spec, ?agreement].where((s) => _asks(s, word)).toList();

  static bool _asks(KindSpec spec, PracticeItem word) => switch (spec.answer) {
    Match(:final agreeing) when agreeing.isNotEmpty => agreeing.contains(
      word.type,
    ),
    _ => true,
  };

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    if (!ctx.unlocked.contains(bundle)) throw CannotBuild('$bundle is locked');
    final cube = Cube(ctx);
    final reasons = <String>{};
    for (final spec in _specsFor(word)..shuffle(rng)) {
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
    final spec = _specsFor(
      word,
    ).where((s) => s.questionKey == exercise.questionKey).firstOrNull;
    if (spec == null ||
        exercise.kind != spec.kind ||
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
      PartsAnswer(:final prompt) => prompt.formKey,
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
  PrincipalParts() => _principalParts(select, cube, word, bundle, rng),
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
  PrincipalParts select => _principalParts(
    select,
    cube,
    target.word,
    bundle,
    null,
    into: target,
  ).where((slice) => slice.target == target),
  AxisPath(:final axes, :final lengths) => [
    if (target.bundle == bundle)
      for (final n in lengths)
        for (final path in _routes(cube, target, n, axes, null))
          Slice(target, path: path),
  ],
};

/// The slices of [select] for [word] in [bundle]: the prompt is the target,
/// the asked parts are the group; shuffled with [rng], in cell order without,
/// only those whose prompt is [into] when given.
Iterable<Slice> _principalParts(
  PrincipalParts select,
  Cube cube,
  PracticeItem word,
  GrammarBundle bundle,
  Random? rng, {
  FormCell? into,
}) {
  final deponent = select.row.any(
    (p) => word.derivation.deponentKeys.contains(p.key),
  );
  final row = [
    for (final (:key, name: _) in select.row)
      if (word.formOrder.contains(key) && !(deponent && key == select.supine))
        cube.cell(word, key),
  ].where(cube.practised).toList();
  if (!row.any((c) => c.bundle == bundle) ||
      {for (final c in row) norm(c.word.forms[c.index])}.length <
          select.minParts) {
    return const [];
  }
  if (!knowsWell([
    cube.ctx.stabilityOf(word.id),
    for (final c in row) cube.ctx.stabilityOf(GrammarCardId.of(word, c.key)),
  ])) {
    final given = row.first;
    final asked = row.skip(1).toList();
    return [
      if (given.key == select.row.first.key &&
          asked.any((c) => c.bundle == bundle) &&
          !asked.any((c) => cube.lookAlike(c, given)))
        Slice(given, group: asked),
    ];
  }
  final prompts = [
    for (final c in cube.cellsOf(word))
      if (select.promptsFrom.any(c.key.startsWith) && (into ?? c) == c) c,
  ];
  if (rng != null) prompts.shuffle(rng);
  final owners = _spellingOwners[cube.ctx.pool] ??= _ownersOf(cube.ctx.pool);
  String text(FormCell c) => optionOf(c, View.latin, cube).text;
  return prompts
      .where(
        (p) =>
            (owners[norm(word.forms[p.index])] ?? const {}).every(
              (id) => id == word.id,
            ) &&
            // A part spelt like the prompt is given, not asked.
            row.any((c) => c.bundle == bundle && text(c) != text(p)),
      )
      .map((p) => Slice(p, group: row));
}

/// The ids of the words of a pool that write each spelling, read without
/// macrons; kept per pool, as indexing every form of a pool is slow.
final _spellingOwners = Expando<Map<String, Set<String>>>();

Map<String, Set<String>> _ownersOf(List<PracticeItem> pool) {
  final owners = <String, Set<String>>{};
  for (final word in pool) {
    for (final spellings in word.acceptedForms) {
      for (final s in spellings) {
        (owners[norm(s)] ??= {}).add(word.id);
      }
    }
  }
  return owners;
}

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
  final (view, asked) = switch (spec.answer) {
    Choose(:final view) ||
    Typed(:final view) ||
    Sort(:final view) => (view, [slice.target]),
    Parts(:final view) => (view, slice.group),
    Match() => (null, const <FormCell>[]),
  };
  for (final c in asked) {
    if (!cube.view(view!).covers(c)) return '$view does not cover $c';
  }
  // A row is asked whole, so each of its parts must be reached.
  if (spec.answer is Parts) {
    for (final c in [slice.target, ...slice.group]) {
      if (!cube.unlocked(c)) return '$c is locked';
    }
  }
  return null;
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
      final Match match =>
        match.agreeing.isEmpty
            ? _match(spec, match, slice, cube)
            : _matchAgreeing(spec, match, slice, cube, rng),
      final Sort sort => _sort(sort, slice, cube),
      Parts(:final view) => _parts(spec, view, slice, cube),
    };

/// The prompt and one slot per part of the row, named by
/// [PrincipalParts.row]; a part spelt like the prompt is given, not asked.
PartsAnswer _parts(KindSpec spec, View view, Slice slice, Cube cube) {
  final row = (spec.select as PrincipalParts).row;
  final prompt = optionOf(slice.target, View.latin, cube);
  final slots = <({String name, TypedAnswer answer})>[];
  final given = <({int at, String name, FormOption form})>[];
  for (final (at, c) in slice.group.indexed) {
    final name = row.singleWhere((p) => p.key == c.key).name;
    final option = optionOf(c, view, cube);
    if (option.text == prompt.text) {
      given.add((at: at, name: name, form: option));
    } else {
      slots.add((
        name: name,
        answer: TypedAnswer(option, cube.view(view).accepted(c)),
      ));
    }
  }
  return PartsAnswer(prompt, slots, given: given);
}

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

/// A case, number and gender a form can have.
typedef _Kng = (String kasus, String numerus, String genus);

/// The readings of [c] itself: the genus comes from its key, or for a noun
/// from its word.
Set<_Kng> _kngOf(FormCell c) {
  final kasus = c.features['kasus'];
  final numerus = c.features['numerus'];
  if (kasus == null || numerus == null) return {};
  final genus = c.features['genus'];
  return {
    for (final g in genus == null ? c.word.genus : [genus]) (kasus, numerus, g),
  };
}

/// The readings of [c]'s spelling: those of every cell of its word that the
/// spelling fits.
Set<_Kng> _readingsOf(Cube cube, FormCell c) => {
  for (final o in cube.allCellsOf(c.word))
    if (cube.fits(View.latin, c, o)) ..._kngOf(o),
};

/// Whether the spellings of [a] and [b] agree in case, number and gender.
bool _agrees(Cube cube, FormCell a, FormCell b) =>
    _readingsOf(cube, a).intersection(_readingsOf(cube, b)).isNotEmpty;

bool _isNoun(PracticeItem w) =>
    w.genus.isNotEmpty &&
    w.derivation.grammar.classByType[w.type] == 'deklination';

/// The cases, numbers and genders that the spellings of [left] and [right]
/// share, as one label of [left]'s word.
String _agreementLabel(Cube cube, FormCell left, FormCell right) {
  final shared = _readingsOf(cube, right);
  return describeLabels([
    for (final o in cube.allCellsOf(left.word))
      if (cube.fits(View.latin, left, o) &&
          _kngOf(o).intersection(shared).isNotEmpty)
        o.word.formLabels[o.index],
  ]);
}

/// The first [Sample.n] cells of the group that agree with a practised noun
/// cell of the pool, each paired with one; no spelling of a side can be taken
/// for another, and no left spelling agrees with the right one of another
/// pair.
MatchingAnswer? _matchAgreeing(
  KindSpec spec,
  Match match,
  Slice slice,
  Cube cube,
  Random rng,
) {
  final n = (spec.select as Sample).n;
  final nouns = [
    for (final w in cube.ctx.pool)
      if (_isNoun(w))
        for (final c in cube.cellsOf(w))
          if (cube.unlocked(c)) c,
  ]..shuffle(rng);
  final readings = <FormCell, Set<_Kng>>{};
  bool agree(FormCell a, FormCell b) => readings
      .putIfAbsent(a, () => _readingsOf(cube, a))
      .intersection(readings.putIfAbsent(b, () => _readingsOf(cube, b)))
      .isNotEmpty;
  final pairs = <(FormCell, FormCell)>[];
  for (final c in slice.group) {
    if (pairs.length == n) break;
    if (_kngOf(c).isEmpty ||
        pairs.any((p) => _alike(cube, match.left, p.$1, c) || agree(c, p.$2))) {
      continue;
    }
    final partner = nouns
        .where(
          (r) =>
              _kngOf(c).intersection(_kngOf(r)).isNotEmpty &&
              !pairs.any(
                (p) => _alike(cube, match.right, p.$2, r) || agree(p.$1, r),
              ),
        )
        .firstOrNull;
    if (partner != null) pairs.add((c, partner));
  }
  if (pairs.length < n) return null;
  return MatchingAnswer(
    [
      for (final (l, r) in pairs)
        (optionOf(l, match.left, cube), optionOf(r, match.right, cube)),
    ],
    agreements: [for (final (l, r) in pairs) _agreementLabel(cube, l, r)],
  );
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
    case PrincipalParts():
      throw ArgumentError('principal parts have a typed answer per slot');
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
    case (final Match match, MatchingAnswer(:final pairs, :final agreements))
        when match.agreeing.isNotEmpty:
      return _agreementObjection(spec, match, slice, cube, pairs, agreements);
    case (
      final Parts parts,
      PartsAnswer(:final prompt, :final slots, :final given),
    ):
      final ours = _parts(spec, parts.view, slice, cube);
      if (prompt.text != ours.prompt.text) return 'prompt ${prompt.text}';
      if (!listEquals(
        [for (final g in given) (g.at, g.name, g.form.formKey, g.form.text)],
        [
          for (final g in ours.given)
            (g.at, g.name, g.form.formKey, g.form.text),
        ],
      )) {
        return 'given ${[for (final g in given) g.form.text]}';
      }
      if (slots.length != ours.slots.length) return '${slots.length} slots';
      for (final (i, slot) in slots.indexed) {
        final our = ours.slots[i];
        if (slot.name != our.name ||
            slot.answer.expected.formKey != our.answer.expected.formKey ||
            slot.answer.expected.text != our.answer.expected.text ||
            !listEquals(slot.answer.accepted, our.answer.accepted)) {
          return 'slot $i is ${slot.answer.expected.text}, '
              'not ${our.answer.expected.text}';
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

String? _agreementObjection(
  KindSpec spec,
  Match match,
  Slice slice,
  Cube cube,
  List<(FormOption, FormOption)> pairs,
  List<String>? agreements,
) {
  final word = slice.target.word;
  if (pairs.length != (spec.select as Sample).n) return '${pairs.length} pairs';
  if (agreements == null) return 'no agreement labels';
  final cells = <(FormCell, FormCell)>[];
  for (final (i, (l, r)) in pairs.indexed) {
    if (l.lexemeId != word.id) return '${l.text} is no form of ${word.id}';
    final left = cube.cellOf(l, word);
    final right = cube.cellOf(r, word);
    if (!_isNoun(right.word) ||
        !cube.practised(right) ||
        !cube.unlocked(right)) {
      return '$right is no practised noun form';
    }
    if (l.text != optionOf(left, match.left, cube).text ||
        r.text != optionOf(right, match.right, cube).text) {
      return '${l.text} or ${r.text} does not show its cell';
    }
    if (_kngOf(left).intersection(_kngOf(right)).isEmpty) {
      return '$left and $right do not agree';
    }
    if (agreements[i] != _agreementLabel(cube, left, right)) {
      return 'label ${agreements[i]} of $left and $right';
    }
    for (final (pl, pr) in cells) {
      if (_alike(cube, match.left, pl, left) ||
          _alike(cube, match.right, pr, right)) {
        return '$left or $right clashes with a pair';
      }
      if (_agrees(cube, pl, right) || _agrees(cube, left, pr)) {
        return '$left or $right agrees with another pair';
      }
    }
    cells.add((left, right));
  }
  return null;
}
