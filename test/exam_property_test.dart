import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';

import 'support/gen_exam.dart';

const _packs = 300;
const _variants = 3000;

/// The fixed packs the seeded loops run first.
Map<String, Object> _synthetic() => examToYaml(
  parseExam(
    File('test/fixtures/exam/synthetic.exam').readAsStringSync(),
    latin,
  ),
);

/// The synthetic pack with one more task: a `bilden` item of a PPP.
Map<String, Object> _withPppBilden() {
  final exam = _synthetic();
  (exam['aufgaben'] as List).add({
    'id': 'z99',
    'titel': 'Partizip',
    'punkte': 1,
    'art': 'bilden',
    'frage': 'Bilde das PPP.',
    'items': [
      {...pppBilden('portātus'), 'punkte': 1},
    ],
    'loesung': <String>[],
  });
  exam['punkte_gesamt'] = (exam['punkte_gesamt'] as int) + 1;
  return exam;
}

Iterable<(String, Map<String, Object>, ExamGen)> _cases() sync* {
  yield ('synthetic', _synthetic(), ExamGen(Random(0)));
  yield ('one-word PPP bilden', _withPppBilden(), ExamGen(Random(0)));
  for (var seed = 1; seed <= _packs; seed++) {
    final gen = ExamGen(Random(seed));
    yield ('seed $seed', gen.exam(), gen);
  }
}

Map<String, dynamic> _copy(Map<String, Object> exam) =>
    jsonDecode(jsonEncode(exam)) as Map<String, dynamic>;

/// [exam] as text that breaks [rule] once, and the path its error names.
(String, String)? _broken(ExamRule rule, Map<String, Object> exam, Random r) {
  if (rule == ExamRule.yaml) return breakYaml(blockYaml(exam), r);
  final broken = _copy(exam);
  final path = breakRule(rule, broken, r);
  return path == null ? null : (jsonEncode(broken), path);
}

/// The variant strings of [exam]: every site the variant syntax holds for.
List<String> _variantStrings(Map<String, Object> exam) {
  final out = <String>[];
  for (final s in (exam['uebersetzung'] as Map)['saetze'] as List) {
    out.addAll((s['de'] as List).cast());
    for (final c in s['teilsaetze'] as List) {
      out.addAll((c['de'] as List).cast());
      out.addAll([for (final a in c['ausrichtung'] as List) a['de'] as String]);
    }
  }
  for (final t in exam['aufgaben'] as List) {
    if (t['art'] == 'umformen' || t['art'] == 'vokabel') {
      for (final i in t['items'] as List) {
        out.addAll(((i['ziel'] ?? i['de']) as List).cast());
      }
    }
  }
  return out;
}

