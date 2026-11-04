import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart';

import 'support/gen_verbs_file.dart';
import 'support/grammar_breaker.dart';

/// Each verbs file with the nouns file its types link to (S12).
const _sources = {
  'lib/data/latin_verbs.yaml': 'lib/data/latin_nouns.yaml',
  'test/fixtures/grammar_examples_verbs.yaml':
      'test/fixtures/grammar_examples.yaml',
};

void _expectRejected(Map<String, dynamic> tree, GrammarBroken broken) {
  expect(
    () => parseGrammarFiles({'broken.yaml': grammarSource(tree)}),
    throwsA(
      isA<SchemaError>()
          .having((e) => e.rule, 'rule', broken.rule)
          .having((e) => e.message, 'message', contains(broken.clause)),
    ),
  );
}

void main() {
  group('S29/S30 validation', () {
    for (final MapEntry(key: path, value: nounsPath) in _sources.entries) {
      final source = File(path).readAsStringSync();

      test('$path: the plain tree parses as the file does', () {
        final nouns = {nounsPath: File(nounsPath).readAsStringSync()};
        final [_, file] = parseGrammarFiles({...nouns, path: source});
        final [_, plain] = parseGrammarFiles({
          ...nouns,
          'plain.yaml': grammarSource(grammarTree(source)),
        });
        expect(plain.items.map((i) => i.id), file.items.map((i) => i.id));
        expect(plain.follows.length, file.follows.length);
      });

      test(
        '$path: an unknown axis in a follows pattern names its entry',
        () {
          final tree = grammarTree(source);
          (tree['follows'][0]['when'] as Map)['aspekt'] = 'x';
          _expectRejected(tree, (
            rule: 'S30',
            clause: 'follows[0].when: "aspekt" is no axis',
          ));
        },
        skip: grammarTree(source)['follows'] == null
            ? '$path has no follows: block'
            : false,
      );

      test('$path: an unknown code in a deponent move names its entry', () {
        final tree = grammarTree(source);
        (tree['voice']['deponent']['moves'][0] as Map)['modus'] = 'optativ';
        _expectRejected(tree, (
          rule: 'S29',
          clause: 'voice.deponent.moves[0].modus: "optativ" is no modus code',
        ));
      });

      for (final kind in GrammarBreak.values) {
        test(
          '$path: every ${kind.name} in voice or follows is rejected',
          () {
            for (var seed = 0; seed < 12; seed++) {
              final tree = grammarTree(source);
              final broken = breakGrammar(tree, kind, Random(seed))!;
              _expectRejected(tree, broken);
            }
          },
          skip: breakGrammar(grammarTree(source), kind, Random(0)) == null
              ? '$path has no site for ${kind.name}'
              : false,
        );
      }
    }
  });

  test('an impersonal item read as a deponent type is refused, naming the '
      'item', () {
    for (var seed = 0; seed < 50; seed++) {
      final r = Random(seed);
      final skeleton = drawVerbsFile(r);
      final type = r.nextBool() ? 'T' : 'T2';
      final drawn = skeleton.withItems([
        ...skeleton.items,
        (
          id: 'imp',
          type: type,
          stem: 'sty',
          deponent: null,
          impersonal: true,
          regularType: 'TD',
          overrides: <String, String>{},
        ),
      ]);
      expect(
        () => parseGrammarFiles({'gen.yaml': grammarSource(drawn.tree)}),
        throwsA(
          isA<SchemaError>()
              .having((e) => e.rule, 'rule', 'S15')
              .having((e) => e.item, 'item', 'imp~TD'),
        ),
        reason: 'seed $seed, own type $type',
      );
    }
  });

  test('drawn files derive the S10/S25 forms, and dropFollowing drops '
      'exactly the asked forms an S30 rule gives', () {
    final counts = <String, int>{};
    void count(String what) => counts[what] = (counts[what] ?? 0) + 1;

    for (var seed = 0; seed < 200; seed++) {
      final r = Random(seed);
      final skeleton = drawVerbsFile(r);
      final drawn = skeleton.withItems([
        ...skeleton.items,
        _impersonalAsRegular,
      ]);
      final file = parseGrammarFiles({
        'gen.yaml': grammarSource(drawn.tree),
      }).single;
      final engine = GrammarEngine([file]);
      if (drawn.rules.where((r) => r.endings).length > 1) {
        count('two endings rules');
      }
      final forms = {
        for (final item in drawn.items)
          item.id: drawn.formsOf(item, item.type, overrides: true),
      };
      final regular = {
        for (final item in drawn.items)
          if (item.regularType case final type?)
            item.id: drawn.formsOf(item, type, overrides: false),
      };
      final sets = _endingSets(drawn, forms);
      final rules = followRulesOf(file);
      final endings = endingSetsOf(engine, file);

      for (final item in drawn.items) {
        final reason = 'seed $seed, item ${item.id}';
        final own = forms[item.id]!;
        final derivation = engine.of('synthetic', item.id);
        expect(
          _spellings(derivation.forms),
          own.map((key, form) => MapEntry(key, [form])),
          reason: reason,
        );
        final regularDerivation = engine.regularOf('synthetic', item.id);
        expect(
          regularDerivation == null
              ? null
              : _spellings(regularDerivation.forms),
          regular[item.id]?.map((key, form) => MapEntry(key, [form])),
          reason: reason,
        );

        final asked = [...own.keys.where((_) => r.nextInt(4) > 0)];
        final shown = {...own.keys.where((_) => r.nextInt(8) == 0)};
        final available = {...asked, ...shown};
        final kept = [
          for (final key in asked)
            if (!drawn.rules.any((rule) {
              final gives = _gives(
                drawn,
                rule,
                item,
                key,
                own,
                regular[item.id],
                available,
                sets,
                count,
              );
              return gives != null && gives == own[key];
            }))
              key,
        ];
        expect(
          dropFollowing(
            rules,
            asked,
            shown,
            derivation.forms,
            regularDerivation?.forms,
            item.impersonal,
            endings,
          ),
          kept,
          reason: reason,
        );
        if (item.impersonal) count('impersonal item');
        if (item.type == 'TD' || item.deponent != null) count('deponent item');
        if (item.overrides.isNotEmpty) count('item with overrides');
      }
    }
    final realFiles = parseGrammarFiles({
      'lib/data/latin_nouns.yaml': File(
        'lib/data/latin_nouns.yaml',
      ).readAsStringSync(),
      'lib/data/latin_verbs.yaml': File(
        'lib/data/latin_verbs.yaml',
      ).readAsStringSync(),
    });
    final verbs = realFiles.last;
    final realRegular = GrammarEngine(realFiles).regularOf('verbs', 'ire')!;
    // The oracle of the real item: the same word, impersonal, as an item
    // of its regular type read by its own reading.
    final twinTree = grammarTree(
      File('lib/data/latin_verbs.yaml').readAsStringSync(),
    );
    final twin = (twinTree['items'] as List).cast<Map>().singleWhere(
      (item) => item['id'] == 'ire',
    );
    twin
      ..['type'] = twin.remove('regular_type')
      ..remove('forms');
    final twinFiles = parseGrammarFiles({
      'lib/data/latin_nouns.yaml': File(
        'lib/data/latin_nouns.yaml',
      ).readAsStringSync(),
      'lib/data/latin_verbs.yaml': grammarSource(twinTree),
    });
    final twinForms = GrammarEngine(twinFiles).of('verbs', 'ire').forms;
    expect(verbs.item('ire').impersonalPassive, isTrue);
    expect(_spellings(realRegular.forms), _spellings(twinForms));
    for (final what in [
      'by endings',
      'by regular',
      'impersonal rule',
      'ambiguous endings',
      'two endings rules',
      'impersonal item',
      'deponent item',
      'item with overrides',
    ]) {
      expect(counts[what], greaterThan(30), reason: '$what in $counts');
    }
  });
}

