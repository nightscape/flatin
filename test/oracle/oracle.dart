/// Compares every form we generate with the Collatinus data (plan 5.3, 5.4).
///
/// The gate is the `form` category: for every key both sides have, some
/// accepted spelling of ours must equal some Collatinus variant after
/// [oracleNorm] plus `j`->`i`. A `form` diff that is not listed
/// in `allowed_diffs.yaml` fails the run. Everything else — a macron that
/// differs, a variant only one side has, a key only one side has — is
/// reported and never gates, because Collatinus marks quantity by other
/// conventions than a school book and covers other forms than we teach.
///
/// A form of two words (amātus sum, allātūrum esse) is not compared:
/// Collatinus files single words only, so the parts carry the comparison.
library;

import 'package:latin_practice/data/lesson_data.dart' show normalizeDiacritics;
import 'package:latin_practice/models/form_label.dart';
import 'package:yaml/yaml.dart';

import 'collatinus.dart';

// ------------------------------------------------------------ normalization

const _marked = 'āēīōūȳăĕĭŏŭ', _plain = 'aeiouyaeiou';
final _combining = RegExp('[̀-ͯ]');

/// Letters only: no case, no quantity mark. The app's [normalizeDiacritics]
/// strips our macrons; Collatinus adds breves and combining marks on top.
String oracleNorm(String text) => normalizeDiacritics(text.trim().toLowerCase())
    .replaceAll(_combining, '')
    .replaceAllMapped(
      RegExp('[$_marked]'),
      (m) => _plain[_marked.indexOf(m[0]!)],
    );

/// What the form gate compares. Collatinus writes consonantal i as `j`.
String oracleCompare(String text) => oracleNorm(text).replaceAll('j', 'i');

/// True when both spellings mark the same vowels long.
///
/// Collatinus also marks a vowel that is long only by position (`fōrtĭs`) or
/// the first vowel of a diphthong, and `̆` on a long vowel means "either".
/// Those marks are dropped, which is why a missing macron before two
/// consonants (āctum) is invisible to this check (plan 5.4).
bool sameQuantity(String ours, String theirs) {
  List<(String, String)> marks(String text) {
    final out = <(String, String)>[];
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (char == '̆' && out.isNotEmpty) {
        out[out.length - 1] = (
          out.last.$1,
          out.last.$2 == 'long' ? 'anceps' : 'short',
        );
      } else if (char == '̄' && out.isNotEmpty) {
        out[out.length - 1] = (out.last.$1, 'long');
      } else {
        final base = oracleCompare(char);
        out.add((base, 'āēīōūȳ'.contains(char) ? 'long' : 'short'));
      }
    }
    return out;
  }

  final o = marks(ours), t = marks(theirs);
  if (o.length != t.length) return false;
  bool consonant(int i) => i < t.length && !'aeiouy'.contains(t[i].$1);
  for (var i = 0; i < o.length; i++) {
    if (t[i].$2 == 'anceps' || o[i].$2 == t[i].$2) continue;
    final positional =
        consonant(i + 1) && (consonant(i + 2) || t[i + 1].$1 == 'x');
    final diphthong =
        i + 1 < t.length &&
        ['ae', 'au', 'oe', 'eu'].contains('${t[i].$1}${t[i + 1].$1}');
    if (t[i].$2 == 'long' && o[i].$2 == 'short' && (positional || diphthong)) {
      continue;
    }
    return false;
  }
  return true;
}

// ------------------------------------------------------------------ inputs

/// The forms of one item, as the engine derives them.
final class ItemForms {
  final String dataFileId;
  final String id;
  final String type;

  /// The Collatinus lemma keys: the item's own lemma first, then the separate
  /// adverb lemma of an adjective.
  final List<String> lemmas;

  /// Built from a lemma line rather than written in a data file.
  final bool synthetic;

  /// Some passive key of the item is a deponent move (S10).
  final bool deponent;

  /// Key -> accepted spellings, the shown one first (S9).
  final Map<FormKey, List<String>> emitted;
  final Map<FormKey, List<String>> internal;

  ItemForms({
    required this.dataFileId,
    required this.id,
    required this.type,
    required this.lemmas,
    required this.synthetic,
    required this.deponent,
    required this.emitted,
    required this.internal,
  });

  Map<FormKey, List<String>> get all => {...emitted, ...internal};
}

