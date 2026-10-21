import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/practice_item.dart';

/// German verbs without a personal passive; their passive keys are absent.
const _withoutGermanPassive = {'herabsteigen'};

/// Latin items 95..141 of the verb file.
const _first = 94;
const _end = 141;

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
  final range = latinVerbs.items.sublist(_first, _end);
  final german = GrammarGermanForms(
    File(
      Platform.environment['GERMAN_VERBS_YAML'] ?? 'lib/data/german_verbs.yaml',
    ).readAsStringSync(),
    latinVerbs,
  );

  test('every item of the range names a German verb', () {
    expect(range, hasLength(47));
    for (final item in range) {
      expect(
        german.germanVerbOf.containsKey('verbs:${item.id}'),
        isTrue,
        reason: item.id,
      );
    }
  });

  test('every course form of the range has German text', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final byId = {for (final item in items) item.id: item};
    for (final latin in range) {
      final item = byId['verbs:${latin.id}']!;
      for (final key in item.formOrder) {
        final codes = key.split('.');
        if (!_inCourse(codes)) continue;
        final absent =
            codes[2] == 'pass' && _withoutGermanPassive.contains(latin.deVerb);
        expect(german.covers(item, key), !absent, reason: '${item.id} $key');
        if (!absent) expect(german.render(item, key), isNotEmpty);
      }
    }
  });

  group('risky rows render the expected German', () {
    late List<PracticeItem> items;
    setUpAll(() async {
      items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    });
    String text(String id, String key) =>
        german.render(items.singleWhere((i) => i.id == id), key);

    test('sein-auxiliary perfect', () {
      expect(
        text('verbs:descendere', 'ind.perf.akt.3.sg'),
        'er/sie/es ist herabgestiegen',
      );
    });
    test('separable verb', () {
      expect(
        text('verbs:accipere', 'ind.praes.akt.3.sg'),
        'er/sie/es nimmt an',
      );
      expect(
        text('verbs:accipere', 'ind.perf.akt.1.sg'),
        'ich habe angenommen',
      );
    });
    test('strong verb', () {
      expect(text('verbs:mandare', 'ind.praes.akt.2.sg'), 'du übergibst');
      expect(text('verbs:vetare', 'ind.impf.akt.3.sg'), 'er/sie/es verbot');
    });
  });
}
