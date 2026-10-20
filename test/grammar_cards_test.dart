import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/asset_text.dart';
import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('grammar cards are stored and loaded beside the word cards', () async {
    SharedPreferences.setMockInitialValues({});
    final items = await loadAllPracticeItems();
    final vocare = items.singleWhere((i) => i.id == 'verbs:vocare');
    final bundle = GrammarCardId.of(vocare, 'ind.fut2.pass.3.pl');

    await FsrsStorage.syncCards(items);
    final synced = await FsrsStorage.syncGrammarCards(items);
    final loaded = await FsrsStorage.loadCards();

    expect(synced.keys, contains(PracticeItemCard.generateItemId(vocare)));
    expect(loaded.keys, contains(bundle));
    expect(loaded.keys.toSet(), synced.keys.toSet());
    expect(loaded[bundle]!.itemId, bundle);
    expect(
      loaded.keys.where((k) => k.startsWith('grammar:verbs:')),
      containsAll([
        'grammar:verbs:ind.praes.akt',
        'grammar:verbs:konj.perf.pass',
      ]),
    );
    expect(loaded.keys, contains('grammar:nouns:U-Deklination'));
  });

  test('a second sync keeps the review state of a grammar card', () async {
    SharedPreferences.setMockInitialValues({});
    final items = await loadAllPracticeItems();
    final cards = await FsrsStorage.syncGrammarCards(items);
    final id = 'grammar:verbs:ind.praes.akt';
    final due = DateTime.utc(2030, 1, 1);
    await FsrsStorage.saveCards({...cards, id: cards[id]!.copyWith(due: due)});

    final again = await FsrsStorage.syncGrammarCards(items);

    expect(again[id]!.due, due);
    expect(again.length, cards.length);
  });

  test('bundleOf names every bundle the curriculum names', () async {
    final items = await loadAllPracticeItems();
    final produced = {
      for (final item in items)
        for (final key in item.formOrder) GrammarCardId.of(item, key),
    };
    final named = <GrammarCardId>{};
    for (final asset in curriculumAssets) {
      for (final entry in loadYaml(await loadAssetText(asset)) as YamlList) {
        final verbs = (entry as YamlMap)['verbs'] as YamlMap?;
        for (final form in (verbs?['forms'] as YamlList? ?? const [])) {
          final axes = (form as YamlMap);
          named.add(
            GrammarCardId(
              'verbs',
              [
                for (final axis in ['modus', 'tempus', 'genus_verbi'])
                  if (axes[axis] != null) axes[axis] as String,
              ].join('.'),
            ),
          );
        }
        for (final type
            in ((entry['nouns'] as YamlMap?)?['types'] as YamlList? ??
                const [])) {
          named.add(GrammarCardId('nouns', type as String));
        }
      }
    }

    expect(named.difference(produced), isEmpty);
    expect(produced.where((id) => id.endsWith(':')), isEmpty);
  });
}