/// `morph_map.yaml`.
final class MorphMap {
  final Map<String, Map<String, String>> phrases;
  final Map<String, Map<String, String>> words;
  final Set<int> ignored;
  final Set<int> adverbMorphs;
  final Map<String, String> adverbFeatures;
  final Map<String, List<String>> dropAxes;

  MorphMap({
    required this.phrases,
    required this.words,
    required this.ignored,
    required this.adverbMorphs,
    required this.adverbFeatures,
    required this.dropAxes,
  });

  factory MorphMap.parse(String source) {
    final root = loadYaml(source) as YamlMap;
    Map<String, Map<String, String>> table(String key) => {
      for (final e in (root[key] as YamlMap).entries)
        '${e.key}': {
          for (final f in (e.value as YamlMap).entries) '${f.key}': '${f.value}',
        },
    };
    return MorphMap(
      phrases: table('phrases'),
      words: table('words'),
      ignored: {for (final e in (root['ignored'] as YamlMap).keys) e as int},
      adverbMorphs: {for (final n in root['adverb_morphs'] as YamlList) n as int},
      adverbFeatures: {
        for (final e in (root['adverb_features'] as YamlMap).entries)
          '${e.key}': '${e.value}',
      },
      dropAxes: {
        for (final e in (root['drop_axes'] as YamlMap).entries)
          '${e.key}': [for (final a in e.value as YamlList) '$a'],
      },
    );
  }

  /// The features of morph [number], or null when it is out of our scope.
  ///
  /// [adverbLemma] says whether the spellings come from the separate adverb
  /// lemma of an adjective; [graded] whether the item's own keys use `grad`,
  /// in which case a Collatinus morph without a comparison word is positive.
  Map<String, String>? features(
    int number,
    String text, {
    required bool adverbLemma,
    required bool graded,
  }) {
    if (ignored.contains(number)) return null;
    if (adverbLemma != adverbMorphs.contains(number)) return null;
    final features = <String, String>{};
    var rest = text;
    for (final phrase in phrases.entries) {
      if (rest.contains(phrase.key)) {
        features.addAll(phrase.value);
        rest = rest.replaceAll(phrase.key, ' ');
      }
    }
    for (final word in rest.split(' ').where((w) => w.isNotEmpty)) {
      final mapped = words[word];
      if (mapped == null) {
        throw StateError('morph $number "$text": morph_map.yaml has no "$word"');
      }
      features.addAll(mapped);
    }
    if (adverbLemma) features.addAll(adverbFeatures);
    if (graded && !adverbLemma) features.putIfAbsent('grad', () => 'pos');
    for (final axis in dropAxes[features['modus']] ?? const <String>[]) {
      features.remove(axis);
    }
    return features;
  }
}

/// How the sample turns the lemmas of one Collatinus model into items.
final class ModelSpec {
  final List<String> types;

  /// `verb`, `noun` or `adjective`; null for a model whose lemmas are written
  /// by hand.
  final String? kind;
  final Map<String, String> build;

  ModelSpec(this.types, this.kind, this.build);
}

/// `type_map.yaml`.
final class TypeMap {
  /// Data file id -> item id -> Collatinus lemma keys.
  final Map<String, Map<String, List<String>>> sample;

  /// Collatinus model -> the types of ours it stands for.
  final Map<String, ModelSpec> models;

  /// Item id -> word-initial rewrites applied to the Collatinus spellings.
  final Map<String, Map<String, String>> spelling;

  TypeMap({
    required this.sample,
    required this.models,
    required this.spelling,
  });

  Map<String, ModelSpec> get builds => {
        for (final e in models.entries)
          if (e.value.kind != null) e.key: e.value,
      };

  factory TypeMap.parse(String source) {
    final root = loadYaml(source) as YamlMap;
    ModelSpec spec(YamlMap node) {
      const kinds = ['verb', 'noun', 'adjective'];
      final kind = kinds.where(node.containsKey).singleOrNull;
      return ModelSpec(
        [for (final t in node['types'] as YamlList) '$t'],
        kind,
        kind == null
            ? const {}
            : {
                for (final e in (node[kind] as YamlMap).entries)
                  '${e.key}': '${e.value}',
              },
      );
    }

    return TypeMap(
      sample: {
        for (final file in (root['sample'] as YamlMap).entries)
          '${file.key}': {
            for (final item in (file.value as YamlMap).entries)
              '${item.key}': [for (final l in item.value as YamlList) '$l'],
          },
      },
      models: {
        for (final e in (root['models'] as YamlMap).entries)
          '${e.key}': spec(e.value as YamlMap),
      },
      spelling: {
        for (final e in (root['spelling'] as YamlMap).entries)
          '${e.key}': {
            for (final r in (e.value as YamlMap).entries) '${r.key}': '${r.value}',
          },
      },
    );
  }

