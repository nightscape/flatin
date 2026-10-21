import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';

const _rangeSize = 47;

/// Range items without a German verb: none.
const _notDone = <String>{};

/// German verbs without a personal passive; their passive keys are absent.
const _withoutGermanPassive = {
  'kommen',
  'wissen',
  'sein',
  'sich freuen',
  'arbeiten',
  'erscheinen',
  'gehen',
  'sich nähern',
  'zögern',
  'zusammenkommen',
  'sorgen',
  'speisen',
  'schlafen',
  'gefallen',
  'eilen',
  'gehorchen',
  'kämpfen',
  'lachen',
  'sitzen',
  'könig sein',
  'dienen',
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
    final range = latinVerbs.items.take(_rangeSize).toList();
    expect(range, hasLength(_rangeSize));
    for (final item in range) {
      final id = 'verbs:${item.id}';
      expect(
        german.germanVerbOf.containsKey(id) || _notDone.contains(id),
        isTrue,
        reason: id,
      );
    }
  });

  test('every course form of the range builds its German text', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final reference = items.singleWhere((i) => i.id == 'verbs:amare');
    for (final item in items.take(_rangeSize)) {
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

  test('erwidern keeps the infinitive in the plural present', () async {
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final item = items.singleWhere((i) => i.id == 'verbs:respondere');
    expect(german.render(item, 'ind.praes.akt.1.pl'), 'wir erwidern');
    expect(german.render(item, 'ind.praes.akt.3.pl'), 'sie (Pl.) erwidern');
  });
}
