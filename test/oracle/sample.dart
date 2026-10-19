/// The items the oracle compares: the curated ones named in `type_map.yaml`
/// plus, per mapped Collatinus model, its most frequent lemmas, written as
/// extra items of the data file that declares the model's type.
///
/// A lemma becomes an item through the principal parts Collatinus gives for
/// it. A line whose radicals are only half there (a perfect radical without a
/// supine one) or that lists several spellings is left out: the engine would
/// need parts the line does not supply.
library;

import 'dart:math';

import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/form_label.dart';
import 'package:latin_practice/data/lesson_data.dart' show normalizeDiacritics;

import 'collatinus.dart';
import 'oracle.dart';

/// Lemmas taken per model.
const lemmasPerModel = 20;

/// One item of the sample and the Collatinus lemmas it is compared with.
final class SampleEntry {
  final String dataFileId;

  /// The item's id; a synthetic item is found by its translation, which is
  /// its Collatinus lemma key.
  final String? itemId;
  final List<String> lemmas;
  final bool synthetic;

  SampleEntry(
    this.dataFileId,
    this.itemId,
    this.lemmas, {
    required this.synthetic,
  });
}

final class Sample {
  /// The sources to parse, with the synthetic items appended.
  final Map<String, String> sources;
  final List<SampleEntry> entries;

  /// Collatinus model -> lemmas this sample took for it. A mapped model the
  /// sample leaves to another corpus is absent.
  final Map<String, int> lemmasByModel;

  Sample(this.sources, this.entries, this.lemmasByModel);
}

/// Mapped model -> its lemmas in the sample that took most of them, for every
/// model that builds its items. Each corpus samples the models of its own
/// types, so a model both corpora sample is not counted twice. A model no
/// sample built is 0.
Map<String, int> lemmasByModel(Iterable<Sample> samples, TypeMap typeMap) => {
  for (final model in typeMap.builds.keys)
    model: samples.fold(0, (n, s) => max(n, s.lemmasByModel[model] ?? 0)),
};

/// Mapped model -> its lemmas, for every model that misses its floor across
/// [samples]: [lemmasPerModel], or exactly the `lemmas` a model declares
/// whose corpus holds fewer. A declared count outside 1 .. floor-1 is refused.
Map<String, int> modelsOffFloor(Iterable<Sample> samples, TypeMap typeMap) {
  final off = <String, int>{};
  for (final e in lemmasByModel(samples, typeMap).entries) {
    final declared = typeMap.models[e.key]!.lemmas;
    if (declared != null && (declared < 1 || declared >= lemmasPerModel)) {
      throw StateError(
        'type_map.yaml: ${e.key} declares $declared lemmas, '
        'which is not in 1 .. ${lemmasPerModel - 1}',
      );
    }
    final met = declared == null
        ? e.value >= lemmasPerModel
        : e.value == declared;
    if (!met) off[e.key] = e.value;
  }
  return off;
}

/// A Collatinus spelling as our data writes it: macrons stay, breves go, `j`
/// is `i`.
String ours(String collatinus) => collatinus
    .toLowerCase()
    .replaceAll('̆', '')
    .replaceAllMapped(RegExp('[ăĕĭŏŭ]'), (m) => 'aeiou'['ăĕĭŏŭ'.indexOf(m[0]!)])
    .replaceAll('j', 'i')
    .replaceAll(RegExp(r'\d'), '');

String _lemmaOf(List<String> fields) {
  final head = fields[0];
  return head.contains('=') ? head.split('=')[1] : head;
}

/// The spelling of a lemma line's radical, or null if the line has none.
List<String>? _radical(String field) =>
    field.isEmpty ? null : [for (final r in field.split(',')) ours(r)];

String _yaml(String text) => '"$text"';

/// The extra item for [lemmaKey] under [model]: its text and the spelling its
/// id is made from, or null if the line does not supply what the type needs.
typedef _Built = ({String text, String idSpelling});

_Built? _verbItem(
  Collatinus collatinus,
  String lemmaKey,
  Map<String, String> build,
  String type,
) {
  final fields = collatinus.lemmaLines[lemmaKey]!;
  final canonical = _lemmaOf(fields);
  if (canonical.contains(',') || fields[4].contains('v.')) return null;
  final perfect = _radical(fields[2]), supine = _radical(fields[3]);
  final deponent = build['deponent'] == 'true';
  if (!deponent && (perfect == null || supine == null)) return null;

  final present = ours(canonical);
  final strip = build['strip']!;
  if (!present.endsWith(strip)) return null;
  final stem = present.substring(0, present.length - strip.length);
  final parts = <String>[
    'infinitiv: ${_yaml(stem + build['infinitive']!)}',
    'praesens_1sg: ${_yaml(present)}',
    if (!deponent && perfect != null)
      'perfekt_1sg: [${perfect.map((r) => _yaml('$rī')).join(', ')}]',
    if (supine != null)
      'supinum: [${supine.map((r) => _yaml('${r}um')).join(', ')}]',
  ];
  return (
    idSpelling: stem + build['infinitive']!,
    text:
        '''
  - type: $type
    translation: ${_yaml(lemmaKey)}
    parts: {${parts.join(', ')}}${deponent ? '\n    deponent: all' : ''}
''',
  );
}

_Built? _nounItem(
  Collatinus collatinus,
  String lemmaKey,
  Map<String, String> build,
  String type,
) {
  final fields = collatinus.lemmaLines[lemmaKey]!;
  final canonical = _lemmaOf(fields);
  if (canonical.contains(',')) return null;
  final nom = ours(canonical);
  if (!nom.endsWith(build['ends'] ?? '')) return null;
  final cut = int.parse(build['cut']!);
  final radical = _radical(fields[2]);
  if (radical != null && radical.length > 1) return null;
  final stem = radical?.single ?? nom.substring(0, nom.length - cut);
  return (
    idSpelling: nom,
    text:
        '''
  - type: $type
    translation: ${_yaml(lemmaKey)}
    parts: {nom: ${_yaml(nom)}, gen: ${_yaml(stem + build['genitive']!)}}
''',
  );
}

