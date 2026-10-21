import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';

/// Latin items 48..94 of latin_verbs.yaml, counted from 1.
const _firstItem = 48;
const _lastItem = 94;

/// Range items without a resolvable German verb.
const _notDone = <String>{};

/// German verbs of the range without a German passive.
const _withoutGermanPassive = {
  'staunen',
  'schweigen',
  'können',
  'gehen',
  'wollen',
  'nicht wollen',
  'lieber wollen',
  'heranrücken',
  'sich anstrengen',
  'weggehen',
  'zögern',
  'segeln',
};

const _yamlPath = String.fromEnvironment(
  'GERMAN_VERBS_YAML',
  defaultValue: 'lib/data/german_verbs.yaml',
);

bool _inCourse(List<String> codes) => switch (codes.first) {
  'ind' || 'konj' => true,
  'inf' || 'part' => codes[1] == 'praes' || codes[1] == 'perf',
  _ => false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final latinVerbs = parseGrammarFiles({
    for (final path in [
      'lib/data/latin_nouns.yaml',
      'lib/data/latin_verbs.yaml',
    ])
      path: File(path).readAsStringSync(),
  }).singleWhere((f) => f.dataFileId == 'verbs');
  final rangeIds = [
    for (final item in latinVerbs.items.sublist(_firstItem - 1, _lastItem))
      'verbs:${item.id}',
  ];

  test('the range holds ${_lastItem - _firstItem + 1} items', () {
    expect(rangeIds, hasLength(_lastItem - _firstItem + 1));
  });

  test('every item of the range has a German verb or is listed', () {
    final german = GrammarGermanForms(
      File(_yamlPath).readAsStringSync(),
      latinVerbs,
    );
    for (final id in rangeIds) {
      expect(
        german.germanVerbOf.containsKey(id) || _notDone.contains(id),
        isTrue,
        reason: id,
      );
    }
  });

  test('every course form of the range builds German text', () async {
    final german = GrammarGermanForms(
      File(_yamlPath).readAsStringSync(),
      latinVerbs,
    );
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    for (final id in rangeIds.where((id) => !_notDone.contains(id))) {
      final item = items.singleWhere((i) => i.id == id);
      final noPassive = _withoutGermanPassive.contains(german.germanVerbOf[id]);
      for (final key in item.formOrder) {
        final codes = key.split('.');
        if (!_inCourse(codes)) continue;
        final isPassive = codes[2] == 'pass';
        final reason = '$id $key';
        if (isPassive && noPassive) {
          expect(german.covers(item, key), isFalse, reason: reason);
          continue;
        }
        expect(german.covers(item, key), isTrue, reason: reason);
        expect(german.render(item, key), isNotEmpty, reason: reason);
      }
    }
  });
}
