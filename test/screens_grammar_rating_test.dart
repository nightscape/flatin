import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:fsrs/fsrs.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/word_classification_harness.dart';

Future<PracticeItem> _dominus() async => (await loadPracticeItems(
  'lib/data/latin_nouns.yaml',
)).firstWhere((i) => i.lemma == 'dominus');

void _expectRated(
  Map<String, PracticeItemCard> before,
  Map<String, PracticeItemCard> after,
  String id,
  Rating rating,
) {
  final expected = Scheduler().reviewCard(before[id]!.card, rating).card;
  expect(after[id]!.card.state, expected.state, reason: id);
  expect(after[id]!.card.stability, expected.stability, reason: id);
  expect(after[id]!.lastReview, isNotNull, reason: id);
}

void _expectUntouched(
  Map<String, PracticeItemCard> before,
  Map<String, PracticeItemCard> after,
  String id,
) => expect(after[id]!.lastReview, before[id]!.lastReview, reason: id);

String _otherBundleCard(Map<String, PracticeItemCard> cards, String shown) =>
    cards.keys.firstWhere((id) => id.startsWith('grammar:') && id != shown);

Override _cardsWithout(String id) =>
    fsrsCardsProvider.overrideWith((ref) async {
      final items = await loadAllPracticeItems();
      await FsrsStorage.syncCards(items);
      return {...await FsrsStorage.syncGrammarCards(items)}..remove(id);
    });

Future<void> _pumpPractice(
  WidgetTester tester,
  PracticeItem item, {
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1200, 12000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapInApp(
      PracticeScreen(item: item),
      forcedLocale: const Locale('de'),
      overrides: overrides,
    ),
  );
  await letItLoad(tester);
}

Future<Map<String, PracticeItemCard>> _syncedCards(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(PracticeScreen)),
    ).read(fsrsCardsProvider.future);

Future<void> _checkAndRate(WidgetTester tester, Rating rating) async {
  await tester.tap(find.byKey(const Key('practice.check.button')));
  await tester.pump();
  await tester.tap(find.byKey(Key('rating.${rating.name}')));
  await letItLoad(tester);
}

void main() {
  for (final (name, typed, grammar) in [
    ('right', 'dominus', Rating.good),
    ('wrong', 'xyz', Rating.again),
  ]) {
    testWidgets('the paradigm screen rates the shown bundle after a $name row, '
        'not a bundle that was not shown', (tester) async {
      final item = await _dominus();
      await _pumpPractice(tester, item);
      final before = await _syncedCards(tester);
      final shown = GrammarCardId.of(item, 'nom.sg');
      await tester.enterText(
        find.byType(TextField).at(item.formOrder.indexOf('nom.sg')),
        typed,
      );

      await _checkAndRate(tester, Rating.good);

      final after = await FsrsStorage.loadCards();
      _expectRated(before, after, shown, grammar);
      _expectUntouched(before, after, _otherBundleCard(before, shown));
    });
  }

  testWidgets('the paradigm screen leaves a bundle alone when no row of it '
      'was typed', (tester) async {
    final item = await _dominus();
    await _pumpPractice(tester, item);
    final before = await _syncedCards(tester);

    await _checkAndRate(tester, Rating.good);

    final after = await FsrsStorage.loadCards();
    _expectUntouched(before, after, GrammarCardId.of(item, 'nom.sg'));
  });

  for (final (name, rightPick, grammar) in [
    ('right', true, Rating.good),
    ('wrong', false, Rating.again),
  ]) {
    testWidgets('the classification screen rates the shown bundle after a '
        '$name pick, not a bundle that was not shown', (tester) async {
      final item = await _dominus();
      final before = await _pumpClassification(tester, item, 'nom.sg');
      final label = item.formLabels[item.formOrder.indexOf('nom.sg')];
      await _pickLabels(tester, item, [
        rightPick ? label : _wrongLabelInBundle(item, 'nom.sg'),
      ]);

      final after = await _checkAndRateClassification(tester);
      final shownCard = GrammarCardId.of(item, 'nom.sg');
      _expectRated(before, after, shownCard, grammar);
      _expectUntouched(before, after, _otherBundleCard(before, shownCard));
    });
  }

  testWidgets('the paradigm screen rates the word Easy and the bundle Again '
      'when Easy is pressed with a wrong row', (tester) async {
    final item = await _dominus();
    await _pumpPractice(tester, item);
    final before = await _syncedCards(tester);
    await tester.enterText(
      find.byType(TextField).at(item.formOrder.indexOf('nom.sg')),
      'xyz',
    );

    await _checkAndRate(tester, Rating.easy);

    final after = await FsrsStorage.loadCards();
    _expectRated(
      before,
      after,
      PracticeItemCard.generateItemId(item),
      Rating.easy,
    );
    _expectRated(before, after, GrammarCardId.of(item, 'nom.sg'), Rating.again);
  });

  testWidgets('the classification screen rates the word Easy and the bundle '
      'Again when Easy is pressed with a wrong pick', (tester) async {
    final item = await _dominus();
    final before = await _pumpClassification(tester, item, 'nom.sg');
    await _pickLabels(tester, item, [_wrongLabelInBundle(item, 'nom.sg')]);

    final after = await _checkAndRateClassification(tester, Rating.easy);

    _expectRated(
      before,
      after,
      PracticeItemCard.generateItemId(item),
      Rating.easy,
    );
    _expectRated(before, after, GrammarCardId.of(item, 'nom.sg'), Rating.again);
  });

  testWidgets('a combination that names no form of the word rates no bundle '
      'Again', (tester) async {
    final item = (await loadPracticeItems(
      'lib/data/latin_verbs.yaml',
    )).singleWhere((i) => i.id == 'verbs:amare');
    const shown = 'ind.praes.akt.1.sg';
    final before = await _pumpClassification(tester, item, shown);
    await _pickLabels(tester, item, [
      item.formLabels[item.formOrder.indexOf(shown)],
    ]);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await _pickRow(tester, item.formLabels.first.axes, 1, {
      'modus': 'ind',
      'tempus': 'praes',
      'genus_verbi': 'akt',
      'person': '1',
      'numerus': 'sg',
      'kasus': 'nom',
    });

    final after = await _checkAndRateClassification(tester);

    _expectRated(before, after, GrammarCardId.of(item, shown), Rating.good);
  });

  testWidgets('the paradigm screen shows the save error and stores nothing '
      'when a grammar card is missing', (tester) async {
    final item = await _dominus();
    final shown = GrammarCardId.of(item, 'nom.sg');
    await _pumpPractice(tester, item, overrides: [_cardsWithout(shown)]);
    await tester.enterText(
      find.byType(TextField).at(item.formOrder.indexOf('nom.sg')),
      'dominus',
    );

    await _checkAndRate(tester, Rating.good);

    _expectSaveErrorFor(tester, shown);
    final stored = await FsrsStorage.loadCards();
    expect(stored[PracticeItemCard.generateItemId(item)]!.lastReview, isNull);
  });

  testWidgets('the classification screen shows the save error and stores '
      'nothing when a grammar card is missing', (tester) async {
    final item = await _dominus();
    final shown = GrammarCardId.of(item, 'nom.sg');
    await _pumpClassification(
      tester,
      item,
      'nom.sg',
      overrides: [_cardsWithout(shown)],
    );
    await _pickLabels(tester, item, [
      item.formLabels[item.formOrder.indexOf('nom.sg')],
    ]);

    final stored = await _checkAndRateClassification(tester);

    _expectSaveErrorFor(tester, shown);
    expect(stored[PracticeItemCard.generateItemId(item)]!.lastReview, isNull);
  });

  testWidgets('a wrong pick in one of two shown bundles rates that bundle '
      'Again and the other Good', (tester) async {
    final item = (await loadPracticeItems(
      'lib/data/latin_verbs.yaml',
    )).singleWhere((i) => i.id == 'verbs:amare');
    const a = 'ind.praes.pass.2.pl';
    const b = 'imp.praes.pass.2.pl';
    final before = await _pumpClassification(tester, item, a);
    FormLabel labelOf(String k) => item.formLabels[item.formOrder.indexOf(k)];
    await _pickLabels(tester, item, [
      labelOf(a),
      labelOf(b),
      labelOf('ind.praes.pass.1.sg'),
    ]);

    final after = await _checkAndRateClassification(tester);
    _expectRated(before, after, GrammarCardId.of(item, a), Rating.again);
    _expectRated(before, after, GrammarCardId.of(item, b), Rating.good);
  });
}