  String rewrite(String itemId, String variant) {
    for (final rule in spelling[itemId]?.entries ?? const <MapEntry<String, String>>[]) {
      // The rewrite is word-initial but the spelling carries quantity marks,
      // so it is matched on the letters.
      final letters = oracleNorm(variant);
      if (!letters.startsWith(rule.key)) continue;
      var cut = 0, seen = 0;
      while (seen < rule.key.length) {
        if (!_combining.hasMatch(variant[cut])) seen++;
        cut++;
      }
      return rule.value + variant.substring(cut);
    }
    return variant;
  }
}

/// One entry of `allowed_diffs.yaml` or `allowed_missing.yaml`. It covers a
/// diff when every field it names matches; `key` is a pattern whose `*`
/// stands for exactly one dot-separated segment.
final class AllowedDiff {
  final DiffCategory category;
  final String? item;
  final List<String>? keys;
  final List<String>? types;

  /// True: only items the sample made up; null: any item.
  final bool? synthetic;

  /// True: only deponent items; null: any item.
  final bool? deponent;
  final String? ours;
  final String? theirs;
  final String reason;

  AllowedDiff({
    required this.category,
    this.item,
    this.keys,
    this.types,
    this.synthetic,
    this.deponent,
    this.ours,
    this.theirs,
    required this.reason,
  });

  bool covers(Diff diff) {
    if (diff.category != category) return false;
    if (item != null && item != diff.item) return false;
    if (types != null && !types!.contains(diff.type)) return false;
    if (synthetic != null && synthetic != diff.synthetic) return false;
    if (deponent != null && deponent != diff.deponent) return false;
    if (keys != null && !keys!.any((k) => _keyMatches(k, diff.key))) {
      return false;
    }
    if (ours != null && ours != diff.ours.join(' / ')) return false;
    if (theirs != null && theirs != diff.theirs.join(' / ')) return false;
    return true;
  }

  static bool _keyMatches(String pattern, String key) {
    final p = pattern.split('.'), k = key.split('.');
    if (p.length != k.length) return false;
    for (var i = 0; i < p.length; i++) {
      if (p[i] != '*' && p[i] != k[i]) return false;
    }
    return true;
  }

  String get describe =>
      '${category.id} item=$item keys=$keys types=$types ours=$ours theirs=$theirs';

  static List<AllowedDiff> parse(String source) => [
    for (final entry in loadYaml(source) as YamlList)
      if (entry['direction'] != null && entry['keys'] == null)
        throw FormatException('a "${entry['direction']}" entry needs keys: '
            '${entry['reason']}')
      else
        AllowedDiff(
        category: switch (entry['direction']) {
          null => DiffCategory.form,
          'ours' => DiffCategory.missingOurs,
          'theirs' => DiffCategory.missingTheirs,
          final other => throw FormatException('direction $other'),
        },
        item: entry['item'] == null ? null : '${entry['item']}',
        keys: entry['keys'] == null
            ? null
            : [for (final k in entry['keys'] as YamlList) '$k'],
        types: entry['types'] == null
            ? null
            : [for (final t in entry['types'] as YamlList) '$t'],
        synthetic: entry['synthetic'] as bool?,
        deponent: entry['deponent'] as bool?,
        ours: entry['ours'] == null ? null : '${entry['ours']}',
        theirs: entry['theirs'] == null ? null : '${entry['theirs']}',
        reason: '${entry['reason']}',
      ),
  ];
}

// ----------------------------------------------------------------- results

enum DiffCategory {
  form,
  quantity,
  variantMissingOurs,
  variantMissingTheirs,
  missingOurs,
  missingTheirs;

  String get id => switch (this) {
    DiffCategory.form => 'form',
    DiffCategory.quantity => 'quantity',
    DiffCategory.variantMissingOurs => 'variant_missing_ours',
    DiffCategory.variantMissingTheirs => 'variant_missing_theirs',
    DiffCategory.missingOurs => 'missing_ours',
    DiffCategory.missingTheirs => 'missing_theirs',
  };
}

