import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_choice.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/data/word_focus.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/curriculum_provider.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/grammar_start_screen.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/round_screen.dart';

import 'support/course_providers.dart';
import 'support/word_classification_harness.dart';

/// Every verb whose type is one of [irregularVerbTypes], read off the data.
const _irregularLemmas = {
  'esse', 'abesse', 'adesse', 'dēesse', 'praeesse', 'posse', //
  'īre', 'abīre', 'adīre', 'exīre', 'inīre', 'perīre', 'redīre', 'subīre',
  'ferre', 'afferre', 'auferre', 'cōnferre', 'efferre', 'īnferre',
  'offerre', 'perferre', 'referre', //
  'velle', 'nōlle', 'mālle',
};

ProviderContainer _container(LessonRange range) {
  seedSettings(Settings(courseWords: range, courseGrammar: range));
  return ProviderContainer(
    retry: noRetry,
    overrides: [
      dataLanguageProvider.overrideWith((ref) => 'de'),
      exerciseRandomProvider.overrideWithValue(Random(17)),
    ],
  );
}

Set<String> _ids(Iterable<PracticeItem> words) => {for (final w in words) w.id};

Future<void> _pick(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(const Key('focus.picker')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byKey(Key('focus.option.$id')).last,
      matching: find.byType(Text),
    ),
  );
  await tester.pumpAndSettle();
}

DropdownMenuItem<WordFocus> _option(WidgetTester tester, String id) => tester
    .widget<DropdownButton<WordFocus>>(find.byKey(const Key('focus.picker')))
    .items!
    .singleWhere((item) => item.value!.id == id);

