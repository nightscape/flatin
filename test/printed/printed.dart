/// Compares our forms with a printed paradigm set (parent #14).
///
/// A printed form is a feature set plus the spellings the print accepts. Our
/// form for exactly these features must be one of those spellings, compared
/// as strings: a missing macron is a difference. A feature set we have no form
/// for is "missing". Forms of ours that the print does not show are ignored,
/// because the print is partial.
library;

import 'package:latin_practice/data/lesson_data.dart' show normalizeDiacritics;
import 'package:latin_practice/models/form_label.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:yaml/yaml.dart';

import '../oracle/oracle.dart';
import '../oracle/sample.dart';

/// The order in which [featureString] writes the codes of a feature set.
const _featureOrder = [
  'modus',
  'tempus',
  'genus_verbi',
  'person',
  'kasus',
  'numerus',
  'genus',
];

/// How a printed feature set becomes one of ours.
final class ShapeRule {
  /// Axes the print gives and we derive from the item (the person of a
  /// personal pronoun).
  final Set<String> drop;

  /// Axes the print gives but that our keys of this item do not use (the
  /// gender of a noun whose forms are not keyed by gender).
  final Set<String> dropIfUnkeyed;

  /// Axes we key by and the print leaves out.
  final Map<String, String> add;

  /// Axes we have one form for, held for this value only: the print's other
  /// values of the axis have no form of ours (the engine's perfect passive is
  /// the masculine).
  final Map<String, String> only;

  const ShapeRule({
    this.drop = const {},
    this.dropIfUnkeyed = const {},
    this.add = const {},
    this.only = const {},
  });
}

/// Per shape (the sorted axis names the print gives). A shape not listed here
/// is refused.
const shapeRules = <String, ShapeRule>{
  'genus,genus_verbi,kasus,modus,numerus,tempus': ShapeRule(),
  'genus,genus_verbi,modus,numerus,person,tempus': ShapeRule(
    drop: {'genus'},
    only: {'genus': 'm'},
  ),
  'genus,genus_verbi,modus,tempus': ShapeRule(
    drop: {'genus'},
    only: {'genus': 'm'},
  ),
  'genus,kasus,numerus': ShapeRule(dropIfUnkeyed: {'genus'}),
  'genus,kasus': ShapeRule(add: {'numerus': 'sg'}),
  'genus_verbi,kasus,modus,numerus,tempus': ShapeRule(add: {'genus': 'm'}),
  'genus_verbi,modus,numerus,person,tempus': ShapeRule(),
  'genus_verbi,modus,tempus': ShapeRule(),
  'kasus,numerus': ShapeRule(),
  'kasus,numerus,person': ShapeRule(drop: {'person'}),
};

/// The id an item has for a printed lemma: no macrons, lower case.
String itemIdOf(String lemma) => normalizeDiacritics(lemma.toLowerCase());

/// The dot-joined codes of [features] in the fixed [_featureOrder].
String featureString(Map<String, String> features) {
  final unknown = features.keys.where((a) => !_featureOrder.contains(a));
  if (unknown.isNotEmpty) {
    throw FormatException('printed axis ${unknown.join(", ")} is not known');
  }
  return [
    for (final axis in _featureOrder)
      if (features.containsKey(axis)) features[axis]!,
  ].join('.');
}

final class PrintedForm {
  final Map<String, String> features;
  final List<String> spellings;

  PrintedForm(this.features, this.spellings);
}

final class PrintedLemma {
  final String lemma;
  final List<PrintedForm> forms;

  PrintedLemma(this.lemma, this.forms);

  String get id => itemIdOf(lemma);
}

/// Reads only `lemma`, `features` and `spellings` of the paradigm file.
List<PrintedLemma> parsePrinted(String source) => [
  for (final entry in loadYaml(source) as YamlList)
    PrintedLemma(entry['lemma'] as String, [
      for (final form in entry['forms'] as YamlList)
        PrintedForm(
          {
            for (final f in (form['features'] as YamlMap).entries)
              '${f.key}': '${f.value}',
          },
          [for (final s in form['spellings'] as YamlList) s as String],
        ),
    ]),
];

/// A difference: [engine] is our shown spelling, null for a missing form.
final class Finding {
  final String lemma;
  final String features;
  final String? engine;

  Finding(this.lemma, this.features, this.engine);

  String get describe =>
      '$lemma $features'
      '${engine == null ? ' (missing)' : ' engine: $engine'}';
}

/// One entry of `allowed.yaml`. Each feature pattern is dot-separated; a
/// segment is a code, `*` for any code, or `a|b` for either code.
final class AllowedFinding {
  final String lemma;
  final List<String> features;
  final String? engine;
  final String reason;

  AllowedFinding(this.lemma, this.features, this.engine, this.reason);

  bool covers(Finding f) =>
      f.lemma == lemma &&
      f.engine == engine &&
      features.any((p) => matches(p)(f));

  bool Function(Finding) matches(String pattern) =>
      (f) =>
          f.lemma == lemma &&
          f.engine == engine &&
          _matches(pattern, f.features);

  /// The patterns of this entry that match none of [findings].
  List<String> dead(Iterable<Finding> findings) => [
    for (final pattern in features)
      if (!findings.any(matches(pattern))) pattern,
  ];

