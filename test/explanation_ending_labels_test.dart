import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every type whose ending can be named has a display phrase', () {
    final shown = borrowedEndings.values.expand((types) => types).toSet();
    expect(endingTypePhrases.keys.toSet(), shown);
  });

  test('a shown ending type without a phrase throws, naming the type', () {
    expect(
      () => endingTypePhrase('Ohne-Etikett'),
      throwsA(predicate((e) => e.toString().contains('Ohne-Etikett'))),
    );
  });
}
