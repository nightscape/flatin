import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/grammar/schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every type whose ending can be named has a display phrase', () {
    final shown = borrowedEndings.values.expand((types) => types).toSet();
    expect(endingTypePhrases.keys.toSet(), shown);
  });

  test('every type phrase exists in every data language', () {
    for (final phrases in [
      ...endingTypePhrases.values,
      ...diagnosisOnlyTypePhrases.values,
    ]) {
      expect(phrases.keys, unorderedEquals(dataLanguages), reason: '$phrases');
    }
  });

  test('a shown ending type without a phrase throws, naming the type', () {
    expect(
      () => endingTypePhrase('Ohne-Etikett', 'de'),
      throwsA(predicate((e) => e.toString().contains('Ohne-Etikett'))),
    );
  });
}
