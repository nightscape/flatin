/// The oracle (plan 5.3): our forms against the Collatinus data.
///
/// Skipped by default because the data is not in the repo. Run it with
///   tool/oracle/fetch_collatinus.sh && flutter test --tags oracle --run-skipped
@Tags(['oracle'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/form_label.dart';

import 'collatinus.dart';
import 'oracle.dart';
import 'sample.dart';

const _fixtures = [
  'test/fixtures/grammar_examples.yaml',
  'test/fixtures/grammar_examples_verbs.yaml',
];

const _real = [
  'lib/data/latin_nouns.yaml',
  'lib/data/latin_verbs.yaml',
];

/// One set of data files, sampled and compared.
final class _Corpus {
  final Sample sample;
  final List<ItemForms> items;
  final Map<String, Axes> axes;
  final OracleResult result;

  _Corpus(this.sample, this.items, this.axes, this.result);
}

void main() {
  late Collatinus collatinus;
  late MorphMap morphMap;
  late TypeMap typeMap;
  late List<AllowedDiff> allowed;
  late _Corpus fixtures;
  late _Corpus real;
  late List<_Corpus> corpora;
  late OracleResult result;

  setUpAll(() {
    collatinus = Collatinus(collatinusDir);
    morphMap = MorphMap.parse(File('test/oracle/morph_map.yaml').readAsStringSync());
    typeMap = TypeMap.parse(File('test/oracle/type_map.yaml').readAsStringSync());
    allowed = [
      for (final f in ['allowed_diffs', 'allowed_missing'])
        ...AllowedDiff.parse(File('test/oracle/$f.yaml').readAsStringSync()),
    ];
    _Corpus run(List<String> paths, Set<String> coveredTypes) {
      final sample = buildSample(
        sources: {for (final path in paths) path: File(path).readAsStringSync()},
        collatinus: collatinus,
        typeMap: typeMap,
        coveredTypes: coveredTypes,
      );
      final items = engineForms(sample);
      final axes = axesOf(sample.sources);
      return _Corpus(
        sample,
        items,
        axes,
        runOracle(
          items: items,
          axesByFile: axes,
          collatinus: collatinus,
          morphMap: morphMap,
          typeMap: typeMap,
        ),
      );
    }

    fixtures = run(_fixtures, const {});
    real = run(_real, {
      for (final file in parseGrammarFiles(
        {for (final p in _fixtures) p: File(p).readAsStringSync()},
      ))
        ...file.declaredTypes.keys,
    });
    corpora = [fixtures, real];
    result = OracleResult(
      [for (final c in corpora) ...c.result.diffs],
      {
        for (final id in ['nouns', 'verbs'])
          id: corpora.fold(0, (n, c) => n + (c.result.compared[id] ?? 0)),
      },
      {
        for (final c in corpora)
          for (final e in c.result.skippedMorphs.entries) e.key: e.value,
      },
      {},
    );
    File('build/oracle_report.md')
      ..createSync(recursive: true)
      ..writeAsStringSync(oracleReport(result, allowed));
  });

  group('expander goldens', () {
    int morphOf(String text) =>
        collatinus.morphs.entries.firstWhere((e) => e.value.trim() == text).key;

    test('a regular perfect has both 3rd plural endings', () {
      expect(
        collatinus.inflect('ămo')[morphOf('perfect indicative active 3rd plural')],
        ['ămāvērūnt', 'ămāvērĕ'],
      );
    });

    test('a lemma line supplies the perfect radical', () {
      expect(
        collatinus.inflect('vĭdĕo')[morphOf(
          'perfect indicative active 1st singular',
        )],
        ['vīdī'],
      );
    });

    test('a noun builds on radical 1 of its lemma line', () {
      expect(collatinus.inflect('rex')[morphOf('genitive singular')], ['rēgĭs']);
    });

    test('an irregular form replaces the ending of its morph', () {
      expect(
        collatinus.inflect('possŭm')[morphOf(
          'present indicative active 1st singular',
        )],
        ['pōssŭm'],
      );
    });

    test('a deponent files its forms under the active morphs', () {
      // Our post-S10 key is ind.praes.akt.1.sg, and 121 is the morph the
      // mapping turns into exactly that: the deponent needs no special case.
      expect(morphOf('present indicative active 1st singular'), 121);
      expect(collatinus.inflect('hortor')[121], ['hōrtŏr']);
    });
  });

  test('every sampled item has the type its Collatinus model stands for', () {
    // runOracle throws when a model is unknown or stands for another type.
    for (final item in [...fixtures.items, ...real.items]) {
      expect(item.lemmas, isNotEmpty);
    }
  });

  test('no form differs that allowed_diffs.yaml does not list', () {
    final unlisted = result.unlisted(allowed);
    expect(
      unlisted.map((d) => d.signature).toList(),
      isEmpty,
      reason: 'see build/oracle_report.md',
    );
    expect(
      result.stale(allowed).map((a) => a.describe).toList(),
      isEmpty,
      reason: 'allowed_diffs.yaml lists differences that no longer happen',
    );
  });

  test('the sample covers the deponents of section 15', () {
    for (final id in ['hortari', 'pati', 'largiri']) {
      expect(fixtures.items.map((i) => i.id), contains(id));
      expect(
        result.diffs.where(
          (d) => d.item == id && d.category == DiffCategory.form,
        ),
        isEmpty,
        reason: '$id must not need an allowed form diff',
      );
    }
  });

  test('the whole sample is compared', () {
    for (final c in corpora) {
      expect(c.sample.entries.where((e) => e.synthetic), hasLength(greaterThan(100)));
      expect(comparedWholeSample(c.result, c.sample.entries.length), isTrue);
    }
  });

  test('-nt and -nd count as positional length', () {
    // Collatinus marks the vowel before nt/nd long; the school spelling does
    // not, so the pair is the same quantity.
    expect(sameQuantity('amant', 'amānt'), isTrue);
    expect(sameQuantity('amandum', 'amāndum'), isTrue);
  });

  group('the gate is red without its parts', () {
    test('without allowed_missing.yaml, in either direction', () {
      final forms = allowed.where((a) => a.category == DiffCategory.form).toList();
      final unlisted = result.unlisted(forms).map((d) => d.category).toSet();
      expect(unlisted, {DiffCategory.missingOurs, DiffCategory.missingTheirs});
    });

    test('an allowed_missing.yaml entry that matches nothing is stale', () {
      final bogus = AllowedDiff(
        category: DiffCategory.missingOurs,
        keys: ['no.such.key'],
        reason: 'x',
      );
      expect(result.stale([bogus]), [bogus]);
    });

    test('a missing-key entry without keys is refused', () {
      expect(
        () => AllowedDiff.parse('- {direction: ours, item: ire, reason: x}'),
        throwsFormatException,
      );
    });

    test('an entry for one item hides no key of the item it does not name', () {
      final ire = result.diffs.firstWhere(
        (d) => d.category == DiffCategory.missingOurs && d.item == 'ire',
      );
      final other = Diff(
        category: ire.category,
        item: ire.item,
        type: ire.type,
        key: 'ind.fut.akt.1.sg',
        ours: const [],
        theirs: const ['x'],
        synthetic: ire.synthetic,
        deponent: false,
      );
      expect(result.unlisted(allowed).length, 0);
      expect(allowed.any((a) => a.covers(other)), isFalse);
    });

    test('a deponent reason does not cover an item that is not a deponent', () {
      final moved = result.diffs.firstWhere((d) =>
          d.category == DiffCategory.missingOurs &&
          d.key.startsWith('imp.fut.akt.') &&
          d.deponent);
      final active = Diff(
        category: moved.category,
        item: 'amare',
        type: moved.type,
        key: moved.key,
        ours: moved.ours,
        theirs: moved.theirs,
        synthetic: false,
        deponent: false,
      );
      expect(allowed.any((a) => a.covers(moved)), isTrue);
      expect(allowed.any((a) => a.covers(active)), isFalse);
    });

    test('a shrunk or empty sample is not the whole sample', () {
      final items = fixtures.items;
      for (final kept in [items.take(items.length ~/ 2).toList(), <ItemForms>[]]) {
        final shrunk = runOracle(
          items: kept,
          axesByFile: fixtures.axes,
          collatinus: collatinus,
          morphMap: morphMap,
          typeMap: typeMap,
        );
        expect(comparedWholeSample(shrunk, fixtures.sample.entries.length), isFalse);
      }
    });

    test('without allowed_diffs.yaml', () {
      expect(result.unlisted(const []), isNotEmpty);
    });

    test('without the j/i spelling rule', () {
      final diffs = runOracle(
        items: fixtures.items,
        axesByFile: fixtures.axes,
        collatinus: collatinus,
        morphMap: morphMap,
        typeMap: typeMap,
        compare: oracleNorm,
      ).unlisted(allowed);
      // Collatinus writes hūjŭs; we write huius.
      expect(diffs.map((d) => d.item), containsAll(['hic', 'iudicare']));
    });
  });
}
