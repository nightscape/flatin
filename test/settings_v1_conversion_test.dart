import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/settings_conversion.dart';
import 'package:flutter/widgets.dart';

import 'support/stored_settings.dart';

Map<String, dynamic> _v1({
  required List<String> nounTypes,
  required List<String> verbTypes,
}) =>
    {
      'disabledForms': {
        'nouns': ['genitive_singular'],
        'verbs': ['praesens_first_person_singular'],
      },
      'disabledTypes': {'nouns': nounTypes, 'verbs': verbTypes},
      'inputStrategyIds': <String, String>{},
      'deselectedWords': <String>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app opens v1 settings with the same choices switched off',
      (tester) async {
    await openSettingsWith(
      tester,
      _v1(
        nounTypes: ['Konsonantische-Deklination-mf', 'Pronomen-is-maskulinum'],
        verbTypes: ['E-Konjugation (s-Perfekt)'],
      ),
    );

    expect(isChecked(tester, formTile('nouns', 'gen.sg')), isFalse);
    expect(isChecked(tester, formTile('nouns', 'nom.sg')), isTrue);
    expect(isChecked(tester, formTile('verbs', 'ind.praes.akt.1.sg')), isFalse);
    expect(isChecked(tester, formTile('verbs', 'ind.praes.akt.2.sg')), isTrue);

    expect(isChecked(tester, typeTile('Konsonantische-Deklination-mf')),
        isFalse);
    expect(isChecked(tester, typeTile('A-Deklination')), isTrue);
    // One of the three old names is not the merged type.
    expect(isChecked(tester, typeTile('Pronomen-is')), isTrue);
    expect(isChecked(tester, typeTile('E-Konjugation')), isTrue);

    final stored = await storedSettings();
    expect(stored[settingsVersionField], settingsVersion);
    expect(stored['disabledTypes']['nouns'], ['Konsonantische-Deklination-mf']);
    expect(stored['disabledTypes']['verbs'], isEmpty);

    await tester.pumpWidget(const SizedBox());
    await openSettingsWith(
      tester,
      _v1(
        nounTypes: [
          'Pronomen-is-maskulinum',
          'Pronomen-is-femininum',
          'Pronomen-is-neutrum',
        ],
        verbTypes: [
          'E-Konjugation',
          'E-Konjugation (Stammperfekt)',
          'E-Konjugation (s-Perfekt)',
        ],
      ),
    );

    expect(isChecked(tester, typeTile('Pronomen-is')), isFalse);
    expect(isChecked(tester, typeTile('E-Konjugation')), isFalse);
    expect(isChecked(tester, typeTile('A-Konjugation')), isTrue);
  });
}
