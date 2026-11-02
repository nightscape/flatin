import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/providers/exam_provider.dart';

import 'support/gen_card_store.dart';

const _cases = 400;

const _wordIds = [
  'nouns:hortus',
  'nouns:rosa',
  'verbs:laudare',
  'verbs:spectare',
  'vocab:et',
];
const _grammarIds = ['grammar:nouns:o.m.sg', 'grammar:verbs:ind.praes.akt'];

/// The cards as synced: new and due now.
Map<String, PracticeItemCard> _fresh(DateTime now) => {
  for (final id in [..._wordIds, ..._grammarIds])
    id: PracticeItemCard(
      itemId: id,
      card: Card(cardId: id.hashCode),
      due: now,
    ),
};

DateTime _startOfTomorrow(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1).toUtc();
}

void main() {
  test('[E] the helped words are due by tomorrow as normal word cards, and '
      'no other card or field changes', () {
    final now = DateTime.now().toUtc();
    final cases = <(String, Map<String, PracticeItemCard>, Set<String>)>[
      ('nothing helped', _fresh(now), {}),
      ('every word helped', _fresh(now), {..._wordIds}),
    ];
    for (var seed = 1; seed <= _cases; seed++) {
      final rng = Random(seed);
      cases.add((
        'seed $seed',
        drawCardStore(rng, _fresh(now), now).cards,
        {
          for (final id in _wordIds)
            if (rng.nextBool()) id,
        },
      ));
    }
    for (final (name, cards, helped) in cases) {
      final tomorrow = _startOfTomorrow(now);
      final queued = queueHelpedWords(cards, helped, now);
      expect(queued.keys.toSet(), cards.keys.toSet(), reason: name);
      for (final MapEntry(key: id, value: before) in cards.entries) {
        final after = queued[id]!;
        if (!helped.contains(id)) {
          expect(after, same(before), reason: '$name: $id is untouched');
          continue;
        }
        expect(after.itemId, before.itemId, reason: name);
        expect(after.card, same(before.card), reason: name);
        expect(after.lastReview, before.lastReview, reason: name);
        expect(
          after.due,
          before.due.isAfter(tomorrow) ? tomorrow : before.due,
          reason: '$name: $id is due by tomorrow, never later than before',
        );
      }
    }
  });
}
