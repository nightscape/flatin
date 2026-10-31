/// Nodes that unlock once every node they require is built.
final class UnlockGraph<K> {
  /// Each node with the nodes it requires; the key order is the node order.
  /// Throws [UnknownRequirement] or [RequirementCycle].
  UnlockGraph(Map<K, List<K>> requires)
    : _requires = Map.unmodifiable(requires) {
    for (final MapEntry(key: node, value: ids) in _requires.entries) {
      for (final id in ids) {
        if (!_requires.containsKey(id)) throw UnknownRequirement(node, id);
      }
    }
    _failOnCycle();
  }

  final Map<K, List<K>> _requires;

  /// The requirements of [node] not in [built], in requires order.
  List<K> missing(Set<K> built, K node) => [
    for (final id in _requires[node]!)
      if (!built.contains(id)) id,
  ];

  /// The nodes not in [built] with nothing missing, in node order. [built]
  /// may hold nodes whose requirements are missing.
  List<K> available(Set<K> built) => [
    for (final MapEntry(key: node, value: ids) in _requires.entries)
      if (!built.contains(node) && ids.every(built.contains)) node,
  ];

  void _failOnCycle() {
    final done = <K>{};
    final path = <K>[];
    void visit(K node) {
      if (done.contains(node)) return;
      final at = path.indexOf(node);
      if (at >= 0) throw RequirementCycle(path.sublist(at));
      path.add(node);
      _requires[node]!.forEach(visit);
      path.removeLast();
      done.add(node);
    }

    _requires.keys.forEach(visit);
  }
}

final class UnknownRequirement<K> implements Exception {
  const UnknownRequirement(this.node, this.id);

  final K node;
  final K id;

  @override
  String toString() => '$node requires unknown $id';
}

/// Each of [nodes] requires the next one, and the last requires the first.
final class RequirementCycle<K> implements Exception {
  const RequirementCycle(this.nodes);

  final List<K> nodes;

  @override
  String toString() => 'cycle ${[...nodes, nodes.first].join(' → ')}';
}
