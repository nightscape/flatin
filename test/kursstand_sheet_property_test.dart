import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/widgets/kursstand_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_settings.dart';
import 'support/word_classification_harness.dart';

const _seed = 3503;
const _pureCases = 20000;

final _chip = find.byKey(const Key('home.kursstand'));
final _next = find.byKey(const Key('kursstand.next'));
final _picker = find.byKey(const Key('kursstand.picker'));

const _types = {
  'nouns': {'A-Deklination', 'O-Deklination'},
  'verbs': {'a-Konjugation'},
};
const _forms = {
  'nouns': {'nom_sg', 'gen_pl'},
};
const _features = {
  'verbs': {
    'genus_verbi': {'act', 'pass'},
  },
};
const _wordUniverse = {'hīc', 'hic', 'porta', 'amīcus'};
const _topics = {'1/nouns/A-Deklination', '3/verbs/genus_verbi=pass'};

/// Stored settings with the learner's overrides drawn too, so that a step
/// of the Kursstand that touches them shows.
Json _drawStored(Random rng) => drawStoredSettings(
  rng,
  types: _types,
  forms: _forms,
  features: _features,
  words: _wordUniverse,
  topics: _topics,
);

Json _words(Json s) => s['courseWords'] as Json;
Json _grammar(Json s) => s['courseGrammar'] as Json;
int _from(Json range) => range['from'] as int;
int _to(Json range) => range['to'] as int;

int _kursstandOf(Json s) =>
    s['kursstand'] as int? ??
    min(max(_to(_words(s)), _to(_grammar(s))), lastLesson);

bool _sameRanges(Json a, Json b) =>
    _from(_words(a)) == _from(_words(b)) &&
    _to(_words(a)) == _to(_words(b)) &&
    _from(_grammar(a)) == _from(_grammar(b)) &&
    _to(_grammar(a)) == _to(_grammar(b));

/// A lesson to pick in [s], weighted towards the cases the rule tells apart.
int _drawPick(Random rng, Json s) {
  final k = _kursstandOf(s);
  final start = max(_from(_words(s)), _from(_grammar(s)));
  return switch (rng.nextInt(6)) {
    0 => k,
    1 => min(k + 1, lastLesson),
    2 => 1 + rng.nextInt(k),
    3 when start > 1 => 1 + rng.nextInt(start - 1),
    4 => lastLesson,
    _ => 1 + rng.nextInt(lastLesson),
  };
}

/// The oracle of a pick: a lesson other than the Kursstand moves it there; a
/// range follows when it ends at the old Kursstand ("Später" counts as the
/// last lesson) and starts at most at the new one; the grammar end stays
/// linked only while it equals the word end. The current lesson changes
/// nothing.
Json _afterPick(Json s, int lesson) {
  final k = _kursstandOf(s);
  if (lesson == k) return s;
  Json follow(Json r) => min(_to(r), lastLesson) == k && _from(r) <= lesson
      ? {'from': _from(r), 'to': lesson}
      : r;
  final words = follow(_words(s));
  final grammar = follow(_grammar(s));
  return {
    ...s,
    'courseWords': words,
    'courseGrammar': grammar,
    'kursstand': lesson,
    'grammarToLinked':
        s['grammarToLinked'] as bool && _to(grammar) == _to(words),
  };
}

/// Whether both ranges of [s] come back after a step back to [back] and forth
/// to the old Kursstand k. Exact condition, per range: one that ends at k
/// (or "Später" while k is the last lesson) comes back unless it is open and
/// followed back (it comes forth to the last lesson only); any other range
/// comes back unless it ends at [back] (it follows forth to k).
bool _comesBack(Json s, int back) {
  final k = _kursstandOf(s);
  bool ok(Json r) => min(_to(r), lastLesson) == k
      ? _to(r) == k || _from(r) > back
      : _to(r) != back;
  return ok(_words(s)) && ok(_grammar(s));
}

sealed class _Action {}

class _Pick extends _Action {
  final int lesson;
  final bool viaNext;
  _Pick(this.lesson, {required this.viaNext});
  @override
  String toString() => viaNext ? 'next($lesson)' : 'pick($lesson)';
}

