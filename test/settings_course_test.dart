import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

void main() {
  group('course ranges', () {
    test('a fresh setting practises the whole course', () {
      final settings = Settings();

      expect(settings.courseWords, LessonRange.full);
      expect(settings.courseGrammar, LessonRange(1, laterLesson));
    });

    test('unlinked, the grammar range stands on its own', () {
      final settings = Settings()
          .withWordRange(LessonRange(5, 12))
          .withGrammarLinked(to: false)
          .withGrammarRange(LessonRange(1, 8));

      expect(settings.courseGrammar, LessonRange(1, 8));
      expect(
        settings.withWordRange(LessonRange(5, 20)).courseGrammar,
        LessonRange(1, 8),
      );
    });
  });

  group('overrides', () {
    test('a toggle stores an override only against the course verdict', () {
      final off = Settings().toggleWord('amare', inRange: true);
      expect(off.overrideOfWord('amare'), Override.forcedOff);

      final on = Settings().toggleWord('amare', inRange: false);
      expect(on.overrideOfWord('amare'), Override.forcedOn);
    });

    test('toggling twice leaves no override behind', () {
      for (final inRange in [true, false]) {
        final once = Settings().toggleWord('amare', inRange: inRange);
        final twice = once.toggleWord('amare', inRange: inRange);

        expect(
          twice.overrideOfWord('amare'),
          Override.none,
          reason: 'inRange: $inRange',
        );
        expect(twice.deselectedWords, isEmpty);
        expect(twice.forcedOnWords, isEmpty);
      }
    });

    test('a toggle against an override of the other side clears it', () {
      final forcedOn = Settings().toggleWord('amare', inRange: false);
      final back = forcedOn.toggleWord('amare', inRange: false);

      expect(back.forcedOnWords, isEmpty);
      expect(back.deselectedWords, isEmpty);
    });

    test('types and forms override the same way', () {
      final settings = Settings()
          .toggleType('nouns', 'A-Deklination', inRange: true)
          .toggleForm('nouns', 'gen.sg', inRange: false);

      expect(
        settings.overrideOfType('nouns', 'A-Deklination'),
        Override.forcedOff,
      );
      expect(settings.overrideOfForm('nouns', 'gen.sg'), Override.forcedOn);
      expect(settings.overrideOfForm('nouns', 'nom.sg'), Override.none);
    });

    test('clearOverrides empties every override and keeps the ranges', () {
      final settings = Settings()
          .withWordRange(LessonRange(3, 9))
          .toggleWord('amare', inRange: true)
          .toggleType('nouns', 'A-Deklination', inRange: false)
          .toggleForm('nouns', 'gen.sg', inRange: true)
          .toggleTopic('1/nouns/*', inRange: true)
          .toggleTopic('41/verbs/ger', inRange: false)
          .toggleFeature('verbs', 'genus_verbi', 'pass')
          .setInputStrategy('nouns', 'dropdown_all_forms')
          .clearOverrides();

      expect(settings.deselectedWords, isEmpty);
      expect(settings.forcedOnWords, isEmpty);
      expect(settings.disabledTypes, isEmpty);
      expect(settings.forcedOnTypes, isEmpty);
      expect(settings.disabledForms, isEmpty);
      expect(settings.forcedOnForms, isEmpty);
      expect(settings.deselectedTopics, isEmpty);
      expect(settings.forcedOnTopics, isEmpty);
      expect(settings.disabledFeatures, isEmpty);
      expect(settings.courseWords, LessonRange(3, 9));
      expect(settings.getInputStrategyId('nouns'), 'dropdown_all_forms');
    });

    test('an entry cannot be forced on and off at once', () {
      expect(
        () => Settings(deselectedWords: {'amare'}, forcedOnWords: {'amare'}),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => Settings(
          disabledTypes: {
            'nouns': {'A-Deklination'},
          },
          forcedOnTypes: {
            'nouns': {'A-Deklination'},
          },
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => Settings(
          disabledForms: {
            'nouns': {'gen.sg'},
          },
          forcedOnForms: {
            'nouns': {'gen.sg'},
          },
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('storage', () {
    test('every new field survives a JSON round trip', () {
      final settings = Settings(
        disabledFeatures: {
          'verbs': {
            'genus_verbi': {'pass'},
          },
        },
        inputStrategyIds: {'nouns': 'dropdown_all_forms'},
        deselectedWords: {'amare'},
        courseWords: LessonRange(4, 17),
        courseGrammar: LessonRange(1, 9),
        grammarToLinked: false,
        forcedOnWords: {'rosa'},
        forcedOnTypes: {
          'nouns': {'U-Deklination'},
        },
        forcedOnForms: {
          'verbs': {'konj.impf.akt.3.sg'},
        },
        deselectedTopics: {'1/nouns/*'},
        forcedOnTopics: {'41/verbs/ger'},
      );

      final restored = Settings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );

      expect(restored.courseWords, LessonRange(4, 17));
      expect(restored.courseGrammar, LessonRange(1, 9));
      expect(restored.grammarToLinked, isFalse);
      expect(restored.forcedOnWords, {'rosa'});
      expect(restored.forcedOnTypes, {
        'nouns': {'U-Deklination'},
      });
      expect(restored.forcedOnForms, {
        'verbs': {'konj.impf.akt.3.sg'},
      });
      expect(restored.deselectedWords, {'amare'});
      expect(restored.deselectedTopics, {'1/nouns/*'});
      expect(restored.forcedOnTopics, {'41/verbs/ger'});
    });

    test('settings stored before the course ranges read as forced-off', () {
      final stored = {
        settingsVersionField: settingsVersion,
        'disabledForms': {
          'nouns': ['gen.sg'],
        },
        'disabledFeatures': {
          'verbs': {
            'genus_verbi': ['pass'],
          },
        },
        'disabledTypes': {
          'nouns': ['U-Deklination'],
        },
        'inputStrategyIds': {'nouns': 'text_field'},
        'deselectedWords': ['amare'],
      };

      final settings = Settings.fromJson(
        jsonDecode(jsonEncode(stored)) as Map<String, dynamic>,
      );

      expect(settings.courseWords, LessonRange.full);
      expect(settings.courseGrammar, LessonRange.full);
      expect(settings.grammarToLinked, isTrue);
      expect(settings.deselectedTopics, isEmpty);
      expect(settings.forcedOnTopics, isEmpty);
      expect(settings.overrideOfWord('amare'), Override.forcedOff);
      expect(
        settings.overrideOfType('nouns', 'U-Deklination'),
        Override.forcedOff,
      );
      expect(settings.overrideOfForm('nouns', 'gen.sg'), Override.forcedOff);
      expect(
        settings.isFeatureEnabled('verbs', 'genus_verbi', 'pass'),
        isFalse,
      );
    });
  });
}