void main() {
  final cases = _cases().toList();

  test('P1: a valid pack survives parse and serialize unchanged', () {
    final reach = <String, int>{};
    final nullKeys = <String>{};
    var seed = 0;
    for (final (name, yaml, gen) in cases) {
      final withNull = _copy(yaml);
      nullKeys.add(nullOptional(withNull, Random(seed++)));
      expect(
        examToYaml(parseExam(jsonEncode(withNull), latin)),
        equals(yaml),
        reason: name,
      );
      final exam = parseExam(jsonEncode(yaml), latin);
      expect(examToYaml(exam), equals(yaml), reason: name);
      expect(
        examToYaml(parseExam(serializeExam(exam), latin)),
        equals(yaml),
        reason: name,
      );
      expect(
        examToYaml(parseExam(blockYaml(yaml), latin)),
        equals(yaml),
        reason: name,
      );
      gen.reach.forEach((k, v) => reach[k] = (reach[k] ?? 0) + v);
    }
    final wanted = [
      ...ExamGen.reachKeys,
      for (final a in ItemArt.values) 'task ${a.code}',
      'task ordnen',
      'task frei',
      for (final a in latin.clauseArt) 'clause $a',
    ];
    expect([
      for (final k in wanted)
        if ((reach[k] ?? 0) == 0) k,
    ], isEmpty);
    expect(nullKeys, {
      'rolle',
      'bezug',
      'verbform',
      'uebergeordnet',
      'sinnrichtung',
      'teilsatz',
      'kasus',
      'numerus',
      'genus',
      'person',
      'tempus',
      'modus',
      'genus_verbi',
      'pronomen',
      'funktion',
    });
  });

  test('P2: each broken rule is refused with its rule id and path', () {
    final reached = <ExamRule, int>{};
    for (final rule in ExamRule.values) {
      var seed = 0;
      for (final (name, yaml, _) in cases) {
        final broken = _broken(rule, yaml, Random(seed++));
        if (broken == null) continue;
        final (source, path) = broken;
        reached[rule] = (reached[rule] ?? 0) + 1;
        expect(
          () => parseExam(source, latin),
          throwsA(
            isA<ExamRejected>().having(
              (e) => [for (final x in e.errors) '${x.rule.id} ${x.path}'],
              'errors',
              contains('${rule.id} $path'),
            ),
          ),
          reason: '$name ${rule.id}',
        );
      }
    }
    expect([
      for (final rule in ExamRule.values)
        if (!reached.containsKey(rule)) rule.id,
    ], isEmpty);
  });

  test('P4: expand equals an independent expander and the matcher '
      'accepts each reading', () {
    final r = Random(7);
    final gen = ExamGen(r);
    final fixed = _variantStrings(cases.first.$2);
    final strings = [
      ...fixed,
      for (var i = 0; i < _variants; i++)
        i.isEven
            ? gen.variant(3, true)
            : String.fromCharCodes([
                for (var j = 0; j < r.nextInt(12); j++)
                  ' ab()[]|'.codeUnitAt(r.nextInt(8)),
              ]),
    ];
    var malformed = 0;
    for (final s in strings) {
      final want = _Oracle(s).readings();
      if (want == null) {
        malformed++;
        expect(() => expand(s), throwsFormatException, reason: s);
        continue;
      }
      expect(expand(s), want, reason: s);
      for (final reading in want.take(5)) {
        expect(variantAccepts(s, ' $reading '), isTrue, reason: s);
      }
    }
    expect(fixed, isNotEmpty);
    expect(malformed, greaterThan(0));
    expect(gen.reach['nested variant'], greaterThan(0));
    expect(gen.reach['mark in variant'], greaterThan(0));
    expect(gen.reach['quote around variant'], greaterThan(0));
  });

  test('P4b: a group next to punctuation or a German quote leaves no '
      'gap', () {
    final gen = ExamGen(Random(13));
    for (final mark in [',', '.', ';', ':', '!', '?']) {
      for (var i = 0; i < 100; i++) {
        final (s, want) = gen.groupBeforeMark(mark);
        expect(expand(s), want, reason: s);
        expect(variantAccepts(s, want.first), isTrue, reason: s);
      }
    }
  });

  test('P5: the matcher refuses a reading changed by one word', () {
    final gen = ExamGen(Random(11));
    final texts = <(String, String, String)>[
      ('(der | Wolf) sieht', 'sieht', 'static drop'),
      ('der [Wolf] sieht', 'der Wolf Wald sieht', 'static add'),
      ('(der Wolf | im Wald) sieht', 'Wolf der sieht', 'static swap'),
      ('[der] Wolf', 'der $outsideWord', 'static replace'),
      ('(der (Wolf | Wald) | im) [sieht]', 'Wald der sieht', 'static swap'),
      ('(a | b)', 'a b', 'static both'),
      ('[x]', 'x x', 'static twice'),
    ];
    for (var i = 0; i < _variants; i++) {
      final s = gen.variant(3, true);
      final reading = gen.pick(_Oracle(s).readings()!);
      for (final m in ReadingMutation.values) {
        final text = gen.mutate(reading, m);
        if (text != null) texts.add((s, text, m.name));
      }
    }
    final reach = <String, int>{};
    for (final (s, text, kind) in texts) {
      expect(s, isNot(contains(outsideWord)));
      if (_Oracle(s).readings()!.contains(_Oracle(text).readings()!.single)) {
        continue;
      }
      expect(variantAccepts(s, text), isFalse, reason: '$kind: "$s" "$text"');
      if (kind.startsWith('static')) continue;
      for (final k in [
        kind,
        if (s.contains('[')) 'optional',
        if (_depth(s) > 1) 'nested',
      ]) {
        reach[k] = (reach[k] ?? 0) + 1;
      }
    }
    expect([
      for (final k in [
        for (final m in ReadingMutation.values) m.name,
        'optional',
        'nested',
      ])
        if ((reach[k] ?? 0) == 0) k,
    ], isEmpty);
  });
}

int _depth(String s) {
  var depth = 0, most = 0;
  for (final c in s.split('')) {
    if ('(['.contains(c)) most = max(most, ++depth);
    if (')]'.contains(c)) depth--;
  }
  return most;
}

/// A recursive-descent reading of the variant grammar:
/// `text := part*`, `part := char | '(' alts ')' | '[' alts ']'`,
/// `alts := text ('|' text)*`; null when [s] is not in the grammar.
final class _Oracle {
  final String s;
  var i = 0;
  _Oracle(this.s);

  List<String>? readings() {
    final text = _text();
    if (text == null || i != s.length) return null;
    return [
      for (final t in text)
        t
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAllMapped(RegExp(r' +([,.;:!?“])'), (m) => m[1]!)
            .replaceAllMapped(RegExp(r'„ +'), (_) => '„')
            .trim(),
    ];
  }

  List<String>? _text() {
    var out = [''];
    while (i < s.length && !'|)]'.contains(s[i])) {
      final c = s[i++];
      List<String> part;
      if (c == '(' || c == '[') {
        final alts = _alts();
        if (alts == null || i >= s.length || s[i] != (c == '(' ? ')' : ']')) {
          return null;
        }
        i++;
        part = c == '[' ? [...alts, ''] : alts;
      } else {
        part = [c];
      }
      out = [
        for (final a in out)
          for (final b in part) a + b,
      ];
    }
    return out;
  }

  List<String>? _alts() {
    final out = <String>[];
    while (true) {
      final text = _text();
      if (text == null) return null;
      out.addAll(text);
      if (i < s.length && s[i] == '|') {
        i++;
      } else {
        return out;
      }
    }
  }
}