_Built? _adjectiveItem(
  Collatinus collatinus,
  String lemmaKey,
  Map<String, String> build,
  String type,
) {
  final fields = collatinus.lemmaLines[lemmaKey]!;
  final canonical = _lemmaOf(fields);
  if (canonical.contains(',')) return null;
  final nom = ours(canonical);
  if (!nom.endsWith(build['ends'] ?? '')) return null;
  final radical = _radical(fields[2]);
  if (radical != null && radical.length > 1) return null;
  if (radical != null && build['radical'] == 'none') return null;
  final stem =
      radical?.single ??
      nom.substring(0, nom.length - int.parse(build['cut']!));
  final parts = <String>[
    'nom: ${_yaml(nom)}',
    if (build.containsKey('f')) 'nom_f: ${_yaml(stem + build['f']!)}',
    if (build.containsKey('n')) 'nom_n: ${_yaml(stem + build['n']!)}',
  ];
  return (
    idSpelling: nom,
    text:
        '''
  - type: $type
    translation: ${_yaml(lemmaKey)}
    parts: {${parts.join(', ')}}
''',
  );
}

/// The sample of the corpus [sources]: the [curated] items (data file id ->
/// item id -> lemmas) and the most frequent lemmas of every model whose type
/// the corpus declares.
Sample buildSample({
  required Map<String, String> sources,
  required Collatinus collatinus,
  required TypeMap typeMap,
  required Map<String, Map<String, List<String>>> curated,
}) {
  final declared = {
    for (final file in parseGrammarFiles(sources))
      file.dataFileId: (file.path, file.declaredTypes.keys.toSet(), file),
  };

  final seen = {
    for (final file in declared.values)
      for (final item in file.$3.items) item.id,
  };
  final entries = <SampleEntry>[
    for (final file in curated.entries)
      for (final item in file.value.entries)
        SampleEntry(file.key, item.key, item.value, synthetic: false),
  ];
  final takenLemmas = {
    for (final curated in [typeMap.sample, typeMap.shipped])
      for (final file in curated.values)
        for (final lemmas in file.values) ...lemmas,
  };

  final extra = <String, StringBuffer>{};
  final taken = <String, int>{};
  for (final model in typeMap.builds.entries) {
    final spec = model.value;
    taken[model.key] = 0;
    final owner = declared.entries
        .where((f) => spec.types.any(f.value.$2.contains))
        .firstOrNull;
    if (owner == null) continue;
    final type = spec.types.firstWhere(owner.value.$2.contains);
    final dataFileId = owner.key;

    final candidates =
        collatinus.lemmaLines.entries
            .where(
              (e) =>
                  e.value[1] == model.key && int.tryParse(e.value[5]) != null,
            )
            .toList()
          ..sort((a, b) {
            final byFrequency = int.parse(
              b.value[5],
            ).compareTo(int.parse(a.value[5]));
            return byFrequency != 0 ? byFrequency : a.key.compareTo(b.key);
          });

    var count = 0;
    for (final candidate in candidates) {
      if (count == lemmasPerModel) break;
      if (takenLemmas.contains(candidate.key)) continue;
      final built = switch (spec.kind) {
        'verb' => _verbItem(collatinus, candidate.key, spec.build, type),
        'noun' => _nounItem(collatinus, candidate.key, spec.build, type),
        'adjective' => _adjectiveItem(
          collatinus,
          candidate.key,
          spec.build,
          type,
        ),
        _ => throw StateError('type_map.yaml: kind ${spec.kind}'),
      };
      if (built == null) continue;
      if (!seen.add(normalizeDiacritics(built.idSpelling))) continue;
      (extra[owner.value.$1] ??= StringBuffer()).write(built.text);
      entries.add(
        SampleEntry(dataFileId, null, [candidate.key], synthetic: true),
      );
      takenLemmas.add(candidate.key);
      count++;
    }
    taken[model.key] = count;
  }

  return Sample(
    {
      for (final entry in sources.entries)
        entry.key: '${entry.value}\n${extra[entry.key] ?? ''}',
    },
    entries,
    taken,
  );
}

/// Our forms of every entry, as the engine derives them.
List<ItemForms> engineForms(Sample sample) {
  final files = parseGrammarFiles(sample.sources);
  final engine = GrammarEngine(files);

  return [
    for (final entry in sample.entries)
      () {
        final file = files.singleWhere((f) => f.dataFileId == entry.dataFileId);
        final itemId =
            entry.itemId ??
            file.items
                .singleWhere((i) => i.translation == entry.lemmas.single)
                .id;
        final derivation = engine.of(entry.dataFileId, itemId);
        return ItemForms(
          dataFileId: entry.dataFileId,
          id: itemId,
          type: derivation.type,
          lemmas: entry.lemmas,
          synthetic: entry.synthetic,
          deponent: derivation.deponentKeys.isNotEmpty,
          fullDeponent: derivation.fullDeponent,
          emitted: {
            for (final f in derivation.forms.entries) f.key: f.value.variants,
          },
          internal: {
            for (final f in derivation.internal.entries)
              f.key: f.value.variants,
          },
        );
      }(),
  ];
}

/// The axes of every data file of [sources].
Map<String, Axes> axesOf(Map<String, String> sources) => {
  for (final file in parseGrammarFiles(sources)) file.dataFileId: file.axes,
};
