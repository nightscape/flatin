import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';

// "sst" after a short vowel is the stem (lässt, musst); after a long vowel or diphthong it is stem plus -st.
final _wrongEnding = RegExp(
  r'([ßzx]|(ei|ie|au|eu|äu|aa|ee|oo|[aeiouäöü]h)s)st\b',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final latinVerbs = parseGrammarFiles({
    for (final path in [
      'lib/data/latin_nouns.yaml',
      'lib/data/latin_verbs.yaml',
    ])
      path: File(path).readAsStringSync(),
  }).singleWhere((f) => f.dataFileId == 'verbs');
  final german = GrammarGermanForms(
    File(
      Platform.environment['GERMAN_VERBS_YAML'] ?? 'lib/data/german_verbs.yaml',
    ).readAsStringSync(),
    latinVerbs,
  );

  test(
    'no German present 2sg drops the ending s after a stem on s, ß, z or x',
    () async {
      final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
      final bad = <String>[];
      for (final item in items) {
        for (final key in item.formOrder) {
          if (!german.covers(item, key)) continue;
          final is2sgPresent = key.contains('.praes.') && key.endsWith('.2.sg');
          for (final form in german.accepted(item, key)) {
            if (is2sgPresent && _wrongEnding.hasMatch(form)) {
              bad.add('${item.id} $key $form');
            }
            if (RegExp(r'reisst|liesst').hasMatch(form)) {
              bad.add('${item.id} $key $form');
            }
          }
        }
      }
      expect(bad, isEmpty);
    },
  );

  test('s_est and sz_est fire only at the word-final seam', () async {
    final yaml = File(
      Platform.environment['GERMAN_VERBS_YAML'] ?? 'lib/data/german_verbs.yaml',
    ).readAsStringSync();
    final regular = GrammarGermanForms(
      yaml
          .replaceFirst('praesens_2sg: speist, ', '')
          .replaceFirst('praesens_2sg: grüßt, ', ''),
      latinVerbs,
    );
    final items = await loadPracticeItems('lib/data/latin_verbs.yaml');
    for (final (id, preterite) in [
      ('verbs:cenare', 'du speistest'),
      ('verbs:salutare', 'du grüßtest'),
    ]) {
      final item = items.singleWhere((i) => i.id == id);
      expect(
        regular.accepted(item, 'ind.praes.akt.2.sg').single,
        isNot(endsWith('est')),
        reason: id,
      );
      expect(regular.accepted(item, 'ind.impf.akt.2.sg'), [preterite]);
    }
  });
}
