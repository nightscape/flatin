import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/trace_fixtures.dart';

/// Every rendered line of [item], over all its forms and both entry points
/// the screens use.
List<String> _allLines(Map<String, String> texts, PracticeItem item) => [
      for (final key in item.derivation.forms.keys)
        for (final line in [
          ...explainForm(item, [key]),
          ...explainWrongAnswer(item, key, 'zzz'),
        ])
          renderDe(texts, line),
    ];

/// The derivation lines of the forms whose seam a rule changes.
List<String> _seamLines(Map<String, String> texts, PracticeItem item) => [
      for (final entry in item.derivation.forms.entries)
        if (entry.value case GeneratedForm(sandhiRule: final _?))
          _derivationLine(texts, item, entry.key),
    ];

/// The one line that derives [key] — the sum, with or without a seam rule.
String _derivationLine(
  Map<String, String> texts,
  PracticeItem item,
  FormKey key,
) =>
    renderDe(
      texts,
      explainWrongAnswer(item, key, 'zzz').firstWhere((l) =>
          l.key.startsWith('explain.sandhi') ||
          l.key.startsWith('explain.generated')),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("habēre: the seam rule stays, the endings are the item's own",
      () async {
    final texts = await germanTexts();
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final item = verbs.firstWhere((i) => i.lemma == 'habēre');
    final lines = explainWrongAnswer(item, 'ind.praes.akt.3.sg', 'habat');
    final line = lines.firstWhere((l) => l.key.startsWith('explain.sandhi'));
    expect(line.key, 'explain.sandhi');
    expect(line.params, {
      'label': 'Präsens: 3. Person Singular',
      'before': 'habē + t',
      'after': 'habet',
      'rule': 'Vokal vor -t am Wortende wird kurz',
    });
    expect(
      renderDe(texts, line),
      'Präsens: 3. Person Singular: habē + t = habet '
      '(Vokal vor -t am Wortende wird kurz)',
    );
    // Every conjugation shares the perfect endings, so the type that declares
    // them is a name the learner is never taught.
    expect(
      _derivationLine(texts, item, 'ind.perf.akt.1.sg'),
      'Perfekt: 1. Person Singular: habu + ī = habuī',
    );
  });

  test('capere: a borrowed ending names the type it comes from', () async {
    final texts = await germanTexts();
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final item = verbs.firstWhere((i) => i.lemma == 'capere');
    expect(
      _derivationLine(texts, item, 'inf.praes.akt'),
      'Infinitiv Präsens: capi + re = capere '
      '(i wird vor r zu e; Endung der I-Konjugation)',
    );
  });

  test('a line names a type only for a borrowed-ending pair', () async {
    final texts = await germanTexts();
    final named = <String, Set<String>>{};
    var checked = 0;
    for (final path in const [
      'lib/data/latin_verbs.yaml',
      'lib/data/latin_nouns.yaml',
    ]) {
      for (final item in await loadPracticeItems(path)) {
        for (final line in _allLines(texts, item)) {
          checked++;
          final types = endingTypePhrases.entries
              .where((e) => line.endsWith('${e.value})'))
              .map((e) => e.key)
              .toList();
          if (types.isEmpty) continue;
          (named[item.type] ??= {}).add(types.single);
        }
      }
    }
    expect(checked, greaterThan(10000));
    // No internal type (Perfekt-System, Verb-Basis, Verb-Vollständig) and no
    // A-Konjugation under E-Konjugation.
    expect(named, {
      'A-Konjugation': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
      'E-Konjugation': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
      'I-Konjugation': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
      'Konsonantische': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
      'Mischkonjugation': {
        'I-Konjugation',
        '3-Endungen',
        '3-Endungen-Partizip',
        'a-o-Endungen',
      },
      'Unregelmäßig': {'3-Endungen', '3-Endungen-Partizip', 'a-o-Endungen'},
      'esse-Typ': {'a-o-Endungen'},
      'Adjektiv-a-o': {'Komparativ-Endungen', 'a-o-Endungen'},
      'Adjektiv-a-o-er': {
        'Adjektiv-a-o',
        'Komparativ-Endungen',
        'a-o-Endungen',
        'a-o-er-Endungen',
      },
      'Adjektiv-dreiendig': {
        'Adjektiv-3',
        'Komparativ-Endungen',
        '3-Endungen',
        'a-o-Endungen',
      },
      'Adjektiv-zweiendig': {
        'Adjektiv-3',
        'Komparativ-Endungen',
        '3-Endungen',
        'a-o-Endungen',
      },
      'Konsonantische-Deklination-i-mf': {'Konsonantische-Deklination-mf'},
      'Konsonantische-Deklination-i-n': {'Konsonantische-Deklination-n'},
      'E-Deklination-Konsonantstamm': {'E-Deklination'},
    });
  });

  test('capere keeps its 16 I-Konjugation lines, word for word', () async {
    final texts = await germanTexts();
    final verbs = await loadPracticeItems('lib/data/latin_verbs.yaml');
    final item = verbs.firstWhere((i) => i.lemma == 'capere');
    final named = _seamLines(texts, item)
        .where((line) => line.contains('Endung der'))
        .toSet()
        .toList();
    expect(
      _allLines(texts, item).where((l) => l.contains('Endung der')).toSet(),
      hasLength(217),
    );
    expect(named, [
      'Präsens Passiv: 2. Person Singular: capi + ris = caperis '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt: 1. Person Singular: capi + rem = caperem '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt: 1. Person Plural: capi + rēmus = caperēmus '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt: 2. Person Singular: capi + rēs = caperēs '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt: 2. Person Plural: capi + rētis = caperētis '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt: 3. Person Singular: capi + ret = caperet '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt: 3. Person Plural: capi + rent = caperent '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt Passiv: 1. Person Singular: capi + rer = caperer '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt Passiv: 1. Person Plural: capi + rēmur = caperēmur '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt Passiv: 2. Person Singular: capi + rēris = '
          'caperēris (i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt Passiv: 2. Person Plural: capi + rēminī = '
          'caperēminī (i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt Passiv: 3. Person Singular: capi + rētur = '
          'caperētur (i wird vor r zu e; Endung der I-Konjugation)',
      'Konjunktiv Imperfekt Passiv: 3. Person Plural: capi + rentur = '
          'caperentur (i wird vor r zu e; Endung der I-Konjugation)',
      'Imperativ Präsens: 2. Person Singular: capi +  = cape '
          '(i wird am Wortende zu e; Endung der I-Konjugation)',
      'Imperativ Präsens Passiv: 2. Person Singular: capi + re = capere '
          '(i wird vor r zu e; Endung der I-Konjugation)',
      'Infinitiv Präsens: capi + re = capere '
          '(i wird vor r zu e; Endung der I-Konjugation)',
    ]);
  });
}
