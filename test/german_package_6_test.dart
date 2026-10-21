import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/practice_item.dart';

const _rangeStart = 235;
const _rangeEnd = 277;

/// German verbs without a personal passive; their passive keys are absent.
const _withoutGermanPassive = {
  'sich anstrengen',
  'weggehen',
  'hinausgehen',
  'verzweifeln',
  'nachdenken',
  'bevorstehen',
  'verborgen sein',
  'müssen',
  'nicht haben',
  'schmerz empfinden',
  'stark sein',
  'brennen',
  'liegen',
  'herantreten',
  'widerstand leisten',
  'leben',
  'fallen',
  'stürzen',
  'fliehen',
  'entkommen',
  'zurückkehren',
  'herangehen',
  'zugrunde gehen',
  'abwesend sein',
  'da sein',
  'fehlen',
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
  final german = GrammarGermanForms(
    File(
      Platform.environment['GERMAN_VERBS_YAML'] ?? 'lib/data/german_verbs.yaml',
    ).readAsStringSync(),
    latinVerbs,
  );

  test('every item of the range has a German verb or is listed', () {
    final range = latinVerbs.items.sublist(_rangeStart, _rangeEnd);
    expect(range, hasLength(_rangeEnd - _rangeStart));
    for (final item in range) {
      final id = 'verbs:${item.id}';
      expect(german.germanVerbOf.containsKey(id), isTrue, reason: id);
    }
  });

  test('every course form of the range builds its German text', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final reference = items.singleWhere((i) => i.id == 'verbs:amare');
    for (final item in items.sublist(_rangeStart, _rangeEnd)) {
      final germanId = german.germanVerbOf[item.id];
      if (germanId == null) continue;
      for (final key in item.formOrder) {
        final group = key.split('.').first;
        if (!{'ind', 'konj', 'inf', 'part'}.contains(group)) continue;
        final withoutPassive =
            _withoutGermanPassive.contains(germanId) &&
            key.split('.')[2] == 'pass';
        expect(
          german.covers(item, key),
          !withoutPassive && german.covers(reference, key),
          reason: '${item.id} $germanId $key',
        );
        if (german.covers(item, key)) {
          expect(german.render(item, key), isNotEmpty);
        }
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
      expect(text('verbs:fugere', 'ind.perf.akt.1.sg'), 'ich bin geflohen');
      expect(
        text('verbs:cadere', 'ind.perf.akt.3.sg'),
        'er/sie/es ist gefallen',
      );
    });
    test('separable verb', () {
      expect(
        text('verbs:cogitare', 'ind.praes.akt.3.sg'),
        'er/sie/es denkt nach',
      );
      expect(
        text('verbs:cogitare', 'ind.perf.akt.1.sg'),
        'ich habe nachgedacht',
      );
      expect(text('verbs:accedere', 'ind.praes.akt.2.sg'), 'du trittst heran');
    });
    test('strong verb', () {
      expect(text('verbs:iacere', 'ind.impf.akt.3.sg'), 'er/sie/es lag');
      expect(text('verbs:cadere', 'ind.praes.akt.2.sg'), 'du fällst');
    });
    test('dental e-insertion', () {
      expect(text('verbs:finire', 'ind.impf.akt.1.sg'), 'ich beendete');
      expect(
        text('verbs:dolere', 'ind.praes.akt.2.sg'),
        'du empfindest Schmerz',
      );
    });
    test('multi-word', () {
      expect(text('verbs:ignorare', 'ind.praes.akt.1.sg'), 'ich kenne nicht');
      expect(text('verbs:latere', 'ind.praes.akt.1.sg'), 'ich bin verborgen');
      expect(
        text('verbs:perire', 'ind.perf.akt.1.sg'),
        'ich bin zugrunde gegangen',
      );
    });
  });
}