void _expectSaveErrorFor(WidgetTester tester, String cardId) => expect(
  find.textContaining(
    'Fortschritt nicht gespeichert: Bad state: no card '
    '"$cardId"',
  ),
  findsOneWidget,
);

FormLabel _wrongLabelInBundle(PracticeItem item, String shownKey) =>
    item.formLabels[item.formOrder.indexWhere((k) => k != shownKey)];

Future<Map<String, PracticeItemCard>> _pumpClassification(
  WidgetTester tester,
  PracticeItem item,
  String formKey, {
  List<Override> overrides = const [],
}) async {
  await seedNothingDue({});
  tester.view.physicalSize = const Size(1200, 4800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapInApp(
      WordClassificationScreen(item: item, formKey: formKey),
      forcedLocale: const Locale('de'),
      overrides: overrides,
    ),
  );
  await letItLoad(tester);
  return ProviderScope.containerOf(
    tester.element(find.byType(WordClassificationScreen)),
  ).read(fsrsCardsProvider.future);
}

Future<void> _pickLabels(
  WidgetTester tester,
  PracticeItem item,
  List<FormLabel> labels,
) async {
  for (final (row, label) in labels.indexed) {
    if (row > 0) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
    }
    await _pickRow(tester, label.axes, row, label.features);
  }
}

Future<void> _pickRow(
  WidgetTester tester,
  Axes axes,
  int row,
  Map<String, String> features,
) async {
  for (final axis in axes.axes) {
    final dropdown = find.byKey(Key('classification.$row.${axis.id}'));
    if (dropdown.evaluate().isEmpty) continue;
    final code = features[axis.id];
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .text(
            code == null ? '—' : axis.values.firstWhere((v) => v.$1 == code).$2,
          )
          .last,
    );
    await tester.pumpAndSettle();
  }
}

Future<Map<String, PracticeItemCard>> _checkAndRateClassification(
  WidgetTester tester, [
  Rating rating = Rating.good,
]) async {
  await tester.tap(find.byKey(const Key('wordClassification.check.button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('rating.${rating.name}')));
  await letItLoad(tester);
  return FsrsStorage.loadCards();
}
