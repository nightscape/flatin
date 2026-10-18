import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:latin_practice/models/settings.dart';

Map<String, dynamic> _stored(Map<String, dynamic> fields) => {
      settingsVersionField: settingsVersion,
      ...fields,
    };

/// A stored settings file that forces one entry both on and off says two
/// things at once. [Settings.fromJson] rejects it before it builds the
/// settings, so the release build refuses it as well.
void main() {
  test('a word in both the on and the off set is refused', () {
    expect(
      () => Settings.fromJson(_stored({
        'deselectedWords': ['rosa'],
        'forcedOnWords': ['rosa'],
      })),
      throwsStateError,
    );
  });

  test('a type in both the on and the off set is refused', () {
    expect(
      () => Settings.fromJson(_stored({
        'disabledTypes': {
          'nouns': ['A-Deklination'],
        },
        'forcedOnTypes': {
          'nouns': ['A-Deklination'],
        },
      })),
      throwsStateError,
    );
  });

  test('a form in both the on and the off set is refused', () {
    expect(
      () => Settings.fromJson(_stored({
        'disabledForms': {
          'nouns': ['gen.sg'],
        },
        'forcedOnForms': {
          'nouns': ['gen.sg'],
        },
      })),
      throwsStateError,
    );
  });

  test('the same entry under another data file is no contradiction', () {
    final settings = Settings.fromJson(_stored({
      'disabledForms': {
        'nouns': ['gen.sg'],
      },
      'forcedOnForms': {
        'verbs': ['gen.sg'],
      },
    }));

    expect(settings.overrideOfForm('nouns', 'gen.sg'), Override.forcedOff);
    expect(settings.overrideOfForm('verbs', 'gen.sg'), Override.forcedOn);
  });
}
