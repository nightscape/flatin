import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/unlock_graph.dart';

const _cases = 1000;

/// A random DAG that knows its answers: every node requires only nodes before
/// it in the hidden topological order [topo]; the key order of [requires] is
/// an independent shuffle.
final class _Dag {
  _Dag(this.seed) : random = Random(seed) {
    final n = random.nextInt(16);
    final names = [for (var i = 0; i < n; i++) 'n$i'];
    topo = [...names]..shuffle(random);
    final density = switch (random.nextInt(10)) {
      0 || 1 => 0.0,
      2 || 3 => 0.8,
      _ => 0.2,
    };
    final byNode = {
      for (final (i, node) in topo.indexed)
        node: [
          for (final before in topo.take(i))
            if (random.nextDouble() < density) before,
        ]..shuffle(random),
    };
    requires = {
      for (final node in [...names]..shuffle(random)) node: byNode[node]!,
    };
  }

  final int seed;
  final Random random;
  late final List<String> topo;
  late final Map<String, List<String>> requires;

  List<String> get nodes => requires.keys.toList();

  int get edges => requires.values.fold(0, (s, r) => s + r.length);

  /// [node] and every node it requires, directly or not.
  Set<String> closure(String node) => {
    node,
    for (final r in requires[node]!) ...closure(r),
  };

  /// A random subset of the nodes, often one that breaks the requires.
  Set<String> someBuilt() => {
    for (final node in nodes)
      if (random.nextBool()) node,
  };

  String pick(List<String> from) => from[random.nextInt(from.length)];

  @override
  String toString() => 'seed $seed, topo $topo, requires $requires';
}

/// The graph of [_Dag] [seed] and the DAG; fails the test naming both if the
/// constructor throws.
(_Dag, UnlockGraph<String>) _built(int seed) {
  final dag = _Dag(seed);
  try {
    return (dag, UnlockGraph(dag.requires));
  } catch (e) {
    fail('$dag: $e');
  }
}

