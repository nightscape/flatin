import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/practice_item.dart';

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

  late List<PracticeItem> items;
  setUpAll(() async {
    items = await loadPracticeItems('lib/data/latin_verbs.yaml');
  });
  List<String> accepted(String id, String key) =>
      german.accepted(items.singleWhere((i) => i.id == id), key);

  group('a preterite stem on s or ß takes e before -st', () {
    test('besitzen', () {
      expect(accepted('verbs:possidere', 'ind.impf.akt.2.sg'), ['du besaßest']);
      expect(accepted('verbs:possidere', 'ind.impf.akt.2.pl'), ['ihr besaßt']);
      expect(accepted('verbs:possidere', 'ind.praes.akt.2.sg'), ['du besitzt']);
      expect(accepted('verbs:possidere', 'ind.perf.akt.2.sg'), [
        'du hast besessen',
        'du besaßest',
      ]);
    });
    test('lesen', () {
      expect(accepted('verbs:legere', 'ind.impf.akt.2.sg'), ['du lasest']);
      expect(accepted('verbs:legere', 'ind.impf.akt.2.pl'), ['ihr last']);
      expect(accepted('verbs:legere', 'ind.praes.akt.2.sg'), ['du liest']);
    });
    test('entlassen, wachsen, entreißen, zurückstoßen', () {
      expect(accepted('verbs:dimittere', 'ind.impf.akt.2.sg'), [
        'du entließest',
      ]);
      expect(accepted('verbs:crescere', 'ind.impf.akt.2.sg'), ['du wuchsest']);
      expect(accepted('verbs:crescere', 'ind.impf.akt.2.pl'), ['ihr wuchst']);
      expect(accepted('verbs:eripere', 'ind.impf.akt.2.sg'), ['du entrissest']);
      expect(accepted('verbs:repellere', 'ind.impf.akt.2.sg'), [
        'du stießest zurück',
      ]);
    });
  });
}