Future<void> _pumpLarge(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapInApp(screen, forcedLocale: const Locale('de')));
  await letItLoad(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the irregular verbs are those of the types esse-Typ, '
      'esse-Kompositum and Unregelmäßig', () async {
    final verbs = await getFormMetadata('lib/data/latin_verbs.yaml');
    expect(verbs.availableTypes, containsAll(irregularVerbTypes));
    final all = await loadAllPracticeItems();
    expect({
      for (final w in all.where(const IrregularVerbs().includes)) w.lemma,
    }, _irregularLemmas);
  });

  for (final range in [LessonRange(1, 3), LessonRange.full]) {
    test('in lessons ${range.from}..${range.to} each focus narrows the words '
        'in range to exactly its group', () async {
      final c = _container(range);
      addTearDown(c.dispose);
      final practicable = await c.read(practicableItemsByTypeProvider.future);
      final focuses = await c.read(wordFocusesProvider.future);
      final nouns = practicable['nouns']!;
      final verbs = practicable['verbs']!;

      expect(focuses.take(4), const [
        AllWords(),
        FileFocus('nouns'),
        FileFocus('verbs'),
        IrregularVerbs(),
      ]);
      expect(const AllWords().narrow(practicable), practicable);
      expect(const FileFocus('nouns').narrow(practicable), {
        'nouns': nouns,
        'verbs': isEmpty,
      });
      expect(const FileFocus('verbs').narrow(practicable), {
        'nouns': isEmpty,
        'verbs': verbs,
      });
      expect({
        for (final w in const IrregularVerbs().narrow(practicable)['verbs']!)
          w.lemma,
      }, range == LessonRange.full ? _irregularLemmas : isEmpty);
      expect(const IrregularVerbs().narrow(practicable)['nouns'], isEmpty);

      final types = focuses.skip(4).cast<TypeFocus>().toList();
      for (final (file, words) in [('nouns', nouns), ('verbs', verbs)]) {
        final ofFile = types.where((t) => t.dataFileId == file).toList();
        expect(
          ofFile.map((t) => t.type).toSet(),
          {for (final w in words) w.type},
          reason: 'one entry per type in range of $file',
        );
        final parts = [
          for (final t in ofFile) _ids(t.narrow(practicable)[file]!),
        ];
        expect(parts.every((p) => p.isNotEmpty), isTrue);
        expect(parts.fold(0, (n, p) => n + p.length), words.length);
        expect(parts.expand((p) => p).toSet(), _ids(words));
        for (final t in ofFile) {
          expect(
            t.narrow(practicable)[file]!.every((w) => w.type == t.type),
            isTrue,
            reason: t.id,
          );
        }
      }
    });
  }

  test('a focused round asks only words of its focus; the topics listed '
      'have words of it', () async {
    final c = _container(LessonRange.full);
    addTearDown(c.dispose);
    final filter = await c.read(courseFilterProvider.future);
    final practicable = await c.read(practicableItemsByTypeProvider.future);
    final focuses = await c.read(wordFocusesProvider.future);
    for (final focus in [
      const FileFocus('nouns'),
      const IrregularVerbs(),
      focuses.whereType<TypeFocus>().last,
    ]) {
      final topics = await c.read(topicsProvider(focus).future);
      expect(topics, isNotEmpty, reason: focus.id);
      for (final topic in topics) {
        expect(
          unlockedBundles(
            filter,
            focus.narrow(practicable)[topic.dataFileId]!,
          ).intersection(topic.bundles.toSet()),
          isNotEmpty,
          reason: '${focus.id} ${topic.id}',
        );
      }
      final offer = await c.read(todayOfferProvider(focus).future);
      for (final request in [
        MixedRound(focus),
        if (offer is NewTopicOffer) BlockedRound(offer.topic.id, focus),
        BlockedRound(topics.last.id, focus),
      ]) {
        final provider = roundProvider(request);
        final sub = c.listen(provider, (_, _) {});
        final words = (await c.read(provider.future)).queue.map((t) => t.word);
        expect(words, isNotEmpty, reason: '$request ${focus.id}');
        expect(
          words.where((w) => !focus.includes(w)).map((w) => w.id),
          isEmpty,
          reason: '$request ${focus.id}',
        );
        sub.close();
      }
    }
  });

  test('the next noun or verb to practise is the next due one of the '
      'focus', () async {
    final c = _container(LessonRange.full);
    addTearDown(c.dispose);
    final due = await c.read(dueItemsByTypeProvider.future);
    expect(
      await c.read(nextDueItemProvider('verbs', const AllWords()).future),
      due['verbs']!.first,
    );
    final irregular = await c.read(
      nextDueItemProvider('verbs', const IrregularVerbs()).future,
    );
    expect(
      irregular,
      due['verbs']!.firstWhere(const IrregularVerbs().includes),
    );
    expect(
      await c.read(nextDueItemProvider('nouns', const IrregularVerbs()).future),
      isNull,
    );
  });

  testWidgets('the grammar start offers every focus, starts at "Alles" and '
      'disables a group without words in range, with a reason', (tester) async {
    seedSettings(
      Settings(
        courseWords: LessonRange(1, 1),
        courseGrammar: LessonRange(1, 1),
      ),
    );
    await _pumpLarge(tester, const GrammarStartScreen());

    final picker = tester.widget<DropdownButton<WordFocus>>(
      find.byKey(const Key('focus.picker')),
    );
    expect(picker.value, const AllWords());
    expect(find.text('Fokus'), findsOneWidget);
    for (final id in ['all', 'nouns', 'verbs', 'nouns:A-Deklination']) {
      expect(_option(tester, id).enabled, isTrue, reason: id);
    }
    expect(_option(tester, 'irregular').enabled, isFalse);
    expect(
      (_option(tester, 'irregular').child as Text).data,
      'Unregelmäßige Verben – keine Wörter im Kursstand',
    );
    expect((_option(tester, 'verbs').child as Text).data, 'Verben');

    await _pick(tester, 'nouns');
    await tester.tap(find.byKey(const Key('round.start.go')));
    await letItLoad(tester);
    expect(
      tester.widget<RoundScreen>(find.byType(RoundScreen)).request.focus,
      const FileFocus('nouns'),
    );
  });

  testWidgets('with every lesson in range the irregular verbs can be '
      'picked', (tester) async {
    seedSettings(Settings());
    await _pumpLarge(tester, const GrammarStartScreen());
    expect(_option(tester, 'irregular').enabled, isTrue);
  });

  testWidgets('on the home screen the focus narrows the noun and verb '
      'practice', (tester) async {
    seedSettings(Settings());
    await _pumpLarge(tester, const HomeScreen());
    expect(
      tester
          .widget<DropdownButton<WordFocus>>(
            find.byKey(const Key('focus.picker')),
          )
          .value,
      const AllWords(),
    );

    await _pick(tester, 'irregular');
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('home.nouns.button')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('home.verbs.button')));
    await letItLoad(tester);
    final opened = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(opened.focus, const IrregularVerbs());
    expect(irregularVerbTypes, contains(opened.item.type));
  });

  testWidgets('a held type focus whose type leaves the range stays listed, '
      'disabled, with the reason', (tester) async {
    seedSettings(Settings());
    await _pumpLarge(tester, const HomeScreen());
    await _pick(tester, 'verbs:Unregelmäßig');

    final c = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await c.read(settingsProvider.notifier).setWordRange(LessonRange(1, 1));
    await letItLoad(tester);

    final held = _option(tester, 'verbs:Unregelmäßig');
    expect(held.enabled, isFalse);
    expect(
      (held.child as Text).data,
      'Unregelmäßig – keine Wörter im Kursstand',
    );
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('home.verbs.button')))
          .onPressed,
      isNull,
    );
  });
}
