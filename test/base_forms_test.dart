import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/grammar_start_screen.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/services/reward_storage.dart';

import 'support/course_providers.dart';
import 'support/word_classification_harness.dart';

List<String> _baseForms(PracticeItem item) => [
  for (final key in item.baseFormKeys) item.forms[item.formOrder.indexOf(key)],
];

Future<void> _pumpLarge(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1200, 12000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapInApp(screen, forcedLocale: const Locale('de')));
  await letItLoad(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PracticeItem> all;
  late GrammarEngine engine;
  late GrammarFile verbsFile;
  late Map<String, List<EndingSet>> endings;
  PracticeItem word(String id) => all.singleWhere((i) => i.id == id);

  setUpAll(() async {
    all = await loadAllPracticeItems();
    engine = GrammarEngine(
      parseGrammarFiles({
        for (final f in ['latin_nouns', 'latin_verbs'])
          'lib/data/$f.yaml': File('lib/data/$f.yaml').readAsStringSync(),
      }),
    );
    verbsFile = await loadGrammarFile('verbs');
    endings = endingSetsOf(engine, verbsFile);
  });

  FollowContext contextOf(String id, [Set<FormKey>? available]) {
    final forms = engine.of('verbs', id).forms;
    return FollowContext(
      forms,
      engine.regularOf('verbs', id)?.forms ?? const {},
      verbsFile.item(id).impersonalPassive,
      endings,
      available ?? forms.keys.toSet(),
    );
  }

  FormDerivation given(FormKey key, String spelling) =>
      GivenForm(formKey: key, variants: [spelling]);

  FollowContext made(
    Map<FormKey, String> forms,
    Map<FormKey, String> regular,
    Map<String, List<EndingSet>> sets,
  ) => FollowContext(
    {for (final e in forms.entries) e.key: given(e.key, e.value)},
    {for (final e in regular.entries) e.key: given(e.key, e.value)},
    true,
    sets,
    forms.keys.toSet(),
  );

  bool dropsBy(FollowRule rule, FormKey key, FollowContext context) {
    final follow = rule(key, context);
    return follow != null &&
        listEquals(follow.gives, context.forms[key]!.variants);
  }

  test('a regular noun asks the genitive', () {
    expect(_baseForms(word('nouns:rex')), ['rēgis']);
    expect(_baseForms(word('nouns:amicus')), ['amīcī']);
    expect(_baseForms(word('nouns:canis')), ['canis']);
  });

  test('a regular verb asks its principal parts, derived or given', () {
    expect(_baseForms(word('verbs:amare')), ['amō', 'amāvī', 'amātum']);
  });

  test('an adjective asks its other genders', () {
    expect(_baseForms(word('nouns:acer')), ['ācris', 'ācre']);
  });

  test('ferre asks its principal parts, then every listed form the '
      'consonant conjugation writes otherwise', () {
    final ferre = word('verbs:ferre');
    expect(_baseForms(ferre).take(6), [
      'ferō',
      'tulī',
      'lātum',
      'ferēns',
      'ferentis',
      'ferendus',
    ]);
    expect(
      _baseForms(ferre),
      containsAll(['fers', 'fert', 'fertis', 'fer', 'ferrī']),
    );
    expect(
      ferre.baseFormKeys,
      isNot(
        anyOf(contains('ind.praes.akt.1.pl'), contains('ind.praes.akt.3.pl')),
      ),
    );
    expect(ferre.baseFormKeys, isNot(contains('inf.praes.akt')));
  });

  test('a regular reading drops the listed forms its type writes the same', () {
    expect(
      word('verbs:velle').baseFormKeys,
      isNot(contains('ind.praes.akt.3.pl')),
    );
    expect(_baseForms(word('verbs:ire')), isNot(contains('īmus')));
    expect(_baseForms(word('verbs:ire')), contains('eunt'));
  });

  test('ire asks no impersonal passive its supine gives', () {
    expect(
      word('verbs:ire').baseFormKeys,
      isNot(
        anyOf(
          contains('ind.perf.pass.3.sg'),
          contains('ind.plusq.pass.3.sg'),
          contains('ind.fut2.pass.3.sg'),
          contains('konj.perf.pass.3.sg'),
          contains('konj.plusq.pass.3.sg'),
        ),
      ),
    );
  });

  test('a gerund follows from the gerundive and is not asked', () {
    for (final id in ['verbs:ire', 'verbs:abire', 'verbs:inire']) {
      expect(_baseForms(word(id)), contains(endsWith('undus')), reason: id);
      expect(
        word(id).baseFormKeys.where((key) => key.startsWith('ger.')),
        isEmpty,
        reason: id,
      );
    }
  });

  test('the regular reading of an impersonal verb is impersonal too', () {
    final engine = GrammarEngine(
      parseGrammarFiles({
        for (final f in ['latin_nouns', 'latin_verbs'])
          'lib/data/$f.yaml': File('lib/data/$f.yaml').readAsStringSync(),
      }),
    );
    final regular = engine.regularOf('verbs', 'ire')!.forms;
    expect(regular['ind.perf.pass.3.sg']!.variants, ['itum est']);
  });

  test('regular_passiv is no item key', () {
    final verbs = File('lib/data/latin_verbs.yaml').readAsStringSync();
    expect(
      () => parseGrammarFiles({
        'lib/data/latin_nouns.yaml': File(
          'lib/data/latin_nouns.yaml',
        ).readAsStringSync(),
        'lib/data/latin_verbs.yaml': verbs.replaceFirst(
          '    regular_type: I-Konjugation\n    passiv:',
          '    regular_type: I-Konjugation\n    regular_passiv:',
        ),
      }),
      throwsA(
        isA<SchemaError>()
            .having((e) => e.rule, 'rule', 'file')
            .having((e) => e.toString(), 'message', contains('regular_passiv')),
      ),
    );
  });

  test('esse asks its principal parts, then the forms no rule gives', () {
    final esse = word('verbs:esse');
    expect(_baseForms(esse).take(3), ['sum', 'fuī', 'futūrus']);
    expect(_baseForms(esse), containsAll(['eram', 'erō', 'sim', 'essem']));
    expect(esse.baseFormKeys, isNot(contains('inf.praes.akt')));
  });

  test('rule 1 gives ībant from ībam, but not eunt from eō', () {
    final ire = contextOf('ire');
    expect(
      followByFirstPerson('ind.impf.akt.3.pl', ire)!.source,
      'ind.impf.akt.1.sg',
    );
    expect(dropsBy(followByFirstPerson, 'ind.impf.akt.3.pl', ire), isTrue);
    expect(dropsBy(followByFirstPerson, 'ind.praes.akt.3.pl', ire), isFalse);
    expect(word('verbs:ire').baseFormKeys, contains('ind.praes.akt.3.pl'));
  });

  test('rule 1 gives nothing when two ending sets fit the first person', () {
    final key = 'ind.fut.akt';
    final forms = {'$key.1.sg': 'amābō', '$key.3.sg': 'amābit'};
    final one = <EndingSet>[
      {'3.sg': ('ō', 'it')},
    ];
    final two = [
      ...one,
      {'3.sg': ('bō', 'bat')},
    ];
    expect(
      followByFirstPerson('$key.3.sg', made(forms, {}, {key: one}))!.source,
      '$key.1.sg',
    );
    expect(
      followByFirstPerson('$key.3.sg', made(forms, {}, {key: two})),
      isNull,
    );
  });

  test(
    'rule 1 drops nothing the single fitting ending set spells otherwise',
    () {
      final context = made(
        {'ind.praes.akt.1.sg': 'eō', 'ind.praes.akt.2.sg': 'īs'},
        {},
        {
          'ind.praes.akt': [
            {'2.sg': ('ō', 'is')},
          ],
        },
      );
      expect(followByFirstPerson('ind.praes.akt.2.sg', context)!.gives, [
        'eis',
      ]);
      expect(
        dropsBy(followByFirstPerson, 'ind.praes.akt.2.sg', context),
        isFalse,
      );
    },
  );

  test('rule 1 reads only an available first person', () {
    final ire = contextOf('ire', {'ind.impf.akt.3.pl'});
    expect(followByFirstPerson('ind.impf.akt.3.pl', ire), isNull);
  });

  test('rule 2 gives ferrent from ferre, but not a form spelled otherwise', () {
    expect(
      dropsBy(
        followByImperfectSubjunctive,
        'konj.impf.akt.3.pl',
        contextOf('ferre', {'inf.praes.akt'}),
      ),
      isTrue,
    );
    final other = made(
      {'inf.praes.akt': 'ferre', 'konj.impf.akt.3.pl': 'ferant'},
      {'inf.praes.akt': 'ferere', 'konj.impf.akt.3.pl': 'fererent'},
      {},
    );
    expect(
      dropsBy(followByImperfectSubjunctive, 'konj.impf.akt.3.pl', other),
      isFalse,
    );
  });

  test('rule 3 gives īssent from īsse, but not a form spelled otherwise', () {
    final ire = contextOf('ire', {'inf.perf.akt'});
    expect(
      dropsBy(followByPluperfectSubjunctive, 'konj.plusq.akt.3.pl', ire),
      isTrue,
    );
    final other = made(
      {'inf.perf.akt': 'īsse', 'konj.plusq.akt.3.pl': 'īvissent'},
      {'inf.perf.akt': 'audīvisse', 'konj.plusq.akt.3.pl': 'audīvissent'},
      {},
    );
    expect(
      dropsBy(followByPluperfectSubjunctive, 'konj.plusq.akt.3.pl', other),
      isFalse,
    );
  });

  test('rule 4 gives ībātur from ībat, but not itum est from iit', () {
    final ire = contextOf('ire');
    expect(
      dropsBy(followByImpersonalPassive, 'ind.impf.pass.3.sg', ire),
      isTrue,
    );
    expect(
      dropsBy(followByImpersonalPassive, 'ind.perf.pass.3.sg', ire),
      isFalse,
    );
  });

  test(
    'rule 4 drops nothing the single fitting ending set spells otherwise',
    () {
      final context = made(
        {'ind.fut.akt.3.sg': 'it', 'ind.fut.pass.3.sg': 'ītur'},
        {},
        {
          'ind.fut.impersonal': [
            {'3.sg': ('', 'ur')},
          ],
        },
      );
      expect(followByImpersonalPassive('ind.fut.pass.3.sg', context)!.gives, [
        'itur',
      ]);
      expect(
        dropsBy(followByImpersonalPassive, 'ind.fut.pass.3.sg', context),
        isFalse,
      );
    },
  );

  test('rule 4 drops no passive of a verb without the impersonal passive', () {
    expect(word('verbs:ferre').baseFormKeys, contains('ind.praes.pass.3.sg'));
  });

  test('no rule gives the present of esse or posse', () {
    for (final id in ['esse', 'posse']) {
      for (final tense in ['ind.praes.akt', 'konj.praes.akt']) {
        for (final person in ['2.sg', '3.sg', '1.pl', '2.pl', '3.pl']) {
          expect(
            followedFrom('$tense.$person', contextOf(id)),
            isNull,
            reason: '$id $tense.$person',
          );
        }
      }
    }
    final esse = word('verbs:esse').baseFormKeys;
    for (final person in ['1.sg', '2.sg', '3.sg', '1.pl', '2.pl', '3.pl']) {
      expect(esse, contains('ind.praes.akt.$person'), reason: person);
    }
  });

  test('a dropped form leads back to an asked or shown form', () {
    final lost = <String>[];
    final paths = <String, List<FormKey>>{};
    for (final item in verbsFile.items) {
      final derivation = engine.of('verbs', item.id);
      final regular = engine.regularOf('verbs', item.id);
      final before = baseFormKeysBeforeRules(
        verbsFile,
        item,
        derivation,
        regular,
      );
      final roots = {...word('verbs:${item.id}').baseFormKeys, 'inf.praes.akt'};
      final source = <FormKey, FormKey>{};
      var changed = true;
      while (changed) {
        changed = false;
        final context = FollowContext(
          derivation.forms,
          regular?.forms ?? const {},
          item.impersonalPassive,
          endings,
          {...roots, ...source.keys},
        );
        for (final key in before.where((k) => !roots.contains(k))) {
          if (source.containsKey(key)) continue;
          for (final rule in followRules) {
            final follow = rule(key, context);
            if (follow != null &&
                listEquals(follow.gives, derivation.forms[key]!.variants)) {
              source[key] = follow.source;
              changed = true;
              break;
            }
          }
        }
      }
      for (final key in before.where((k) => !roots.contains(k))) {
        if (!source.containsKey(key)) {
          lost.add('${item.id} $key ${derivation.forms[key]!.result}');
          continue;
        }
        final path = [key];
        while (!roots.contains(path.last)) {
          path.add(source[path.last]!);
        }
        paths['${item.id} $key'] = path;
      }
    }
    expect(lost, isEmpty);
    expect(paths['ire ind.impf.pass.3.sg'], [
      'ind.impf.pass.3.sg',
      'ind.impf.akt.3.sg',
      'ind.impf.akt.1.sg',
    ]);
  });

  test('a non-focus round of ire still asks the forms the focus drops', () {
    final ire = word('verbs:ire');
    final every = ire.formOrder.toSet();
    expect(ire.filterForms(every).keys, contains('ind.impf.akt.3.pl'));
    expect(askedBaseForms(ire, every), isNot(contains('ind.impf.akt.3.pl')));
  });

  test('ire and its compounds ask at most 14 forms', () {
    expect(word('verbs:ire').baseFormKeys, hasLength(14));
    expect(word('verbs:abire').baseFormKeys, hasLength(13));
  });

  Future<void> expectGolden(
    String name,
    bool Function(GrammarItem) selects,
  ) async {
    final verbs = await loadGrammarFile('verbs');
    final rows = <String>['| verb | key | asked form |', '| --- | --- | --- |'];
    for (final item in verbs.items.where(selects)) {
      final verb = word('verbs:${item.id}');
      for (final key in verb.baseFormKeys) {
        rows.add(
          '| ${item.lemma} (${item.regularType ?? item.typeName}) | $key '
          '| ${verb.forms[verb.formOrder.indexOf(key)]} |',
        );
      }
    }
    final table = '${rows.join('\n')}\n';
    final golden = File('test/golden/$name.md');
    if (Platform.environment['BASE_FORMS_GOLDEN_UPDATE'] == '1') {
      golden.writeAsStringSync(table);
    }
    expect(table, golden.readAsStringSync());
  }

  test(
    'the verbs with a regular reading ask the forms of the golden',
    () => expectGolden('base_forms_regular', (i) => i.regularType != null),
  );

  test(
    'the irregular verbs without a regular reading ask the forms of the golden',
    () => expectGolden(
      'base_forms_irregular',
      (i) => i.regularType == null && irregularVerbTypes.contains(i.typeName),
    ),
  );

  test('every noun and verb has a base form besides its lemma', () {
    expect([
      for (final item in all)
        if (!item.isVocab && item.baseFormKeys.isEmpty) item.id,
    ], isEmpty);
  });

  test('a base form a principal part gives pays coins only when the part is '
      'asked', () {
    final amare = word('verbs:amare');
    expect(paysCoins(amare, 'sup.akk'), isFalse);
    expect(paysCoins(amare, 'sup.akk', const BaseForms()), isTrue);
  });

  test('a base form spelled like the lemma pays coins in the base forms '
      'focus only', () {
    for (final id in ['nouns:canis', 'nouns:manus']) {
      expect(paysCoins(word(id), 'gen.sg'), isFalse, reason: id);
      expect(paysCoins(word(id), 'gen.sg', const BaseForms()), isTrue);
    }
  });

  test('a noun has its genus, a common noun two, a verb none', () {
    expect(word('nouns:rex').genus, ['m']);
    expect(word('nouns:arbor').genus, ['f']);
    expect(word('nouns:templum').genus, ['n']);
    expect(word('nouns:custos').genus, ['m', 'f']);
    expect(word('nouns:acer').genus, isEmpty);
    expect(word('verbs:amare').genus, isEmpty);
  });

  test('a noun without a genus, or with two sources of it, fails the load', () {
    final nouns = File('lib/data/latin_nouns.yaml').readAsStringSync();
    final verbs = File('lib/data/latin_verbs.yaml').readAsStringSync();
    void loads(String nounSource) => parseGrammarFiles({
      'lib/data/latin_nouns.yaml': nounSource,
      'lib/data/latin_verbs.yaml': verbs,
    });
    const rex = 'parts: {nom: "rēx", gen: "rēgis"}\n    genus: m\n';
    expect(nouns, contains(rex));
    expect(
      () =>
          loads(nouns.replaceFirst(rex, 'parts: {nom: "rēx", gen: "rēgis"}\n')),
      throwsA(isA<SchemaError>().having((e) => e.rule, 'rule', 'S26')),
    );
    const templum = 'parts: {nom: "templum"}\n';
    expect(nouns, contains(templum));
    expect(
      () => loads(nouns.replaceFirst(templum, '$templum    genus: n\n')),
      throwsA(isA<SchemaError>().having((e) => e.rule, 'rule', 'S26')),
    );
  });

  test('at every course position, every word the focus offers has a base '
      'form to ask or a genus', () async {
    for (var to = 1; to <= laterLesson; to++) {
      seedSettings(Settings(courseWords: LessonRange(1, to)));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final filter = await container.read(courseFilterProvider.future);
      final practicable = await container.read(
        practicableItemsByTypeProvider.future,
      );
      final offered = [
        for (final words in practicable.values)
          for (final word in words)
            if (const BaseForms().offers(word, filter)) word,
      ];
      expect(offered, isNotEmpty, reason: 'lessons 1..$to');
      expect(
        [
          for (final word in offered)
            if (word.genus.isEmpty &&
                askedBaseForms(
                  word,
                  filter.practicedForms(word.dataFileId, word.formLabels),
                ).isEmpty)
              word.id,
        ],
        isEmpty,
        reason: 'lessons 1..$to',
      );
    }
  });

  test('vocab items load with no base forms, and the focus offers none of '
      'them', () async {
    seedSettings(Settings(courseWords: LessonRange.full));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final filter = await container.read(courseFilterProvider.future);
    final vocab = all.where((w) => w.isVocab).toList();
    expect(vocab, isNotEmpty);
    for (final word in vocab) {
      expect(word.baseFormKeys, isEmpty, reason: word.id);
      expect(const BaseForms().includes(word), isFalse, reason: word.id);
      expect(const BaseForms().offers(word, filter), isFalse, reason: word.id);
    }
  });

  Future<Finder> verbsButtonInBaseForms(WidgetTester tester, int to) async {
    seedSettings(Settings(courseWords: LessonRange(1, to)));
    await _pumpLarge(tester, const HomeScreen());
    await tester.tap(find.byKey(const Key('focus.picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nur Stammformen').last);
    await tester.pumpAndSettle();
    return find.byKey(const Key('home.verbs.button'));
  }

  testWidgets('at lesson 1, whose verbs have no base form in range, the '
      'verbs button of the base forms focus is off', (tester) async {
    final button = await verbsButtonInBaseForms(tester, 1);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
  });

  testWidgets('from lesson 4 on the verbs button opens a verb with a base '
      'form to ask', (tester) async {
    await tester.tap(await verbsButtonInBaseForms(tester, 4));
    await letItLoad(tester);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('the home screen offers the base forms focus and opens the '
      'practice with it; the grammar start does not', (tester) async {
    seedSettings(Settings());
    await _pumpLarge(tester, const GrammarStartScreen());
    expect(find.byKey(const Key('focus.option.baseForms')), findsNothing);

    await _pumpLarge(tester, const HomeScreen());
    await tester.tap(find.byKey(const Key('focus.picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nur Stammformen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home.verbs.button')));
    await letItLoad(tester);
    expect(
      tester.widget<PracticeScreen>(find.byType(PracticeScreen)).focus,
      const BaseForms(),
    );
  });

  testWidgets('the base forms practice shows lemma and meaning, asks the '
      'base forms and pays for each right one', (tester) async {
    seedSettings(Settings());
    final rex = word('nouns:rex');
    await _pumpLarge(
      tester,
      PracticeScreen(item: rex, focus: const BaseForms()),
    );

    expect(find.text('rēx'), findsOneWidget);
    expect(find.byKey(const Key('practice.translation.shown')), findsOneWidget);
    expect(find.text('der König'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rēgis');
    await tester.tap(find.byKey(const Key('practice.genus.m')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('practice.check.button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('practice.genus.answer')), findsOneWidget);
    expect((await tester.runAsync(RewardStorage.load))!.earnedOf(coins), 6);
  });

  testWidgets('a wrong genus pays nothing and rates the card down', (
    tester,
  ) async {
    seedSettings(Settings());
    await _pumpLarge(
      tester,
      PracticeScreen(item: word('nouns:rex'), focus: const BaseForms()),
    );
    await tester.enterText(find.byType(TextField), 'rēgis');
    await tester.tap(find.byKey(const Key('practice.genus.f')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('practice.check.button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect((await tester.runAsync(RewardStorage.load))!.earnedOf(coins), 3);
    final good = tester.widget<ElevatedButton>(
      find.byKey(const Key('rating.hard')),
    );
    expect(good.style!.elevation!.resolve({}), 4);
  });

  testWidgets('only a noun in the base forms focus is asked its genus', (
    tester,
  ) async {
    seedSettings(Settings());
    await _pumpLarge(
      tester,
      PracticeScreen(item: word('verbs:amare'), focus: const BaseForms()),
    );
    expect(find.byKey(const Key('practice.genus.m')), findsNothing);
    await _pumpLarge(tester, PracticeScreen(item: word('nouns:rex')));
    expect(find.byKey(const Key('practice.genus.m')), findsNothing);
  });
}
