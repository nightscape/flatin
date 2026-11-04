import 'dart:math';

/// A pattern as a data file writes it: axis → the codes it accepts.
typedef RawPattern = Map<String, List<String>>;

bool rawMatches(Map<String, String> features, RawPattern pattern) =>
    pattern.entries.every((e) => e.value.contains(features[e.key]));

typedef DrawnRule = ({
  RawPattern when,
  Map<String, String> from,
  List<String> drop,
  bool endings,
  bool impersonal,
});

typedef DrawnItem = ({
  String id,
  String type,
  String stem,
  List<String>? deponent,
  bool impersonal,
  String? regularType,
  Map<String, String> overrides,
});

/// A drawn grammar file with three types, items, a `voice:` block and
/// `follows:` rules, and the facts it was drawn from. No id is a Latin one.
///
/// Every key of [keys] is a form of every type: `{s}` plus a one-letter ending
/// of its own per key and type, so a form ends in no other key's ending.
final class DrawnVerbsFile {
  final Map<String, List<String>> axes;
  final String voiceAxis, active, passive, deponentBy;
  final List<RawPattern> moves, personal;

  /// The codes of [deponentBy] the type `TD` is deponent in; null for `all`.
  final List<String>? typeDeponent;
  final List<DrawnRule> rules;
  final List<Map<String, String>> keys;
  final Map<String, Map<String, String>> endingByType;
  final List<DrawnItem> items;

  /// The file of the given facts: every key of [axes] plus, when [dropped]
  /// is not empty, every key without the [dropped] axes. The types `T` and
  /// `TD` share their endings; `T2` has endings of its own.
  factory DrawnVerbsFile.fromFacts({
    required Map<String, List<String>> axes,
    required String voiceAxis,
    required String active,
    required String passive,
    required String deponentBy,
    required List<RawPattern> moves,
    required List<RawPattern> personal,
    required List<String>? typeDeponent,
    required List<DrawnRule> rules,
    required List<String> dropped,
  }) {
    Iterable<Map<String, String>> combinations(List<String> ids) => ids.fold(
      [<String, String>{}],
      (all, id) => [
        for (final c in all)
          for (final code in axes[id]!) {...c, id: code},
      ],
    );

    final names = [...axes.keys];
    final keys = [
      ...combinations(names),
      if (dropped.isNotEmpty)
        ...combinations([...names.where((a) => !dropped.contains(a))]),
    ];
    Map<String, String> endings(int type) => {
      for (final (i, features) in keys.indexed)
        [...features.values].join('.'): String.fromCharCode(
          0x4E00 + 0x1000 * type + i,
        ),
    };
    return DrawnVerbsFile._(
      axes,
      voiceAxis,
      active,
      passive,
      deponentBy,
      moves,
      personal,
      typeDeponent,
      rules,
      keys,
      {'T': endings(0), 'TD': endings(0), 'T2': endings(1)},
      [],
    );
  }

  DrawnVerbsFile._(
    this.axes,
    this.voiceAxis,
    this.active,
    this.passive,
    this.deponentBy,
    this.moves,
    this.personal,
    this.typeDeponent,
    this.rules,
    this.keys,
    this.endingByType,
    this.items,
  );

  DrawnVerbsFile withItems(List<DrawnItem> items) => DrawnVerbsFile._(
    axes,
    voiceAxis,
    active,
    passive,
    deponentBy,
    moves,
    personal,
    typeDeponent,
    rules,
    keys,
    endingByType,
    items,
  );

  String keyOf(Map<String, String> features) =>
      [for (final axis in axes.keys) ?features[axis]].join('.');

