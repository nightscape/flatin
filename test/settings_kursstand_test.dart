import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(Settings, Map<String, dynamic>)> _load(
  Map<String, dynamic> stored,
) async {
  SharedPreferences.setMockInitialValues({
    'practice_settings': jsonEncode(stored),
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final settings = await container.read(settingsProvider.future);
  final prefs = await SharedPreferences.getInstance();
  return (
    settings,
    jsonDecode(prefs.getString('practice_settings')!) as Map<String, dynamic>,
  );
}

LessonRange _range(Random rng) {
  final from = 1 + rng.nextInt(laterLesson);
  return LessonRange(from, from + rng.nextInt(laterLesson - from + 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a version 3 store gets the furthest lesson of its ranges as the '
      'Kursstand and keeps the ranges', () async {
    final words = {'from': 3, 'to': 18};
    final grammar = {'from': 1, 'to': 22};
    final (settings, stored) = await _load({
      settingsVersionField: 3,
      'disabledForms': <String, dynamic>{},
      'disabledTypes': <String, dynamic>{},
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
      'courseWords': words,
      'courseGrammar': grammar,
      'grammarFromLinked': false,
      'grammarToLinked': false,
    });

    expect(settings.kursstand, 22);
    expect(settings.courseWords, LessonRange(3, 18));
    expect(settings.courseGrammar, LessonRange(1, 22));
    expect(stored[settingsVersionField], settingsVersion);
    expect(stored['kursstand'], 22);
    expect(stored['courseWords'], words);
    expect(stored['courseGrammar'], grammar);
  });

  test('an unversioned store gets the furthest lesson of its ranges as the '
      'Kursstand and keeps the ranges', () async {
    final (settings, stored) = await _load({
      'disabledForms': <String, dynamic>{},
      'disabledTypes': <String, dynamic>{},
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
      'courseWords': {'from': 1, 'to': 27},
      'courseGrammar': {'from': 2, 'to': 14},
      'grammarFollowsWords': false,
    });

    expect(settings.kursstand, 27);
    expect(settings.courseWords, LessonRange(1, 27));
    expect(settings.courseGrammar, LessonRange(2, 14));
    expect(stored[settingsVersionField], settingsVersion);
    expect(stored['kursstand'], 27);
  });

  test('a store open at the top has reached the last lesson', () async {
    final (settings, _) = await _load({
      settingsVersionField: 3,
      ...Settings().toJson()..remove('kursstand'),
    });

    expect(settings.kursstand, lastLesson);
    expect(settings.courseWords, LessonRange.full);
  });

  test('the Kursstand survives a reload', () async {
    final (settings, _) = await _load(Settings(kursstand: 7).toJson());
    expect(settings.kursstand, 7);
  });

  group('a step of the Kursstand', () {
    test('moves the word range and a linked grammar range that end at it', () {
      final next = Settings(
        courseWords: LessonRange(4, 24),
        kursstand: 24,
      ).withKursstand(25);

      expect(next.kursstand, 25);
      expect(next.courseWords, LessonRange(4, 25));
      expect(next.courseGrammar.to, 25);
    });

    test('moves an unlinked grammar range that ends at it', () {
      final next = Settings(
        courseWords: LessonRange(1, 20),
        courseGrammar: LessonRange(2, 24),
        grammarToLinked: false,
        kursstand: 24,
      ).withKursstand(25);

      expect(next.courseWords, LessonRange(1, 20));
      expect(next.courseGrammar, LessonRange(2, 25));
      expect(next.grammarToLinked, isFalse);
    });

    test('keeps a range that ends earlier', () {
      final next = Settings(
        courseWords: LessonRange(1, 24),
        courseGrammar: LessonRange(5, 12),
        grammarToLinked: false,
        kursstand: 24,
      ).withKursstand(25);

      expect(next.courseWords, LessonRange(1, 25));
      expect(next.courseGrammar, LessonRange(5, 12));
    });

    test('back takes the ranges that end at it along, but not one that starts '
        'above the new Kursstand', () {
      final next = Settings(
        courseWords: LessonRange(3, 24),
        courseGrammar: LessonRange(20, 24),
        grammarToLinked: false,
        kursstand: 24,
      ).withKursstand(10);

      expect(next.kursstand, 10);
      expect(next.courseWords, LessonRange(3, 10));
      expect(next.courseGrammar, LessonRange(20, 24));
    });

    test('a back step below a grammar start keeps that start', () {
      final next = Settings(
        courseWords: LessonRange(1, 20),
        courseGrammar: LessonRange(10, 20),
        kursstand: 20,
      ).withKursstand(5);

      expect(next.courseGrammar, LessonRange(10, 20));
      expect(next.grammarToLinked, isFalse);
      expect(next.courseWords, LessonRange(1, 5));
    });

    test('a word range that starts above the new Kursstand stays', () {
      final next = Settings(
        courseWords: LessonRange(15, 20),
        courseGrammar: LessonRange(1, 20),
        kursstand: 20,
      ).withKursstand(5);

      expect(next.courseWords, LessonRange(15, 20));
      expect(next.courseGrammar, LessonRange(1, 5));
      expect(next.grammarToLinked, isFalse);
    });

    test('a step back and forth above the range starts gives both ranges '
        'back with their link', () {
      final before = Settings(
        courseWords: LessonRange(2, 20),
        courseGrammar: LessonRange(3, 20),
        kursstand: 20,
      );
      final back = before.withKursstand(5);
      final again = back.withKursstand(20);

      expect(back.courseWords, LessonRange(2, 5));
      expect(back.courseGrammar, LessonRange(3, 5));
      expect(back.grammarToLinked, isTrue);
      expect(again.courseWords, before.courseWords);
      expect(again.courseGrammar, before.courseGrammar);
      expect(again.grammarToLinked, isTrue);
    });

    test('takes a range open at the top along from the last lesson', () {
      final next = Settings().withKursstand(24);
      expect(next.courseWords, LessonRange(1, 24));
      expect(next.courseGrammar, LessonRange(1, 24));
    });

    test('on random settings follows the rule', () {
      final rng = Random(350);
      for (var i = 0; i < 2000; i++) {
        final toLinked = rng.nextBool();
        final before = Settings(
          courseWords: _range(rng),
          courseGrammar: _range(rng),
          grammarFromLinked: rng.nextBool(),
          grammarToLinked: toLinked,
          kursstand: rng.nextBool() ? null : 1 + rng.nextInt(lastLesson),
        );
        final lesson = 1 + rng.nextInt(lastLesson);
        final after = before.withKursstand(lesson);
        final reason = 'case $i: ${before.toJson()} to $lesson';

        LessonRange followed(LessonRange r) =>
            min(r.to, lastLesson) == before.kursstand && r.from <= lesson
            ? LessonRange(r.from, lesson)
            : r;
        final words = followed(before.courseWords);
        final grammar = followed(before.courseGrammar);

        expect(after.kursstand, lesson, reason: reason);
        expect(after.courseWords, words, reason: reason);
        expect(after.courseGrammar, grammar, reason: reason);
        expect(after.courseWords.from, before.courseWords.from);
        expect(after.courseGrammar.from, before.courseGrammar.from);
        expect(after.grammarFromLinked, before.grammarFromLinked);
        expect(
          after.grammarToLinked,
          toLinked && grammar.to == words.to,
          reason: reason,
        );
        if (before.courseGrammar.from > lesson) {
          expect(after.courseGrammar, before.courseGrammar, reason: reason);
          expect(
            after.grammarToLinked,
            toLinked && before.courseGrammar.to == words.to,
            reason: reason,
          );
        }
      }
    });
  });
}
