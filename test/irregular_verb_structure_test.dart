// The irregular verbs spell out their finite paradigm cell by cell, so no rule
// catches a wrong ending. What the irregularity never touches is the
// person/number ending, and pinning it catches a one-person typo.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';

const _verbs = 'lib/data/latin_verbs.yaml';

/// The verb types delegate into the noun file, so both are linked.
const _paths = ['lib/data/latin_nouns.yaml', _verbs];

/// Every verb item that spells out forms of its own.
const _explicitItemCount = 24;

/// The finite active indicative and subjunctive cells among them.
const _finiteActiveCellCount = 694;

/// 1.sg is -ō in the present and -m after a tense vowel.
const _personEndings = {
  '1.sg': ['ō', 'm'],
  '2.sg': ['s'],
  '3.sg': ['t'],
  '1.pl': ['mus'],
  '2.pl': ['tis'],
  '3.pl': ['nt'],
};

/// The perfect indicative carries its own endings. A perfect in -vī contracts
/// (-īvistī → -īstī), so 2.sg and 2.pl are regular in either spelling.
const _perfectEndings = {
  '1.sg': ['ī'],
  '2.sg': ['istī', 'īstī'],
  '3.sg': ['it'],
  '1.pl': ['imus'],
  '2.pl': ['istis', 'īstis'],
  '3.pl': ['ērunt', 'ēre'],
};

final _finiteActive = RegExp(r'^(ind|konj)\.\w+\.akt\.[123]\.(sg|pl)$');

final GrammarEngine _engine = GrammarEngine(
  parseGrammarFiles({
    for (final path in _paths) path: File(path).readAsStringSync(),
  }),
);

typedef _Cell = ({GrammarItem item, String key, List<String> spellings});

void _expectEnding(_Cell cell, Map<String, List<String>> table) {
  final parts = cell.key.split('.');
  final endings = table['${parts[3]}.${parts[4]}']!;
  for (final form in cell.spellings) {
    expect(
      endings.any(form.endsWith),
      isTrue,
      reason:
          '${cell.item.id} ${cell.key}: $form ends in none of '
          '${endings.join(", ")}',
    );
  }
}

void main() {
  final items = _engine.files
      .firstWhere((file) => file.path == _verbs)
      .items
      .where((item) => item.forms.isNotEmpty)
      .toList();

  final cells = <_Cell>[
    for (final item in items)
      for (final entry in item.forms.entries)
        if (_finiteActive.hasMatch(entry.key))
          (item: item, key: entry.key, spellings: entry.value),
  ];

  test('every verb item that spells out forms is covered', () {
    expect(items.map((item) => item.id), hasLength(_explicitItemCount));
    expect(cells, hasLength(_finiteActiveCellCount));
  });

  test(
    'outside the perfect indicative the person endings are the regular ones',
    () {
      for (final cell in cells) {
        if (cell.key.startsWith('ind.perf.')) continue;
        _expectEnding(cell, _personEndings);
      }
    },
  );

  test('the perfect indicative carries the perfect person endings', () {
    for (final cell in cells) {
      if (!cell.key.startsWith('ind.perf.')) continue;
      _expectEnding(cell, _perfectEndings);
    }
  });
}