  Map<String, dynamic> get tree {
    Map<String, String> texts(String id) => {'de': id, 'en': id};
    Map<String, dynamic> yamlOf(RawPattern p) => {
      for (final MapEntry(:key, :value) in p.entries)
        key: value.length == 1 ? value.single : value,
    };
    Map<String, String> formsOf(String type) => {
      for (final MapEntry(:key, :value) in endingByType[type]!.entries)
        key: '{s}$value',
    };
    return {
      'data_file_id': 'synthetic',
      'axes': {
        for (final MapEntry(key: id, value: codes) in axes.entries)
          id: {
            'name': texts(id),
            'values': {for (final code in codes) code: texts(code)},
          },
      },
      'label': {
        'head': <String>[],
        'tail': [...axes.keys],
        'merge_axis': axes.keys.first,
      },
      'parts': {
        'lemma': {'label': texts('lemma')},
      },
      'defaults': {'given_part': 'lemma'},
      'classes': ['wortart'],
      'voice': {
        'axis': voiceAxis,
        'active': active,
        'passive': passive,
        'deponent': {
          'by': deponentBy,
          'moves': [for (final m in moves) yamlOf(m)],
        },
        'impersonal': {
          'personal': [for (final p in personal) yamlOf(p)],
          'agrees': {deponentBy: axes[deponentBy]!.first},
        },
      },
      'follows': [
        for (final rule in rules)
          {
            'when': yamlOf(rule.when),
            'from': rule.from,
            if (rule.drop.isNotEmpty) 'drop': rule.drop,
            'by': rule.endings ? 'endings' : 'regular',
            if (rule.impersonal) 'impersonal': true,
          },
      ],
      'types': {
        'T': {
          'class': 'wortart',
          'display': texts('T'),
          'stems': {
            's': {'from': 'lemma'},
          },
          'forms': formsOf('T'),
        },
        'TD': {
          'class': 'wortart',
          'display': texts('TD'),
          'inherits_from': 'T',
          'deponent': typeDeponent ?? 'all',
        },
        'T2': {
          'class': 'wortart',
          'display': texts('T2'),
          'stems': {
            's': {'from': 'lemma'},
          },
          'forms': formsOf('T2'),
        },
      },
      'items': [
        for (final item in items)
          {
            'id': item.id,
            'type': item.type,
            'translation': texts(item.id),
            'parts': {'lemma': item.stem},
            'deponent': ?item.deponent,
            if (item.impersonal) 'passiv': 'unpersönlich',
            'regular_type': ?item.regularType,
            if (item.overrides.isNotEmpty) 'forms': item.overrides,
          },
      ],
    };
  }

  /// S10 and S25 read from the drawn facts: the form of each key [item] has
  /// as [type], its overrides included when [overrides] holds.
  Map<String, String> formsOf(
    DrawnItem item,
    String type, {
    required bool overrides,
  }) {
    final deponent =
        item.deponent ??
        (type == 'TD' ? typeDeponent ?? axes[deponentBy]! : null);
    final endings = endingByType[type]!;
    final forms = <String, String>{};
    for (final features in keys) {
      final key = keyOf(features);
      var target = features;
      if (deponent != null) {
        final moves =
            deponent.contains(features[deponentBy]) &&
            this.moves.any((m) => rawMatches(features, m));
        final voice = features[voiceAxis];
        if (voice == passive && !moves || voice == active && moves) continue;
        if (voice == passive) target = {...features, voiceAxis: active};
      }
      if (item.impersonal &&
          target[voiceAxis] == passive &&
          personal.any((p) => rawMatches(target, p))) {
        continue;
      }
      forms[keyOf(target)] = '${item.stem}${endings[key]}';
    }
    if (overrides) forms.addAll(item.overrides);
    return forms;
  }
}

