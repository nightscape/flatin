import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/practice_item.dart';

const _rangeStart = 188;
const _rangeEnd = 235;

/// Range items without a German verb.
const _notDone = <String>{};

/// German verbs without a personal passive; their passive keys are absent.
const _withoutGermanPassive = {
  'sich erheben',
  'sich ausdenken',
  'hingelangen',
  'hinausgehen',
  'herankommen',
  'anhalten',
  'wachsen',
  'umherirren',
  'nicht wissen',
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
      if (_notDone.contains(id)) {
        expect(item.deVerb, isNull, reason: id);
      } else {
        expect(german.germanVerbOf.containsKey(id), isTrue, reason: id);
      }
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
      expect(
        text('verbs:pervenire', 'ind.perf.akt.1.sg'),
        'ich bin hingelangt',
      );
      expect(
        text('verbs:crescere', 'ind.perf.akt.3.sg'),
        'er/sie/es ist gewachsen',
      );
    });
    test('separable verb', () {
      expect(
        text('verbs:inicere', 'ind.praes.akt.3.sg'),
        'er/sie/es wirft hinein',
      );
      expect(
        text('verbs:inicere', 'ind.perf.akt.1.sg'),
        'ich habe hineingeworfen',
      );
      expect(
        text('verbs:continere', 'ind.praes.akt.2.sg'),
        'du hältst zusammen',
      );
    });
    test('strong verb', () {
      expect(text('verbs:bibere', 'ind.impf.akt.3.sg'), 'er/sie/es trank');
      expect(
        text('verbs:frangere', 'ind.praes.akt.3.sg'),
        'er/sie/es zerbricht',
      );
      expect(text('verbs:consulere', 'ind.impf.akt.2.sg'), 'du berietest');
    });
    test('dative reflexive', () {
      expect(
        text('verbs:fingere', 'ind.praes.akt.3.sg'),
        'er/sie/es denkt sich aus',
      );
      expect(text('verbs:fingere', 'ind.praes.akt.1.sg'), 'ich denke mir aus');
    });
    test('reflexive and multi-word', () {
      expect(text('verbs:surgere', 'ind.praes.akt.1.sg'), 'ich erhebe mich');
      expect(
        text('verbs:restituere', 'ind.praes.akt.1.sg'),
        'ich stelle wieder her',
      );
      expect(text('verbs:nescire', 'ind.praes.akt.1.sg'), 'ich weiß nicht');
    });
    test('first gloss verb kept without a core-sense match', () {
      expect(text('verbs:habere', 'ind.praes.akt.1.sg'), 'ich habe');
      expect(text('verbs:manere', 'ind.praes.akt.3.sg'), 'er/sie/es bleibt');
      expect(
        text('verbs:respicere', 'ind.praes.akt.1.sg'),
        'ich blicke zurück',
      );
    });
    test('wiederherstellen is one separable verb', () {
      expect(
        text('verbs:restituere', 'ind.praes.akt.3.sg'),
        'er/sie/es stellt wieder her',
      );
      expect(text('verbs:restituere', 'part.perf.pass'), 'wiederhergestellt');
      expect(text('verbs:restituere', 'inf.praes.akt'), 'wiederherstellen');
    });
  });
}
