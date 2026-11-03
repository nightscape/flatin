import 'dart:convert';
import 'dart:math';

import 'package:yaml/yaml.dart';

/// A grammar data file as ordered plain maps and lists, so a test can edit it
/// and parse it again through [grammarSource].
Map<String, dynamic> grammarTree(String yaml) =>
    _plain(loadYaml(yaml)) as Map<String, dynamic>;

/// [tree] as data file text (JSON is YAML).
String grammarSource(Map<String, dynamic> tree) => jsonEncode(tree);

Object? _plain(Object? node) => switch (node) {
  YamlMap() => <String, dynamic>{
    for (final e in node.entries) '${e.key}': _plain(e.value),
  },
  YamlList() => [for (final v in node) _plain(v)],
  _ => node,
};

enum GrammarBreak { unknownAxis, unknownCode, unknownKey, endingsDrop }

/// The rule a broken file must throw and a clause its message must hold.
typedef GrammarBroken = ({String rule, String clause});

/// Breaks one site of the `voice:` or `follows:` block of [tree] with [kind]
/// and returns what the parse must throw, or null when [tree] has no such site.
GrammarBroken? breakGrammar(
  Map<String, dynamic> tree,
  GrammarBreak kind,
  Random r,
) {
  T pick<T>(List<T> xs) => xs[r.nextInt(xs.length)];
  final n = r.nextInt(1000);
  final sites = _sites(tree);
  switch (kind) {
    case GrammarBreak.unknownKey:
      final blocks = [...sites.blocks];
      if (blocks.isEmpty) return null;
      final block = pick(blocks);
      block.node['extra_$n'] = 'x';
      return (
        rule: block.rule,
        clause: '${block.path}: unknown key "extra_$n"',
      );
    case GrammarBreak.unknownAxis:
      final axis = 'axis_$n';
      final choices = [
        for (final p in sites.patterns)
          () {
            p.node[axis] = 'x';
            return (rule: p.rule, clause: '${p.path}: "$axis" is no axis');
          },
        for (final a in sites.axisRefs)
          () {
            a.set(axis);
            return (rule: a.rule, clause: '${a.path}: "$axis" is no axis');
          },
      ];
      return choices.isEmpty ? null : pick(choices)();
    case GrammarBreak.unknownCode:
      final code = 'q${n}x';
      final choices = [
        for (final p in sites.patterns)
          for (final axis in p.node.keys.toList())
            () {
              final codes = p.node[axis];
              p.node[axis] = codes is List
                  ? ([...codes]..insert(r.nextInt(codes.length + 1), code))
                  : code;
              return (
                rule: p.rule,
                clause: '${p.path}.$axis: "$code" is no $axis code',
              );
            },
        for (final c in sites.codeRefs)
          () {
            c.set(code);
            return (
              rule: c.rule,
              clause: '${c.path}: "$code" is no ${c.axis} code',
            );
          },
      ];
      return choices.isEmpty ? null : pick(choices)();
    case GrammarBreak.endingsDrop:
      final rules = [...sites.endingRules];
      if (rules.isEmpty) return null;
      final rule = pick(rules);
      final from = rule.node['from'] as Map<String, dynamic>;
      rule.node['drop'] = [
        pick([
          ...(tree['axes'] as Map).keys.where((a) => !from.containsKey(a)),
        ]),
      ];
      return (rule: 'S30', clause: '${rule.path}: an endings rule has drop');
  }
}

typedef _Node = ({String rule, String path, Map<String, dynamic> node});
typedef _Ref = ({String rule, String path, void Function(String) set});
typedef _CodeRef = ({
  String rule,
  String path,
  String axis,
  void Function(String) set,
});

({
  List<_Node> blocks,
  List<_Node> patterns,
  List<_Node> endingRules,
  List<_Ref> axisRefs,
  List<_CodeRef> codeRefs,
})
_sites(Map<String, dynamic> tree) {
  final blocks = <_Node>[];
  final patterns = <_Node>[];
  final endingRules = <_Node>[];
  final axisRefs = <_Ref>[];
  final codeRefs = <_CodeRef>[];

  void patternList(String rule, String path, List<dynamic> list) {
    for (final (i, p) in list.indexed) {
      patterns.add((rule: rule, path: '$path[$i]', node: p));
    }
  }

  if (tree['voice'] case final Map<String, dynamic> voice) {
    blocks.add((rule: 'S29', path: 'voice', node: voice));
    axisRefs.add((
      rule: 'S29',
      path: 'voice.axis',
      set: (v) => voice['axis'] = v,
    ));
    for (final side in ['active', 'passive']) {
      codeRefs.add((
        rule: 'S29',
        path: 'voice.$side',
        axis: voice['axis'] as String,
        set: (v) => voice[side] = v,
      ));
    }
    if (voice['deponent'] case final Map<String, dynamic> deponent) {
      blocks.add((rule: 'S29', path: 'voice.deponent', node: deponent));
      axisRefs.add((
        rule: 'S29',
        path: 'voice.deponent.by',
        set: (v) => deponent['by'] = v,
      ));
      patternList('S29', 'voice.deponent.moves', deponent['moves']);
    }
    if (voice['impersonal'] case final Map<String, dynamic> impersonal) {
      blocks.add((rule: 'S29', path: 'voice.impersonal', node: impersonal));
      patternList('S29', 'voice.impersonal.personal', impersonal['personal']);
      patterns.add((
        rule: 'S29',
        path: 'voice.impersonal.agrees',
        node: impersonal['agrees'],
      ));
    }
  }

  for (final (i, rule) in ((tree['follows'] as List?) ?? const []).indexed) {
    final path = 'follows[$i]';
    final node = rule as Map<String, dynamic>;
    blocks.add((rule: 'S30', path: path, node: node));
    if (node['by'] == 'endings') {
      endingRules.add((rule: 'S30', path: path, node: node));
    }
    patterns.add((rule: 'S30', path: '$path.when', node: node['when']));
    patterns.add((rule: 'S30', path: '$path.from', node: node['from']));
    if (node['drop'] case final List<dynamic> drop) {
      for (final j in drop.indexed.map((e) => e.$1)) {
        axisRefs.add((
          rule: 'S30',
          path: '$path.drop',
          set: (v) => drop[j] = v,
        ));
      }
    }
  }
  return (
    blocks: blocks,
    patterns: patterns,
    endingRules: endingRules,
    axisRefs: axisRefs,
    codeRefs: codeRefs,
  );
}
