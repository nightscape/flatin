import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

void main() {
  late List<PracticeItem> items;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    items = await loadAllPracticeItems();
  });

  // Exhaustive over the shipped data rather than drawn: every generated form
  // is a case, and there are few enough to walk them all.
  test('each stem variant joined with its ending splits at the variant '
      'length', () {
    var checked = 0;
    for (final item in items) {
      final d = item.derivation;
      for (final MapEntry(:key, value: form) in d.forms.entries) {
        if (form is! GeneratedForm ||
            form.sandhiRule != null ||
            form.ending.isEmpty) {
          expect(d.stemOf(key, form.result), isNull, reason: '${item.id} $key');
          continue;
        }
        for (final v in d.stems[form.stemName]!.variants) {
          final stem = d.stemOf(key, v + form.ending)!;
          expect(stem.name, form.stemName);
          expect(
            stem.spelling.characters.length,
            v.characters.length,
            reason: '${item.id} $key $v',
          );
          checked++;
        }
        expect(
          d.stemOf(key, form.result)!.spelling,
          d.stems[form.stemName]!.stem,
          reason: '${item.id} $key',
        );
      }
    }
    expect(checked, greaterThan(0));
  });

  test('a text that no stem variant spells throws', () {
    final (item, key, form) = [
      for (final item in items)
        for (final MapEntry(:key, :value) in item.derivation.forms.entries)
          if (value is GeneratedForm &&
              value.sandhiRule == null &&
              value.ending.isNotEmpty)
            (item, key, value),
    ].first;
    expect(
      () => item.derivation.stemOf(key, 'x${form.result}'),
      throwsStateError,
    );
  });
}
