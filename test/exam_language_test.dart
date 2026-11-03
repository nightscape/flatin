import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:yaml/yaml.dart';

import 'support/gen_exam.dart';

const _golden = 'test/fixtures/guard/exam_codes.txt';
const _packs = 300;

/// The synthetic pack first, then drawn packs; read inside the tests, so a
/// pack the parser refuses fails a named test.
final List<(String, Map<String, Object>)> _cases = [
  (
    'synthetic',
    examToYaml(
      parseExam(
        File('test/fixtures/exam/synthetic.exam').readAsStringSync(),
        latin,
      ),
    ),
  ),
  for (var seed = 1; seed <= _packs; seed++)
    ('seed $seed', ExamGen(Random(seed)).exam()),
];

/// Every word token of [exam] with its path.
Iterable<(Map, String)> _words(Map exam) sync* {
  for (final (i, s) in (exam['uebersetzung']['saetze'] as List).indexed) {
    for (final (j, t) in (s['tokens'] as List).indexed) {
      if (t.containsKey('lemma')) {
        yield (t, 'exam.uebersetzung.saetze[$i].tokens[$j]');
      }
    }
  }
}

Iterable<(Map, String)> _clauses(Map exam) sync* {
  for (final (i, s) in (exam['uebersetzung']['saetze'] as List).indexed) {
    for (final (k, c) in (s['teilsaetze'] as List).indexed) {
      yield (c, 'exam.uebersetzung.saetze[$i].teilsaetze[$k]');
    }
  }
}

/// The code lists of la.yaml as a mutable copy of plain maps and lists.
Map<String, dynamic> _latinData() =>
    jsonDecode(jsonEncode(loadYaml(File(latinAsset).readAsStringSync())))
        as Map<String, dynamic>;

/// A rule parameter of la.yaml changed, and the errors a pack gets for it.
typedef _Mutation = ({
  String name,
  Language language,
  Set<String> Function(Map exam) errors,
});

List<_Mutation> _mutations(Random r) {
  T pick<T>(List<T> xs) => xs[r.nextInt(xs.length)];
  _Mutation mutation(
    String name,
    void Function(Map<String, dynamic> rules) change,
    Set<String> Function(Map exam) errors,
  ) {
    final data = _latinData();
    change(data['rules'] as Map<String, dynamic>);
    return (
      name: name,
      language: Language.parse(jsonEncode(data)),
      errors: errors,
    );
  }

  final tense = pick(['perf', 'plusq', 'fut2']);
  final tempusCodes = codes('tempus').cast<String>();
  final main = pick([
    for (final a in latin.clauseArt)
      if (a != 'haupt') a,
  ]);
  Set<String> pairs(Map exam, bool Function(Map ppp) hit) {
    final byId = {for (final (t, p) in _words(exam)) t['id']: (t, p)};
    return {
      for (final (t, path) in _words(exam))
        if (t['verbform'] case [final ppp, _] when hit(byId[ppp]!.$1))
          '$path.verbform',
    };
  }

  return [
    mutation(
      'compound.tense_map.$tense',
      (rules) => rules['compound']['tense_map'][tense] = pick([
        for (final t in tempusCodes)
          if (t != rules['compound']['tense_map'][tense]) t,
      ]),
      (exam) => {
        for (final path in pairs(
          exam,
          (ppp) =>
              ppp['analyse']['modus'] != 'inf' &&
              ppp['analyse']['tempus'] == tense,
        ))
          'E-verbform-agree $path',
      },
    ),
    mutation(
      'compound.aux.lemma',
      (rules) => rules['compound']['aux']['lemma'] = 'fuisse',
      (exam) => {
        for (final path in pairs(exam, (_) => true)) 'E-verbform-pair $path',
      },
    ),
    mutation(
      'participle.form.tempus',
      (rules) => rules['participle']['form']['tempus'] = pick([
        for (final t in tempusCodes)
          if (t != 'perf') t,
      ]),
      (exam) => {
        for (final (t, path) in _words(exam))
          if (t['analyse']['modus'] == 'part') 'E-participle-ppp $path',
      },
    ),
    mutation('main_clause $main', (rules) => rules['main_clause'] = main, (
      exam,
    ) {
      return {
        for (final (c, path) in _clauses(exam))
          if (c['art'] == 'haupt' && !c.containsKey('uebergeordnet'))
            'E-uebergeordnet $path',
      };
    }),
    mutation(
      'no_role + subst',
      (rules) => (rules['no_role'] as List).add('subst'),
      (exam) => {
        for (final (t, path) in _words(exam))
          if (t['analyse']['wortart'] == 'subst' && t.containsKey('rolle'))
            'E-rolle-none $path',
      },
    ),
  ];
}

Set<String> _errors(Map<String, Object> exam, Language language) {
  try {
    parseExam(jsonEncode(exam), language);
    return {};
  } on ExamRejected catch (e) {
    return {for (final x in e.errors) '${x.rule.id} ${x.path}'};
  }
}

/// Update with `flutter test --update-goldens test/exam_language_test.dart`.
void main() {
  // An example test: it pins the codes of the one real language file, which
  // has no input space to draw from. A renamed code makes stored packs
  // unreadable.
  test('la.yaml has exactly the exam codes of the golden', () {
    final codes = [
      for (final MapEntry(:key, :value) in latin.axes.entries)
        for (final code in value) '$key\t$code',
    ]..sort();
    if (autoUpdateGoldenFiles) {
      File(_golden).writeAsStringSync('${codes.join('\n')}\n');
    }

    final golden = File(_golden).readAsLinesSync();
    expect(golden, orderedEquals([...golden]..sort()));
    final diff = {
      'in la.yaml, not in the golden': codes.toSet().difference(golden.toSet()),
      'in the golden, not in la.yaml': golden.toSet().difference(codes.toSet()),
    };
    expect(diff, {for (final kind in diff.keys) kind: isEmpty});
  });

  test('L1: the drawn packs use every code of la.yaml, per axis', () {
    final drawn = <String, Set<Object>>{};
    void add(String axis, Object? code) {
      if (code != null) (drawn[axis] ??= {}).add(code);
    }

    for (final (_, exam) in _cases.skip(1)) {
      for (final (t, _) in _words(exam)) {
        add('rolle', t['rolle']);
        (t['analyse'] as Map).forEach((k, v) => add('analyse.$k', v));
      }
      for (final (c, _) in _clauses(exam)) {
        add('clause.art', c['art']);
        add('clause.sinnrichtung', c['sinnrichtung']);
      }
    }
    expect(drawn, {
      for (final MapEntry(:key, :value) in latin.axes.entries)
        key: value.toSet(),
    });
  });

  test('L2: a rule parameter changed in a copy of la.yaml refuses a pack '
      'exactly at the sites of that rule', () {
    final reached = <String, int>{};
    for (final (i, (name, exam)) in _cases.indexed) {
      expect(_errors(exam, latin), isEmpty, reason: name);
      for (final m in _mutations(Random(i))) {
        final want = m.errors(exam);
        if (want.isNotEmpty) {
          final kind = m.name.split(RegExp('[ .]')).first;
          reached[kind] = (reached[kind] ?? 0) + 1;
        }
        expect(_errors(exam, m.language), want, reason: '$name ${m.name}');
      }
    }
    expect(reached.keys, {'compound', 'participle', 'main_clause', 'no_role'});
  });
}