class _Dismiss extends _Action {
  @override
  String toString() => 'dismiss';
}

/// Fixed cases every loop runs before the drawn ones, each with its actions
/// and the back lesson of its round trip: the current lesson picked on a
/// fresh install, a typo fixed by a step back and forth, and a back step
/// below the start of the word range.
final _fixed = <(Json, List<_Action>, int?)>[
  (
    Settings().toJson()..remove('kursstand'),
    [_Pick(lastLesson, viaNext: false)],
    null,
  ),
  (
    Settings(
      courseWords: LessonRange(1, 20),
      courseGrammar: LessonRange(10, 20),
      kursstand: 20,
    ).toJson(),
    [_Pick(5, viaNext: false), _Pick(20, viaNext: false)],
    5,
  ),
  (
    Settings(
      courseWords: LessonRange(15, 20),
      courseGrammar: LessonRange(1, 20),
      kursstand: 20,
    ).toJson(),
    [_Pick(5, viaNext: false), _Pick(20, viaNext: false)],
    5,
  ),
];

/// The fixed cases, then [count] drawn ones from seed [firstSeed] on: a
/// label for the failure reason, the stored settings, the actions and the
/// back lesson of a round trip.
List<(String, Json, List<_Action>, int?)> _cases(int firstSeed, int count) {
  final cases = [
    for (final (i, (stored, actions, roundTrip)) in _fixed.indexed)
      ('fixed case $i', stored, actions, roundTrip),
  ];
  for (var seed = firstSeed; seed < firstSeed + count; seed++) {
    final rng = Random(seed);
    final stored = _drawStored(rng);
    final (actions, roundTrip) = _drawActions(rng, stored);
    cases.add(('seed $seed', stored, actions, roundTrip));
  }
  return cases;
}

/// The actions of one case, and the back lesson if the case starts with a
/// step back and the step forth to the old Kursstand.
(List<_Action>, int?) _drawActions(Random rng, Json stored) {
  var state = stored;
  final actions = <_Action>[];
  int? roundTrip;
  final k = _kursstandOf(stored);
  if (k > 1 && rng.nextInt(3) == 0) {
    final back = 1 + rng.nextInt(k - 1);
    roundTrip = back;
    actions
      ..add(_Pick(back, viaNext: false))
      ..add(_Pick(k, viaNext: back + 1 == k && rng.nextBool()));
    state = _afterPick(_afterPick(state, back), k);
  }
  for (var i = rng.nextInt(3); i >= 0; i--) {
    if (rng.nextInt(8) == 0) {
      actions.add(_Dismiss());
      continue;
    }
    final lesson = _drawPick(rng, state);
    final viaNext = lesson == _kursstandOf(state) + 1 && rng.nextBool();
    actions.add(_Pick(lesson, viaNext: viaNext));
    state = _afterPick(state, lesson);
  }
  return (actions, roundTrip);
}

typedef _Reach = Map<String, int>;

void _count(_Reach reach, String what, bool hit) =>
    reach.update(what, (n) => n + (hit ? 1 : 0), ifAbsent: () => hit ? 1 : 0);

void _countPick(_Reach reach, Json s, int lesson, {required bool viaNext}) {
  final k = _kursstandOf(s);
  final starts = [_from(_words(s)), _from(_grammar(s))];
  final open = [_to(_words(s)), _to(_grammar(s))].contains(laterLesson);
  _count(reach, 'pick = current', lesson == k);
  _count(reach, 'pick = current+1', lesson == k + 1);
  _count(reach, 'the next button', viaNext);
  _count(reach, 'a back step', lesson < k);
  _count(
    reach,
    'a back step below a range start',
    lesson < k && starts.any((f) => lesson < f),
  );
  _count(
    reach,
    'a range starting above the pick',
    starts.any((f) => f > lesson),
  );
  _count(reach, 'the last lesson', lesson == lastLesson);
  _count(reach, 'Kursstand at the last lesson', k == lastLesson);
  _count(reach, 'an open-ended range', open);
  _count(reach, 'pick = current on an open range', lesson == k && open);
  _count(reach, 'to-linked grammar', s['grammarToLinked'] as bool);
  _count(reach, 'from-linked grammar', s['grammarFromLinked'] as bool);
  _count(reach, 'a derived Kursstand', !s.containsKey('kursstand'));
  _countRewards(reach, s);
}