  static bool _matches(String pattern, String key) {
    final p = pattern.split('.'), k = key.split('.');
    if (p.length != k.length) return false;
    for (var i = 0; i < p.length; i++) {
      if (p[i] != '*' && !p[i].split('|').contains(k[i])) return false;
    }
    return true;
  }
}

final class Allowed {
  final int matchedLemmas;
  final List<AllowedFinding> diffs, missing;

  Allowed(this.matchedLemmas, this.diffs, this.missing);

  static Allowed parse(String source) {
    final root = loadYaml(source) as YamlMap;
    List<AllowedFinding> entries(String key, {required bool hasEngine}) => [
      for (final e in root[key] as YamlList)
        AllowedFinding(
          e['lemma'] as String,
          [for (final f in e['features'] as YamlList) f as String],
          hasEngine ? e['engine'] as String : null,
          e['reason'] as String,
        ),
    ];
    return Allowed(
      root['matched_lemmas'] as int,
      entries('diffs', hasEngine: true),
      entries('missing', hasEngine: false),
    );
  }
}

final class PrintedResult {
  final List<String> matched, unmatched;
  final int compared;
  final List<Finding> diffs, missing;

  PrintedResult(
    this.matched,
    this.unmatched,
    this.compared,
    this.diffs,
    this.missing,
  );

  /// Findings that [allowed] does not cover.
  List<Finding> unlisted(Allowed allowed) => [
    for (final d in diffs)
      if (!allowed.diffs.any((a) => a.covers(d))) d,
    for (final m in missing)
      if (!allowed.missing.any((a) => a.covers(m))) m,
  ];

  /// The dead patterns of [allowed], as "lemma pattern".
  List<String> stale(Allowed allowed) => [
    for (final a in allowed.diffs)
      for (final p in a.dead(diffs)) '${a.lemma} $p',
    for (final a in allowed.missing)
      for (final p in a.dead(missing)) '${a.lemma} $p',
  ];
}

/// Compares [printed] with [engine] (item id → our forms of that item).
/// [axesByFile] holds the axes of every data file.
PrintedResult comparePrinted({
  required List<PrintedLemma> printed,
  required Map<String, ItemForms> engine,
  required Map<String, Axes> axesByFile,
}) {
  final matched = <String>[], unmatched = <String>[];
  final diffs = <Finding>[], missing = <Finding>[];
  var compared = 0;

  for (final lemma in printed) {
    final item = engine[lemma.id];
    if (item == null) {
      unmatched.add(lemma.lemma);
      continue;
    }
    matched.add(lemma.id);
    final axes = axesByFile[item.dataFileId]!;
    final keyed = {for (final key in item.all.keys) ...axes.parseKey(key).keys};
    for (final form in lemma.forms) {
      compared++;
      final shape = (form.features.keys.toList()..sort()).join(',');
      final rule = shapeRules[shape];
      if (rule == null) {
        throw StateError(
          '${lemma.id} ${featureString(form.features)}: '
          'no mapping for the feature shape "$shape"',
        );
      }
      final printedKey = featureString(form.features);
      if (rule.only.entries.any((o) => form.features[o.key] != o.value)) {
        missing.add(Finding(lemma.id, printedKey, null));
        continue;
      }
      final ours = {
        for (final f in form.features.entries)
          if (!rule.drop.contains(f.key) &&
              !(rule.dropIfUnkeyed.contains(f.key) && !keyed.contains(f.key)))
            f.key: f.value,
        ...rule.add,
      };
      final spellings = item.all[axes.formatKey(ours)];
      if (spellings == null) {
        missing.add(Finding(lemma.id, printedKey, null));
      } else if (!form.spellings.contains(spellings.first)) {
        diffs.add(Finding(lemma.id, printedKey, spellings.first));
      }
    }
  }
  return PrintedResult(matched, unmatched, compared, diffs, missing);
}

const _dataFiles = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];

/// Our forms of the items with the given [ids] in the real data files, and
/// the axes of those files. An id that is no item is left out; an id that two
/// files have is an error.
({Map<String, ItemForms> items, Map<String, Axes> axes}) engineOf(
  Iterable<String> ids,
  String Function(String path) read,
) {
  final sources = {for (final path in _dataFiles) path: read(path)};
  final files = parseGrammarFiles(sources);
  final entries = <SampleEntry>[];
  for (final id in ids) {
    final owners = [
      for (final file in files)
        if (file.items.any((i) => i.id == id)) file.dataFileId,
    ];
    if (owners.length > 1) throw StateError('$id is an item of $owners');
    if (owners.isEmpty) continue;
    entries.add(SampleEntry(owners.single, id, [id], synthetic: false));
  }
  final forms = engineForms(Sample(sources, entries, const {}));
  return (items: {for (final f in forms) f.id: f}, axes: axesOf(sources));
}

/// The findings in the layout of `allowed.yaml`, reasons left to fill in.
String reportYaml(PrintedResult result) {
  final out = StringBuffer('matched_lemmas: ${result.matched.length}\n');
  out.writeln('diffs:');
  for (final d in result.diffs) {
    out.writeln(
      '  - {lemma: ${d.lemma}, features: "${d.features}", '
      'engine: "${d.engine}", reason: ""}',
    );
  }
  out.writeln('missing:');
  for (final m in result.missing) {
    out.writeln(
      '  - {lemma: ${m.lemma}, features: "${m.features}", reason: ""}',
    );
  }
  return out.toString();
}