/// A fixed state kept in every drawn file: an impersonal item read as another
/// type, as `ire` is in the verbs file.
const DrawnItem _impersonalAsRegular = (
  id: 'static',
  type: 'T2',
  stem: 'stz',
  deponent: null,
  impersonal: true,
  regularType: 'T',
  overrides: <String, String>{},
);

Map<String, List<String>> _spellings(Map<String, FormDerivation> forms) =>
    forms.map((key, form) => MapEntry(key, form.variants));

(String, String) _swap(String from, String to) {
  var common = 0;
  while (common < from.length &&
      common < to.length &&
      from[common] == to[common]) {
    common++;
  }
  return (from.substring(common), to.substring(common));
}

String? _swapped(String form, (String, String) swap) => form.endsWith(swap.$1)
    ? form.substring(0, form.length - swap.$1.length) + swap.$2
    : null;

/// S30: the source of the key [features] by [rule], or null when the rule does
/// not reach it.
Map<String, String>? _sourceOf(DrawnRule rule, Map<String, String> features) {
  if (!rawMatches(features, rule.when) ||
      ![...rule.from.keys, ...rule.drop].every(features.containsKey) ||
      rule.drop.isEmpty &&
          rule.from.entries.every((e) => features[e.key] == e.value)) {
    return null;
  }
  return {...features, ...rule.from}
    ..removeWhere((axis, _) => rule.drop.contains(axis));
}