void main() {
  test('the generator makes empty, dense and shuffled graphs', () {
    var empty = 0, dense = 0, shuffled = 0, large = 0;
    for (var seed = 0; seed < _cases; seed++) {
      final dag = _Dag(seed);
      final n = dag.nodes.length;
      if (n >= 3 && dag.edges == 0) empty++;
      if (n >= 4 && dag.edges * 2 >= n * (n - 1) / 2) dense++;
      final at = {for (final (i, node) in dag.nodes.indexed) node: i};
      if (dag.requires.entries.any(
        (e) => e.value.any((r) => at[r]! > at[e.key]!),
      )) {
        shuffled++;
      }
      if (n >= 12) large++;
    }
    expect(empty, greaterThan(0));
    expect(dense, greaterThan(0));
    expect(shuffled, greaterThan(0));
    expect(large, greaterThan(0));
  });

  test('accepts every DAG', () {
    for (var seed = 0; seed < _cases; seed++) {
      _built(seed);
    }
  });

  test('rejects an added edge that closes a cycle, naming the nodes on it', () {
    var self = 0, longer = 0;
    for (var seed = 0; seed < _cases; seed++) {
      final dag = _Dag(seed);
      if (dag.nodes.isEmpty) continue;
      final to = dag.pick(dag.nodes);
      final above = (dag.closure(to)..remove(to)).toList();
      final from = above.isEmpty || dag.random.nextInt(4) == 0
          ? to
          : dag.pick(above);
      final edited = {
        for (final MapEntry(:key, :value) in dag.requires.entries)
          key: [...value, if (key == from) to],
      };
      from == to ? self++ : longer++;
      final reason = '$dag, added $from -> $to';
      try {
        UnlockGraph(edited);
        fail('accepted: $reason');
      } on RequirementCycle<String> catch (e) {
        final cycle = e.nodes;
        expect(cycle, isNotEmpty, reason: reason);
        expect(cycle.toSet().length, cycle.length, reason: '$reason: $cycle');
        for (final (i, node) in cycle.indexed) {
          expect(
            edited[node],
            contains(cycle[(i + 1) % cycle.length]),
            reason: '$reason: $cycle',
          );
        }
      }
    }
    expect(self + longer, greaterThan(_cases / 2));
    expect(self, greaterThan(_cases / 10));
    expect(longer, greaterThan(_cases / 4));
  });

  test('rejects an unknown requirement, naming the node and the id', () {
    var checked = 0;
    for (var seed = 0; seed < _cases; seed++) {
      final dag = _Dag(seed);
      if (dag.nodes.isEmpty) continue;
      final node = dag.pick(dag.nodes);
      final requires = dag.requires[node]!;
      final edited = {
        ...dag.requires,
        node: [...requires]
          ..insert(dag.random.nextInt(requires.length + 1), 'unknown'),
      };
      expect(
        () => UnlockGraph(edited),
        throwsA(
          isA<UnknownRequirement<String>>()
              .having((e) => e.node, 'node', node)
              .having((e) => e.id, 'id', 'unknown'),
        ),
        reason: '$dag, $node requires unknown',
      );
      checked++;
    }
    expect(checked, greaterThan(_cases / 2));
  });

  test('missing is the requires not built, in requires order', () {
    for (var seed = 0; seed < _cases; seed++) {
      final (dag, graph) = _built(seed);
      final built = dag.someBuilt();
      for (final node in dag.nodes) {
        expect(graph.missing(built, node), [
          for (final r in dag.requires[node]!)
            if (!built.contains(r)) r,
        ], reason: '$dag, built $built, node $node');
      }
    }
  });

  test('building from an empty town reaches every node', () {
    for (var seed = 0; seed < _cases; seed++) {
      final (dag, graph) = _built(seed);
      final built = <String>{};
      for (
        var open = graph.available(built);
        open.isNotEmpty;
        open = graph.available(built)
      ) {
        final next = dag.pick(open);
        expect(built, isNot(contains(next)), reason: '$dag, built $built');
        expect(
          built,
          containsAll(dag.requires[next]!),
          reason: '$dag, next $next',
        );
        built.add(next);
      }
      expect(built, dag.nodes.toSet(), reason: '$dag');
      for (final (i, node) in dag.topo.indexed) {
        expect(
          graph.available(dag.topo.take(i).toSet()),
          contains(node),
          reason: '$dag, topo step $i',
        );
      }
    }
  });

  test('in an empty town exactly the nodes without requires are available', () {
    for (var seed = 0; seed < _cases; seed++) {
      final (dag, graph) = _built(seed);
      expect(graph.available({}), [
        for (final node in dag.nodes)
          if (dag.requires[node]!.isEmpty) node,
      ], reason: '$dag');
    }
  });

  test('building a node never makes another node unavailable', () {
    var checked = 0;
    for (var seed = 0; seed < _cases; seed++) {
      final (dag, graph) = _built(seed);
      final built = dag.someBuilt();
      final unbuilt = [
        for (final n in dag.nodes)
          if (!built.contains(n)) n,
      ];
      if (unbuilt.isEmpty) continue;
      final added = dag.pick(unbuilt);
      final after = graph.available({...built, added});
      for (final node in graph.available(built)) {
        if (node == added) continue;
        expect(
          after,
          contains(node),
          reason: '$dag, built $built, added $added',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(_cases / 2));
  });

  test('a built node with missing requires stays built and unlocks others', () {
    var saves = 0, unlocked = 0;
    for (var seed = 0; seed < _cases; seed++) {
      final (dag, graph) = _built(seed);
      final withRequires = [
        for (final n in dag.nodes)
          if (dag.requires[n]!.isNotEmpty) n,
      ];
      if (withRequires.isEmpty) continue;
      final broken = dag.pick(withRequires);
      final built = {...dag.someBuilt(), broken}
        ..remove(dag.pick(dag.requires[broken]!));
      final available = graph.available(built);
      final reason = '$dag, built $built, broken $broken';
      expect(available, isNot(contains(broken)), reason: reason);
      expect(graph.missing(built, broken), isNotEmpty, reason: reason);
      for (final node in dag.nodes) {
        if (!built.contains(node) &&
            dag.requires[node]!.contains(broken) &&
            dag.requires[node]!.every(built.contains)) {
          expect(available, contains(node), reason: '$reason, node $node');
          unlocked++;
        }
      }
      saves++;
    }
    expect(saves, greaterThan(_cases / 2));
    expect(unlocked, greaterThan(0));
  });
}