/// Draws a file of 3 or 4 axes with 2 or 3 codes each. A regular rule may drop
/// the axes some keys lack; an endings rule drops none (S30), and no two
/// endings rules have the same `from` axes (S30).
/// No move or personal pattern names the voice axis: a move on it would put a
/// moved passive key onto an active key that stays.
DrawnVerbsFile drawVerbsFile(Random r) {
  T pick<T>(List<T> xs) => xs[r.nextInt(xs.length)];
  List<T> subset<T>(List<T> xs) {
    final picked = [...xs.where((_) => r.nextBool())];
    return picked.isEmpty ? [pick(xs)] : picked;
  }

  final axes = {
    for (var a = 0; a < 3 + r.nextInt(2); a++)
      'ax$a': [for (var c = 0; c < 2 + r.nextInt(2); c++) 'a${a}c$c'],
  };
  final names = [...axes.keys];
  final voiceAxis = pick(names);
  final [active, passive, ...] = [...axes[voiceAxis]!]..shuffle(r);
  final others = [...names.where((a) => a != voiceAxis)];
  final deponentBy = pick(others);
  final dropped = r.nextBool() ? subset(others) : <String>[];

  RawPattern pattern(List<String> pool, {bool single = false}) => {
    for (final axis in subset(pool))
      axis: single ? [pick(axes[axis]!)] : subset(axes[axis]!),
  };
  List<RawPattern> patterns(List<String> pool) => [
    for (var i = 0; i <= r.nextInt(2); i++) pattern(pool),
  ];
  // S15: each personal pattern must remove a key the ones before it leave.
  List<RawPattern> personal() {
    final [axis, ...rest] = [...others]..shuffle(r);
    final codes = [...axes[axis]!]..shuffle(r);
    final cut = 1 + r.nextInt(codes.length - 1);
    return [
      {axis: codes.sublist(0, cut)},
      if (r.nextBool()) {axis: codes.sublist(cut), ...pattern(rest)},
    ];
  }

  final endingAxes = <String>{};
  final file = DrawnVerbsFile.fromFacts(
    axes: axes,
    voiceAxis: voiceAxis,
    active: active,
    passive: passive,
    deponentBy: deponentBy,
    moves: patterns(others),
    personal: personal(),
    typeDeponent: r.nextBool() ? null : subset(axes[deponentBy]!),
    rules: [
      for (var i = 0; i <= r.nextInt(3); i++)
        () {
          final drop = i > 0 && dropped.isNotEmpty && r.nextBool()
              ? dropped
              : <String>[];
          final from = pattern([
            ...names.where((a) => !drop.contains(a)),
          ], single: true);
          final axes = (from.keys.toList()..sort()).join('.');
          return (
            when: pattern(names),
            from: {for (final e in from.entries) e.key: e.value.single},
            drop: drop,
            endings:
                drop.isEmpty &&
                (i == 0 || r.nextBool()) &&
                endingAxes.add(axes),
            impersonal: r.nextInt(3) == 0,
          );
        }(),
    ],
    dropped: dropped,
  );

  for (var i = 0; i < 3 + r.nextInt(4); i++) {
    final type = pick(['T', 'TD', 'T2']);
    // A deponent has no impersonal passive: S25 refuses the item (S15 for a
    // deponent type).
    final impersonal = type != 'TD' && r.nextInt(3) == 0;
    // The regular reading of an impersonal item is refused on a deponent type
    // like the item's own (S15).
    final regular = [
      for (final t in ['T', 'TD', 'T2'])
        if (t != type && !(impersonal && t == 'TD')) t,
    ];
    final item = (
      id: 'i$i',
      type: type,
      stem: 'st${String.fromCharCode(0x61 + i)}',
      deponent: !impersonal && r.nextInt(4) == 0
          ? subset(axes[deponentBy]!)
          : null,
      impersonal: impersonal,
      regularType: r.nextBool() ? pick(regular) : null,
      overrides: <String, String>{},
    );
    final forms = file.formsOf(item, type, overrides: false);
    for (var o = r.nextInt(3); o > 0; o--) {
      final key = pick([...forms.keys]);
      item.overrides[key] = '${item.stem}q${forms[key]!.substring(3)}';
    }
    file.items.add(item);
  }
  file.items.shuffle(r);
  return file;
}
