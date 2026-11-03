import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_card_store.dart';
import 'support/gen_settings.dart';

const _dir = 'test/fixtures/guard';
const _cases = 20;

/// The stored states: each `<name>.stored.json` holds the stored value of
/// its key, and `<name>.saved.json` the value the app writes after loading
/// it. Every card store holds a card for each card id of the course, so
/// loading creates no card and reads no clock; `cards_orphans` also holds
/// cards whose ids the course no longer derives. Update the saved values with
/// `flutter test --update-goldens test/guard_stored_data_test.dart`.
const _states = {
  'settings_default': _settingsKey,
  'settings_drawn': _settingsKey,
  'settings_sparse': _settingsKey,
  'cards_reviewed': _cardsKey,
  'cards_synced': _cardsKey,
  'cards_orphans': _cardsKey,
};

const _settingsKey = 'practice_settings';
const _cardsKey = 'fsrs_cards';

/// The value of [key] that the app stores after it loads [stored] and saves.
/// The settings are saved through the notifier with one value set to what
/// it already is; the cards as a review saves them.
Future<String> _loadAndSave(String key, String stored) async {
  SharedPreferences.setMockInitialValues({key: stored});
  final c = ProviderContainer(retry: noRetry);
  if (key == _settingsKey) {
    final settings = await c.read(settingsProvider.future);
    await c
        .read(settingsProvider.notifier)
        .setRewardAnimation(settings.rewardAnimation);
  } else {
    await FsrsStorage.saveCards(await c.read(fsrsCardsProvider.future));
  }
  c.dispose();
  return (await SharedPreferences.getInstance()).getString(key)!;
}

Future<String> _storedCards(Map<String, PracticeItemCard> cards) async {
  SharedPreferences.setMockInitialValues({});
  await FsrsStorage.saveCards(cards);
  return (await SharedPreferences.getInstance()).getString(_cardsKey)!;
}

const _overrides = [
  'disabledForms',
  'forcedOnForms',
  'disabledTypes',
  'forcedOnTypes',
  'disabledFeatures',
  'deselectedWords',
  'forcedOnWords',
  'deselectedTopics',
  'forcedOnTopics',
];

/// What the first save of [stored] must keep: every stored card, and every
/// stored override of the learner, unchanged.
Map<String, String> _kept(String key, String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  return key == _cardsKey
      ? {
          for (final c in map['cards'] as List<dynamic>)
            (c as Map<String, dynamic>)['itemId'] as String: jsonEncode(c),
        }
      : {
          for (final o in _overrides)
            if (map.containsKey(o)) o: jsonEncode(map[o]),
        };
}

String _read(String name, String kind) =>
    File('$_dir/$name.$kind.json').readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final MapEntry(key: name, value: key) in _states.entries) {
    // An example test: it pins the format of the stored data, whose old
    // files no generator reproduces once the format changes.
    test(
      'loading and saving $name writes the saved golden byte for byte',
      () async {
        final saved = await _loadAndSave(key, _read(name, 'stored'));
        if (autoUpdateGoldenFiles) {
          File('$_dir/$name.saved.json').writeAsStringSync(saved);
        }
        expect(saved, _read(name, 'saved'));
      },
    );
  }

  // An example test: a card whose item left the course is review history
  // that the stored states above do not hold.
  test('loading and saving keeps a card whose item the course no longer '
      'derives', () async {
    final stored =
        jsonDecode(_read('cards_reviewed', 'stored')) as Map<String, dynamic>;
    final cards = stored['cards'] as List<dynamic>;
    cards.add({...cards.first as Map<String, dynamic>, 'itemId': 'nouns:gone'});
    final saved =
        jsonDecode(await _loadAndSave(_cardsKey, jsonEncode(stored)))
            as Map<String, dynamic>;
    expect([
      for (final c in saved['cards'] as List<dynamic>)
        (c as Map<String, dynamic>)['itemId'],
    ], contains('nouns:gone'));
  });

  test('loading and saving is a fixpoint after the first save, and the '
      'first save keeps every stored card and override, for the stored '
      'states and for drawn settings and card stores', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(retry: noRetry);
    addTearDown(c.dispose);
    final fresh = await c.read(fsrsCardsProvider.future);
    final universes = universesOf(await loadAllPracticeItems(), {
      for (final t in (await loadCurriculum(bookAssets)).courseTopics) t.key,
    });
    final now = DateTime.now().toUtc();

    final cases = [
      for (final MapEntry(key: name, value: key) in _states.entries)
        (name, key, _read(name, 'stored')),
    ];
    for (var seed = 1; seed <= _cases; seed++) {
      final rng = Random(seed);
      final u = rng.nextBool() ? withOrphans(universes) : universes;
      cases.add((
        'seed $seed settings',
        _settingsKey,
        jsonEncode(
          drawStoredSettings(
            rng,
            types: u.types,
            forms: u.forms,
            features: u.features,
            words: u.words,
            topics: u.topics,
          ),
        ),
      ));
      cases.add((
        'seed $seed cards',
        _cardsKey,
        await _storedCards(
          drawCardStore(
            rng,
            fresh,
            now,
            absent: rng.nextBool() ? 0 : rng.nextDouble(),
            orphans: rng.nextBool() ? 0 : 1 + rng.nextInt(5),
          ).cards,
        ),
      ));
    }
    for (final (name, key, stored) in cases) {
      final once = await _loadAndSave(key, stored);
      final kept = _kept(key, once);
      final before = _kept(key, stored);
      expect({for (final k in before.keys) k: kept[k]}, before, reason: name);
      expect(await _loadAndSave(key, once), once, reason: name);
    }
  });
}