Map<String, String> _features(DrawnVerbsFile drawn, String key) {
  final codes = key.split('.');
  return {
    for (final MapEntry(key: axis, value: values) in drawn.axes.entries)
      axis: ?values.where(codes.contains).firstOrNull,
  };
}

/// A reached key's codes on the rule's `from` and `drop` axes.
String _target(DrawnRule rule, Map<String, String> features) => [
  for (final axis in [...rule.from.keys, ...rule.drop]) features[axis],
].join('.');

/// S30 `by: endings` read from the drawn forms: under each group (a source
/// without the `from` axes), the distinct swap sets that each type's first
/// item gives whose source and every key reached from it are generated forms.
Map<String, List<Map<String, (String, String)>>> _endingSets(
  DrawnVerbsFile drawn,
  Map<String, Map<String, String>> forms,
) {
  final byGroup = <String, Map<String, Map<String, (String, String)>>>{};
  final done = <String>{};
  for (final (index, rule) in drawn.rules.indexed) {
    if (!rule.endings) continue;
    for (final item in drawn.items) {
      final own = forms[item.id]!;
      bool generated(String key) =>
          own.containsKey(key) && !item.overrides.containsKey(key);
      for (final sourceKey in own.keys) {
        final source = _features(drawn, sourceKey);
        if (!rule.from.entries.every((e) => source[e.key] == e.value)) continue;
        final reached = [
          for (final features in drawn.keys)
            if (_sourceOf(rule, features) case final s?
                when drawn.keyOf(s) == sourceKey)
              features,
        ];
        if (reached.isEmpty ||
            !generated(sourceKey) ||
            !reached.every((f) => generated(drawn.keyOf(f))) ||
            !done.add('${item.type}/$index/$sourceKey')) {
          continue;
        }
        final group = {...source}
          ..removeWhere((axis, _) => rule.from.containsKey(axis));
        byGroup.putIfAbsent(drawn.keyOf(group), () => {})[item.type] = {
          for (final features in reached)
            _target(rule, features): _swap(
              own[sourceKey]!,
              own[drawn.keyOf(features)]!,
            ),
        };
      }
    }
  }
  String canonical(Map<String, (String, String)> set) =>
      ([for (final e in set.entries) '${e.key}=${e.value}']..sort()).join(';');
  return {
    for (final MapEntry(:key, :value) in byGroup.entries)
      key: {
        for (final set in value.values) canonical(set): set,
      }.values.toList(),
  };
}

/// The spelling [rule] gives [key] of [item] from an [available] form, or
/// null when it gives none.
String? _gives(
  DrawnVerbsFile drawn,
  DrawnRule rule,
  DrawnItem item,
  String key,
  Map<String, String> forms,
  Map<String, String>? regular,
  Set<String> available,
  Map<String, List<Map<String, (String, String)>>> sets,
  void Function(String) count,
) {
  if (rule.impersonal && !item.impersonal) return null;
  final features = _features(drawn, key);
  final source = _sourceOf(rule, features);
  if (source == null) return null;
  final sourceKey = drawn.keyOf(source);
  if (!available.contains(sourceKey)) return null;
  final spelling = forms[sourceKey]!;
  final String? gives;
  if (rule.endings) {
    final group = {...source}
      ..removeWhere((axis, _) => rule.from.containsKey(axis));
    final fitting = [
      for (final set in sets[drawn.keyOf(group)] ?? const [])
        if (set.values.every((swap) => spelling.endsWith(swap.$1))) set,
    ];
    if (fitting.length > 1) count('ambiguous endings');
    gives = fitting.length == 1
        ? _swapped(spelling, fitting.single[_target(rule, features)]!)
        : null;
  } else {
    final from = regular?[sourceKey];
    final to = regular?[key];
    gives = from == null || to == null
        ? null
        : _swapped(spelling, _swap(from, to));
  }
  if (gives != null && gives == forms[key]) {
    count(rule.endings ? 'by endings' : 'by regular');
    if (rule.impersonal) count('impersonal rule');
  }
  return gives;
}