void _countRewards(_Reach reach, Json s) {
  final off = s['disabledRewards'] as List;
  _count(reach, 'points off', off.contains('points'));
  _count(reach, 'town off', off.contains('town'));
  _count(reach, 'points and town off', off.length == 2);
}

void _expectReached(_Reach reach) {
  // ignore: avoid_print
  print('reach: $reach');
  for (final MapEntry(:key, :value) in reach.entries) {
    expect(value, greaterThan(0), reason: 'never drawn: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final german =
      (jsonDecode(File('assets/flutter_i18n/de.json').readAsStringSync())
              as Json)['kursstand']
          as Json;

  // Real texts: 'next' and 'lesson' interpolate the lesson, and the test
  // checks that each language shows its own wording.
  // The rule does not depend on the language, so English draws fewer cases.
  const deCases = 100;
  for (final (locale, firstSeed, cases, nextText, lessonText) in [
    (const Locale('de'), _seed, deCases, 'Weiter zu Lektion', 'Lektion'),
    (const Locale('en'), _seed + deCases, 30, 'Continue to lesson', 'Lesson'),
  ]) {
    testWidgets('picks in the ${locale.languageCode} sheet store what the '
        'rule says and the chip shows the Kursstand', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Tall enough that the picker menu lays out every lesson.
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapInApp(
          Scaffold(appBar: AppBar(actions: const [KursstandChip()])),
          forcedLocale: locale,
        ),
      );
      await letItLoad(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(KursstandChip)),
      );
      Future<String> raw() async => (await SharedPreferences.getInstance())
          .getString('practice_settings')!;
      final reach = <String, int>{};
      var writes = 0;
      container.listen(settingsProvider, (_, _) => writes++);

      final watch = Stopwatch()..start();
      for (final (label, stored, actions, roundTrip) in _cases(
        firstSeed,
        cases,
      )) {
        final reason = '$label: $stored then $actions';

        SharedPreferences.setMockInitialValues({
          'practice_settings': jsonEncode(stored),
        });
        container.invalidate(settingsProvider);
        await tester.pump();
        await tester.pump();
        expect(container.read(settingsProvider).isLoading, isFalse);

        var expected = stored;
        for (final (index, action) in actions.indexed) {
          final k = _kursstandOf(expected);
          expect(
            find.descendant(of: _chip, matching: find.text('$k')),
            findsOneWidget,
            reason: 'P3 $reason',
          );
          await tester.tap(_chip);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: _next,
              matching: find.text('$nextText ${k + 1}'),
            ),
            k < lastLesson ? findsOneWidget : findsNothing,
            reason: 'P3 $reason',
          );
          expect(_next, k < lastLesson ? findsOneWidget : findsNothing);
          if (locale.languageCode == 'en') {
            for (final label in german.values) {
              final shown = (label as String).replaceAll(
                '{lesson}',
                '${k + 1}',
              );
              expect(find.text(shown), findsNothing, reason: reason);
            }
          }

          final before = await raw();
          final writesBefore = writes;
          switch (action) {
            case _Dismiss():
              await tester.tapAt(const Offset(180, 20));
            case _Pick(:final lesson, viaNext: true):
              expect(lesson, k + 1);
              await tester.tap(_next);
            case _Pick(:final lesson):
              await tester.tap(_picker);
              await tester.pumpAndSettle();
              await tester.tap(find.text('$lessonText $lesson').last);
          }
          await tester.pumpAndSettle();
          expect(_picker, findsNothing, reason: reason);

          _count(reach, 'a dismiss', action is _Dismiss);
          if (action case _Pick(:final lesson, :final viaNext)) {
            _countPick(reach, expected, lesson, viaNext: viaNext);
          }
          final lesson = switch (action) {
            _Pick(:final lesson) => lesson,
            _Dismiss() => k,
          };
          expected = _afterPick(expected, lesson);
          if (lesson == k) {
            expect(await raw(), before, reason: 'P2 $reason');
            expect(writes, writesBefore, reason: 'P2 $reason');
          } else {
            expect(jsonDecode(await raw()), expected, reason: 'P1 $reason');
          }
          if (roundTrip != null && index == 1) {
            _count(reach, 'a round trip', true);
            expect(
              _sameRanges(jsonDecode(await raw()) as Json, stored),
              _comesBack(stored, roundTrip),
              reason: 'P4 $reason',
            );
          }
        }
        expect(
          find.descendant(
            of: _chip,
            matching: find.text('${_kursstandOf(expected)}'),
          ),
          findsOneWidget,
          reason: 'P3 $reason',
        );
      }
      // ignore: avoid_print
      print(
        '${locale.languageCode}: $cases cases in '
        '${watch.elapsedMilliseconds} ms',
      );
      _expectReached(reach);
    });
  }

  testWidgets('HomeScreen shows the Kursstand chip in its app bar for any '
      'stored settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapInApp(const HomeScreen(), forcedLocale: const Locale('de')),
    );
    await letItLoad(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final reach = <String, int>{};
    final cases = [
      for (final off in [
        {'town'},
        {'points', 'town'},
        {'points'},
      ])
        ('fixed rewards off $off', Settings(disabledRewards: off).toJson()),
      for (var seed = _seed; seed < _seed + 50; seed++)
        ('seed $seed', _drawStored(Random(seed))),
    ];
    for (final (label, stored) in cases) {
      SharedPreferences.setMockInitialValues({
        'practice_settings': jsonEncode(stored),
      });
      container.invalidate(settingsProvider);
      await letItLoad(tester);
      expect(container.read(settingsProvider).isLoading, isFalse);
      final reason = '$label: $stored';
      expect(
        find.descendant(
          of: _chip,
          matching: find.text('${_kursstandOf(stored)}'),
        ),
        findsOneWidget,
        reason: reason,
      );
      expect(
        tester.getRect(find.byType(AppBar)).contains(tester.getCenter(_chip)),
        isTrue,
        reason: reason,
      );
      _countRewards(reach, stored);
      _count(reach, 'a derived Kursstand', !stored.containsKey('kursstand'));
    }
    _expectReached(reach);
  });

  Json step(Json s, int lesson) =>
      Settings.fromJson(s).withKursstand(lesson).toJson();

  test('steps of the Kursstand store what the rule says', () {
    final reach = <String, int>{};
    for (final (label, stored, actions, _) in _cases(_seed, _pureCases)) {
      var state = stored;
      final steps = <int>[];
      for (final action in actions) {
        if (action is! _Pick || action.lesson == _kursstandOf(state)) continue;
        steps.add(action.lesson);
        _countPick(reach, state, action.lesson, viaNext: false);
        final next = step(state, action.lesson);
        expect(
          next,
          _afterPick(state, action.lesson),
          reason: 'P1 $label: $stored then $steps',
        );
        state = next;
      }
    }
    reach.remove('pick = current');
    reach.remove('pick = current on an open range');
    reach.remove('the next button');
    _expectReached(reach);
  });

  test('a step back and forth gives the ranges back exactly when nothing '
      'follows past them', () {
    final trips = [
      for (final (i, (stored, _, back)) in _fixed.indexed)
        if (back != null) ('fixed case $i', stored, back),
    ];
    for (var seed = _seed; seed < _seed + _pureCases; seed++) {
      final rng = Random(seed);
      final stored = _drawStored(rng);
      final k = _kursstandOf(stored);
      if (k > 1) trips.add(('seed $seed', stored, 1 + rng.nextInt(k - 1)));
    }
    final reach = <String, int>{};
    for (final (label, stored, back) in trips) {
      final comesBack = _comesBack(stored, back);
      _count(reach, 'a round trip that comes back', comesBack);
      _count(reach, 'a round trip that does not', !comesBack);
      expect(
        _sameRanges(step(step(stored, back), _kursstandOf(stored)), stored),
        comesBack,
        reason: 'P4 $label: $stored back to $back',
      );
    }
    _expectReached(reach);
  });
}
