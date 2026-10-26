import 'package:yaml/yaml.dart';

import '../models/reward.dart';
import 'asset_text.dart';

const String gameRulesAsset = 'lib/data/game_rules.yaml';

Future<GameRules> loadGameRules() async =>
    GameRules.parse(await loadAssetText(gameRulesAsset), gameRulesAsset);

/// Gains [gain] per resource, times the fact [per], for an event named [on]
/// whose facts satisfy every entry of [when]: a key `<field>AtLeast` needs a
/// number of at least the value, a list any of its values, else the value.
final class EarnRule {
  final String on;
  final Map<String, Object> when;
  final Map<String, int> gain;
  final String? per;
  final String? tag;

  const EarnRule({
    required this.on,
    required this.when,
    required this.gain,
    this.per,
    this.tag,
  });

  bool matches(Map<String, Object?> facts) => when.entries.every((c) {
    if (c.key.endsWith(_atLeast)) {
      final value = facts[_field(c.key)] as num?;
      return value != null && value >= (c.value as num);
    }
    final value = facts[c.key];
    return c.value is List
        ? (c.value as List).contains(value)
        : value == c.value;
  });
}

/// Changes every later gain of [resource] while its building stands.
final class Modifier {
  final String resource;
  final int add;
  final num multiply;

  const Modifier(this.resource, {this.add = 0, this.multiply = 1});
}

final class Building {
  final String id;
  final Map<String, int> price;
  final List<Modifier> modifies;

  const Building(this.id, this.price, [this.modifies = const []]);
}

final class GameRules {
  final List<String> resources;
  final List<EarnRule> earn;

  /// In shop order.
  final List<Building> buildings;

  const GameRules({
    required this.resources,
    required this.earn,
    required this.buildings,
  });

  /// Throws a [FormatException] naming [file] and the path of the first entry
  /// that is not part of the schema.
  factory GameRules.parse(String source, String file) =>
      _Reader(file).rules(loadYaml(source));

  /// The gains of [event]. The order is fixed: per resource, the gains of
  /// all matching rules add up; then the modifiers of the built buildings for
  /// that resource apply, every `add` before every `multiply`; then the sum is
  /// rounded. A tag's share of it is the tag's gains times the multiplies,
  /// rounded; the rest is untagged.
  List<ResourceGained> gainsOf(RewardLedger ledger, RewardEvent event) {
    final name = rewardEventName(event);
    final facts = event.facts;
    final sums = <String, Map<String?, int>>{};
    for (final rule in earn) {
      if (rule.on != name || !rule.matches(facts)) continue;
      final times = rule.per == null ? 1 : facts[rule.per] as int;
      for (final g in rule.gain.entries) {
        sums
            .putIfAbsent(g.key, () => {})
            .update(
              rule.tag,
              (sum) => sum + g.value * times,
              ifAbsent: () => g.value * times,
            );
      }
    }
    final built = [
      for (final b in buildings)
        if (ledger.buildings.contains(b.id)) ...b.modifies,
    ];
    return [
      for (final MapEntry(key: resource, value: byTag) in sums.entries)
        ..._shares(resource, byTag, [
          for (final m in built)
            if (m.resource == resource) m,
        ]),
    ];
  }

  static List<ResourceGained> _shares(
    String resource,
    Map<String?, int> byTag,
    List<Modifier> modifiers,
  ) {
    final add = modifiers.fold(0, (sum, m) => sum + m.add);
    final num multiply = modifiers.fold<num>(1, (p, m) => p * m.multiply);
    final int total = ((byTag.values.reduce((a, b) => a + b) + add) * multiply)
        .round();
    final tagged = <String, int>{
      for (final MapEntry(:key, :value) in byTag.entries)
        ?key: (value * multiply).round(),
    };
    final int rest = total - tagged.values.fold(0, (a, b) => a + b);
    return [
      if (rest > 0) ResourceGained(resource, rest),
      for (final MapEntry(key: tag, value: amount) in tagged.entries)
        if (amount > 0) ResourceGained(resource, amount, tag: tag),
    ];
  }

  List<RewardEffect> buy(Building building) => [
    for (final p in building.price.entries) ResourceSpent(p.key, p.value),
    BuildingAdded(building.id),
  ];

  /// The buildings the shop offers.
  List<Building> unbuilt(RewardLedger ledger) => [
    for (final b in buildings)
      if (!ledger.buildings.contains(b.id)) b,
  ];
}

const String _atLeast = 'AtLeast';

String _field(String key) => key.substring(0, key.length - _atLeast.length);

final class _Reader {
  _Reader(this.file);

  final String file;
  late final List<String> _resources;

  Never _fail(String path, String message) =>
      throw FormatException('$file: $path: $message');

  T _as<T>(Object? value, String path) =>
      value is T ? value : _fail(path, 'expected $T, got $value');

