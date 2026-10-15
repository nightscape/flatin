/// The oracle (plan 5.3): our forms against the Collatinus data.
///
/// Skipped by default because the data is not in the repo. Run it with
///   tool/oracle/fetch_collatinus.sh && flutter test --tags oracle --run-skipped
@Tags(['oracle'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/form_label.dart';

import 'collatinus.dart';
import 'oracle.dart';

/// Our forms, until L1 lets the oracle read the engine.
List<ItemForms> _ourForms() {
  final root =
      jsonDecode(File('test/oracle/paradigms.json').readAsStringSync())
          as Map<String, dynamic>;
  return [
    for (final item in root['items'] as List)
      ItemForms(
        dataFileId: item['file'] as String,
        id: item['id'] as String,
        type: item['type'] as String,
        emitted: {
          for (final e in (item['forms'] as Map).entries)
            e.key as FormKey: (e.value as String).split('|'),
        },
        internal: {
          for (final e in (item['internal'] as Map).entries)
            e.key as FormKey: (e.value as String).split('|'),
        },
      ),
  ];
}

void main() {
  late Collatinus collatinus;
  late MorphMap morphMap;
  late TypeMap typeMap;
  late List<AllowedDiff> allowed;
  late List<ItemForms> items;
  late Map<String, Axes> axesByFile;
  late OracleResult result;

  setUpAll(() {
    collatinus = Collatinus(collatinusDir);
    morphMap = MorphMap.parse(File('test/oracle/morph_map.yaml').readAsStringSync());
    typeMap = TypeMap.parse(File('test/oracle/type_map.yaml').readAsStringSync());
    allowed = AllowedDiff.parse(
      File('test/oracle/allowed_diffs.yaml').readAsStringSync(),
    );
    items = _ourForms();
    axesByFile = {
      for (final file in parseGrammarFiles({
        for (final path in [
          'test/fixtures/grammar_examples.yaml',
          'test/fixtures/grammar_examples_verbs.yaml',
        ])
          path: File(path).readAsStringSync(),
      }))
        file.dataFileId: file.axes,
    };
    result = runOracle(
      items: items,
      axesByFile: axesByFile,
      collatinus: collatinus,
      morphMap: morphMap,
      typeMap: typeMap,
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
    for (final item in items) {
      expect(typeMap.sample[item.dataFileId]?[item.id], isNotNull,
          reason: '${item.id} is in paradigms.json but not in type_map.yaml');
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
      result.stale(allowed).map((a) => a.signature).toList(),
      isEmpty,
      reason: 'allowed_diffs.yaml lists differences that no longer happen',
    );
  });

  test('the sample covers the deponents of section 15', () {
    for (final id in ['hortari', 'pati', 'largiri']) {
      expect(items.map((i) => i.id), contains(id));
      expect(
        result.diffs.where(
          (d) => d.item == id && d.category == DiffCategory.form,
        ),
        isEmpty,
        reason: '$id must not need an allowed form diff',
      );
    }
  });

  group('the gate is red without its parts', () {
    test('without allowed_diffs.yaml', () {
      expect(result.unlisted(const []), isNotEmpty);
    });

    test('without the j/i spelling rule', () {
      final diffs = runOracle(
        items: items,
        axesByFile: axesByFile,
        collatinus: collatinus,
        morphMap: morphMap,
        typeMap: typeMap,
        compare: oracleNorm,
      ).unlisted(allowed);
      // Collatinus writes hūjŭs; we write huius.
      expect(diffs.map((d) => d.item).toSet(), {'hic'});
    });
  });
}