final class Diff {
  final DiffCategory category;
  final String item;
  final String type;
  final FormKey key;
  final List<String> ours;
  final List<String> theirs;
  final bool synthetic;
  final bool deponent;

  Diff({
    required this.category,
    required this.item,
    required this.type,
    required this.key,
    required this.ours,
    required this.theirs,
    required this.synthetic,
    required this.deponent,
  });

  String get signature =>
      '$item $key: ${ours.join(" / ")} / ${theirs.join(" / ")}';
}

final class OracleResult {
  final List<Diff> diffs;

  /// Keys compared, per data file id.
  final Map<String, int> compared;

  /// A morph number with its text -> how often the mapping dropped it (5.2).
  final Map<String, int> skippedMorphs;

  /// The items with at least one compared key, as `<file>:<id>`.
  final Set<String> itemsCompared;

  OracleResult(
    this.diffs,
    this.compared,
    this.skippedMorphs,
    this.itemsCompared,
  );

  List<Diff> of(DiffCategory category) =>
      diffs.where((d) => d.category == category).toList();

  /// Gating diffs (form and missing) that no entry of [allowed] covers.
  List<Diff> unlisted(List<AllowedDiff> allowed) => diffs
      .where((d) => gating.contains(d.category))
      .where((d) => !allowed.any((a) => a.covers(d)))
      .toList();

  /// Entries of [allowed] that cover no diff any more.
  List<AllowedDiff> stale(List<AllowedDiff> allowed) =>
      allowed.where((a) => !diffs.any(a.covers)).toList();
}

/// Whether the run compared every entry of a sample of [entries] items.
bool comparedWholeSample(OracleResult result, int entries) =>
    result.itemsCompared.length >= entries;

const gating = {
  DiffCategory.form,
  DiffCategory.missingOurs,
  DiffCategory.missingTheirs,
};

// --------------------------------------------------------------- the run

OracleResult runOracle({
  required List<ItemForms> items,
  required Map<String, Axes> axesByFile,
  required Collatinus collatinus,
  required MorphMap morphMap,
  required TypeMap typeMap,
  String Function(String) compare = oracleCompare,
}) {
  final diffs = <Diff>[];
  final compared = <String, int>{};
  final skipped = <String, int>{};
  final itemsCompared = <String>{};

  for (final item in items) {
    final lemmas = item.lemmas;
    final axes = axesByFile[item.dataFileId]!;
    // The adverb morphs come from a separate Collatinus lemma; an item
    // without one has nothing to compare its adverb keys with.
    final ours = {
      for (final e in item.all.entries)
        if (lemmas.length > 1 ||
            !axes.parseKey(e.key).containsKey('adverb'))
          e.key: e.value,
    };
    final graded = ours.keys.any((k) => axes.parseKey(k).containsKey('grad'));

    final model = collatinus.modelOf(lemmas.first);
    final types = typeMap.models[model]?.types;
    if (types == null) {
      throw StateError('type_map.yaml has no model "$model" (${item.id})');
    }
    if (!types.contains(item.type)) {
      throw StateError(
        '${item.id} is a ${item.type} but its lemma ${lemmas.first} uses the '
        'Collatinus model "$model" ($types)',
      );
    }

    final theirs = <FormKey, List<String>>{};
    for (final (index, lemma) in lemmas.indexed) {
      collatinus.inflect(lemma).forEach((morph, spellings) {
        final features = morphMap.features(
          morph,
          collatinus.morphs[morph]!,
          adverbLemma: index == 1,
          graded: graded,
        );
        if (features == null) {
          final name = '$morph ${collatinus.morphs[morph]!}';
          skipped[name] = (skipped[name] ?? 0) + 1;
          return;
        }
        final key = axes.formatKey(features);
        final into = theirs[key] ??= [];
        for (final spelling in spellings) {
          final variant = typeMap.rewrite(item.id, spelling);
          if (!into.contains(variant)) into.add(variant);
        }
      });
    }

    void add(DiffCategory category, FormKey key, List<String> o, List<String> t) =>
        diffs.add(Diff(
          category: category,
          item: item.id,
          type: item.type,
          key: key,
          ours: o,
          theirs: t,
          synthetic: item.synthetic,
          deponent: item.deponent,
        ));

    final keys = [
      ...ours.keys,
      ...theirs.keys.where((k) => !ours.containsKey(k)),
    ];
    for (final key in keys) {
      final o = ours[key], t = theirs[key];
      if (o != null && o.any((s) => s.contains(' '))) continue;
      if (o == null) {
        add(DiffCategory.missingOurs, key, const [], t!);
        continue;
      }
      if (t == null) {
        add(DiffCategory.missingTheirs, key, o, const []);
        continue;
      }
      compared[item.dataFileId] = (compared[item.dataFileId] ?? 0) + 1;
      itemsCompared.add('${item.dataFileId}:${item.id}');
      final oc = o.map(compare).toSet(), tc = t.map(compare).toSet();
      if (oc.intersection(tc).isEmpty) {
        add(DiffCategory.form, key, o, t);
        continue;
      }
      final pairs = [
        for (final a in o)
          for (final b in t)
            if (compare(a) == compare(b)) (a, b),
      ];
      for (final (a, b) in pairs.where((p) => !sameQuantity(p.$1, p.$2))) {
        add(DiffCategory.quantity, key, [a], [b]);
      }
      if (tc.difference(oc).isNotEmpty) {
        add(DiffCategory.variantMissingOurs, key, o, t);
      }
      if (oc.difference(tc).isNotEmpty) {
        add(DiffCategory.variantMissingTheirs, key, o, t);
      }
    }
  }
  return OracleResult(diffs, compared, skipped, itemsCompared);
}

