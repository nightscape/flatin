import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/word_classification_harness.dart';

/// Two widget tests in one file must not interfere. The second one used to
/// wait forever on the practice data that the first one had already loaded,
/// and then on the load that the first one had left in flight.
void main() {
  setUp(resetPracticeDataForTest);
  tearDown(() => parseGate = () async {});

  test('two concurrent loads of one zone parse once', () async {
    var parses = 0;
    final gate = Completer<void>();
    parseGate = () {
      parses++;
      return gate.future;
    };

    unawaited(loadPracticeItems('lib/data/latin_nouns.yaml'));
    unawaited(loadPracticeItems('lib/data/latin_verbs.yaml'));
    await Future<void>.delayed(Duration.zero);

    expect(parses, 1);
  });

  test('a parse that throws does not brick later loads in the same zone',
      () async {
    parseGate = () async => throw StateError('simulated bad data file');
    await expectLater(
        loadPracticeItems('lib/data/latin_nouns.yaml'), throwsStateError);

    parseGate = () async {};
    final items = await loadPracticeItems('lib/data/latin_nouns.yaml')
        .timeout(const Duration(seconds: 5));

    expect(items, isNotEmpty);
  });

  test('a parse that throws rejects the callers queued behind it', () async {
    final gate = Completer<void>();
    parseGate = () => gate.future;

    final first = loadPracticeItems('lib/data/latin_nouns.yaml');
    final second = loadPracticeItems('lib/data/latin_verbs.yaml');
    unawaited(first.then((_) {}, onError: (_) {}));
    await Future<void>.delayed(Duration.zero);

    gate.completeError(StateError('simulated bad data file'));

    await expectLater(first, throwsStateError);
    await expectLater(
        second.timeout(const Duration(seconds: 5)), throwsStateError);
  });

  test('a caller queued by another zone is adopted by the take-over',
      () async {
    final gate = Completer<void>();
    parseGate = () => gate.future;

    unawaited(loadPracticeItems('lib/data/latin_nouns.yaml'));
    final adopted = loadPracticeItems('lib/data/latin_verbs.yaml');
    await Future<void>.delayed(Duration.zero);

    parseGate = () async {};
    await runZoned(() => loadPracticeItems('lib/data/latin_nouns.yaml'));

    expect(await adopted.timeout(const Duration(seconds: 5)), isNotEmpty);
  });

  test('an adopted caller gets the error of the take-over', () async {
    final gate = Completer<void>();
    parseGate = () => gate.future;

    unawaited(loadPracticeItems('lib/data/latin_nouns.yaml'));
    final adopted = loadPracticeItems('lib/data/latin_verbs.yaml');
    await Future<void>.delayed(Duration.zero);

    parseGate = () async => throw StateError('simulated bad data file');
    await expectLater(
        runZoned(() => loadPracticeItems('lib/data/latin_nouns.yaml')),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', 'simulated bad data file')));

    await expectLater(
        adopted.timeout(const Duration(seconds: 5)), throwsStateError);
  });

  test('a parse that finishes releases a caller it queued after a take-over',
      () async {
    final gateA = Completer<void>();
    final gateB = Completer<void>();
    var parses = 0;
    parseGate = () => ++parses == 1 ? gateA.future : gateB.future;

    unawaited(loadPracticeItems('lib/data/latin_nouns.yaml'));
    final queued = loadPracticeItems('lib/data/latin_verbs.yaml');
    await Future<void>.delayed(Duration.zero);

    unawaited(runZoned(() => loadPracticeItems('lib/data/latin_nouns.yaml')));
    await Future<void>.delayed(Duration.zero);

    gateA.complete();
    expect(await queued.timeout(const Duration(seconds: 5)), isNotEmpty);
  });

  test('a parse that throws rejects a caller it queued after a take-over',
      () async {
    final gateA = Completer<void>();
    final gateB = Completer<void>();
    var parses = 0;
    parseGate = () => ++parses == 1 ? gateA.future : gateB.future;

    final first = loadPracticeItems('lib/data/latin_nouns.yaml');
    unawaited(first.then((_) {}, onError: (_) {}));
    final queued = loadPracticeItems('lib/data/latin_verbs.yaml');
    await Future<void>.delayed(Duration.zero);

    unawaited(runZoned(() => loadPracticeItems('lib/data/latin_nouns.yaml')));
    await Future<void>.delayed(Duration.zero);

    gateA.completeError(StateError('simulated bad data file'));
    await expectLater(
        queued.timeout(const Duration(seconds: 5)), throwsStateError);
  });

  testWidgets('a test that abandons the load does not strand the next one',
      (tester) async {
    final gate = Completer<void>();
    parseGate = () => gate.future;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(wrapInApp(const LatinPracticeApp()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final nouns = tester.widget<ElevatedButton>(
        find.byKey(const Key('home.nouns.button')));
    expect(nouns.onPressed, isNull);
  });

  testWidgets('the next test still reaches the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(wrapInApp(const LatinPracticeApp()));
    await letItLoad(tester);

    final nouns = tester.widget<ElevatedButton>(
        find.byKey(const Key('home.nouns.button')));
    expect(nouns.onPressed, isNotNull);
  });

  for (final run in ['first', 'second']) {
    testWidgets('the $run test of the file reaches the home screen',
        (tester) async {
      await seedNothingDue({'nouns': <String>{}, 'verbs': <String>{}});

      await tester.pumpWidget(wrapInApp(const LatinPracticeApp()));
      await letItLoad(tester);

      expect(find.text('Nomen (Deklination)'), findsOneWidget);
      expect(find.text('Verben (Konjugation)'), findsOneWidget);
    });
  }
}