  YamlMap _map(
    Object? value,
    String path, {
    Set<String> required = const {},
    Set<String> optional = const {},
  }) {
    final map = _as<YamlMap>(value, path);
    for (final key in map.keys) {
      if (!required.contains(key) && !optional.contains(key)) {
        _fail('$path.$key', 'unknown key');
      }
    }
    for (final key in required) {
      if (!map.containsKey(key)) _fail('$path.$key', 'missing');
    }
    return map;
  }

  List<Object?> _list(Object? value, String path) => _as<YamlList>(value, path);

  String _resource(Object? value, String path) {
    final name = _as<String>(value, path);
    return _resources.contains(name) ? name : _fail(path, 'unknown resource');
  }

  Map<String, int> _amounts(Object? value, String path) => {
    for (final e in _as<YamlMap>(value, path).entries)
      _resource(e.key, '$path.${e.key}'): _positive(e.value, '$path.${e.key}'),
  };

  int _positive(Object? value, String path) {
    final n = _as<int>(value, path);
    return n > 0 ? n : _fail(path, 'must be positive');
  }

  GameRules rules(Object? doc) {
    final top = _map(doc, r'$', required: {'resources', 'earn', 'buildings'});
    _resources = [
      for (final (i, r) in _list(top['resources'], 'resources').indexed)
        _as<String>(r, 'resources[$i]'),
    ];
    final buildings = [
      for (final (i, b) in _list(top['buildings'], 'buildings').indexed)
        _building(b, 'buildings[$i]'),
    ];
    final ids = <String>{};
    for (final (i, b) in buildings.indexed) {
      if (!ids.add(b.id)) _fail('buildings[$i].id', 'duplicate ${b.id}');
    }
    final earn = [
      for (final (i, r) in _list(top['earn'], 'earn').indexed)
        _rule(r, 'earn[$i]'),
    ];
    // One tag per resource: tag shares rounded separately could exceed the
    // rounded total.
    final tags = <String, String>{};
    for (final (i, r) in earn.indexed) {
      for (final resource in r.gain.keys) {
        if (r.tag case final tag?
            when tags.putIfAbsent(resource, () => tag) != tag) {
          _fail('earn[$i].tag', '$resource already has tag ${tags[resource]}');
        }
      }
    }
    return GameRules(resources: _resources, earn: earn, buildings: buildings);
  }

  EarnRule _rule(Object? value, String path) {
    final map = _map(
      value,
      path,
      required: {'on', 'gain'},
      optional: {'when', 'per', 'tag'},
    );
    final on = _as<String>(map['on'], '$path.on');
    final fields =
        rewardEventFields[on] ?? _fail('$path.on', 'unknown event $on');
    final per = map['per'] == null
        ? null
        : _as<String>(map['per'], '$path.per');
    if (per != null && fields[per] != int) {
      _fail('$path.per', '$on has no number field $per');
    }
    return EarnRule(
      on: on,
      when: {
        for (final c in _map(
          map['when'] ?? YamlMap(),
          '$path.when',
          optional: {
            ...fields.keys,
            for (final f in fields.entries)
              if (f.value == int || f.value == double) '${f.key}$_atLeast',
          },
        ).entries)
          c.key as String: _condition(
            c.value,
            fields[c.key] ?? num,
            '$path.when.${c.key}',
          ),
      },
      gain: _amounts(map['gain'], '$path.gain'),
      per: per,
      tag: map['tag'] == null ? null : _as<String>(map['tag'], '$path.tag'),
    );
  }

  Object _condition(Object? value, Type type, String path) {
    bool fits(Object? v) => switch (type) {
      const (bool) => v is bool,
      const (int) => v is int,
      const (double) || const (num) => v is num,
      const (String) => v is String,
      _ => throw StateError('no condition for $type'),
    };
    if (value is YamlList && type != num) {
      return [
        for (final (i, v) in value.indexed)
          fits(v) ? v as Object : _fail('$path[$i]', 'expected $type, got $v'),
      ];
    }
    return fits(value) ? value! : _fail(path, 'expected $type, got $value');
  }

  Building _building(Object? value, String path) {
    final map = _map(
      value,
      path,
      required: {'id', 'price'},
      optional: {'modifies'},
    );
    return Building(
      _as<String>(map['id'], '$path.id'),
      _amounts(map['price'], '$path.price'),
      [
        for (final (i, m) in _list(
          map['modifies'] ?? YamlList(),
          '$path.modifies',
        ).indexed)
          _modifier(m, '$path.modifies[$i]'),
      ],
    );
  }

  Modifier _modifier(Object? value, String path) {
    final map = _map(
      value,
      path,
      required: {'resource'},
      optional: {'add', 'multiply'},
    );
    final resource = _resource(map['resource'], '$path.resource');
    return switch ((map['add'], map['multiply'])) {
      (final Object add, null) => Modifier(
        resource,
        add: _positive(add, '$path.add'),
      ),
      (null, final Object multiply) => Modifier(
        resource,
        multiply: _as<num>(multiply, '$path.multiply') > 0
            ? multiply as num
            : _fail('$path.multiply', 'must be positive'),
      ),
      _ => _fail(path, 'needs either add or multiply'),
    };
  }
}