// ------------------------------------------------------------------ report

String oracleReport(OracleResult result, List<AllowedDiff> allowed) {
  final out = StringBuffer('# Oracle report\n\n');
  final unlisted = result.unlisted(allowed);

  out.writeln('Keys compared: ${result.compared.entries.map((e) => "${e.key} ${e.value}").join(", ")}.');
  out.writeln('Gate: ${unlisted.length} unlisted gating diffs '
      '(${allowed.length} allowed entries).\n');

  out.writeln('## Counts per category\n');
  out.writeln('| category | count | gates |\n|---|---|---|');
  for (final category in DiffCategory.values) {
    out.writeln('| ${category.id} | ${result.of(category).length} | '
        '${gating.contains(category) ? "yes, unless listed" : "no"} |');
  }

  out.writeln('\n## Counts per type\n');
  out.writeln('| type | ${DiffCategory.values.map((c) => c.id).join(" | ")} |');
  out.writeln('|---|${DiffCategory.values.map((_) => "---").join("|")}|');
  final types = {for (final d in result.diffs) d.type}.toList()..sort();
  for (final type in types) {
    final row = DiffCategory.values.map(
      (c) => result.diffs.where((d) => d.type == type && d.category == c).length,
    );
    out.writeln('| $type | ${row.join(" | ")} |');
  }

  for (final category in DiffCategory.values) {
    final list = result.of(category);
    if (list.isEmpty) continue;
    out.writeln('\n## ${category.id} (${list.length})\n');
    for (final diff in list) {
      final mark = gating.contains(category) && !unlisted.contains(diff)
          ? ' [allowed]'
          : '';
      out.writeln('- ${diff.signature}$mark  (${diff.type})');
    }
  }

  out.writeln('\n## Collatinus morphs the mapping drops (5.2)\n');
  out.writeln('How much of Collatinus never reaches the comparison. A morph '
      'listed here is one `morph_map.yaml` declares outside our axes, or one '
      'that belongs to the other lemma of an adjective pair.\n');
  if (result.skippedMorphs.isEmpty) out.writeln('None.');
  for (final entry in result.skippedMorphs.entries) {
    out.writeln('- ${entry.key}: ${entry.value} times');
  }

  out.writeln('\n## Macron suggestions (Q10)\n');
  out.writeln('Every vowel Collatinus marks long that our spelling writes '
      'short, outside the positions plan 5.4 drops. A suggestion is a '
      'candidate for the principal part it comes from, not a verdict: '
      'Collatinus also marks hidden quantity the school spelling leaves out.\n');
  final byItem = <String, List<Diff>>{};
  for (final diff in result.of(DiffCategory.quantity)) {
    (byItem[diff.item] ??= []).add(diff);
  }
  if (byItem.isEmpty) out.writeln('None.');
  for (final entry in byItem.entries) {
    out.writeln('\n### ${entry.key} (${entry.value.length})\n');
    for (final diff in entry.value) {
      out.writeln('- ${diff.key}: ours ${diff.ours.single}, '
          'Collatinus ${diff.theirs.single}');
    }
  }
  return out.toString();
}
