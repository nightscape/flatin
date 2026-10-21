/// Parser and Dart model of the grammar data schema 3.2 (`lib/data/SCHEMA.md`).
///
/// This library reads and checks data; it generates no forms. It resolves type
/// inheritance (S6), the type of every item (S11) and the set of keys every
/// item has (S4, S10, S13, S14, S15) — the engine (`lib/grammar/engine.dart`)
/// fills those keys with forms and traces.
library;

import 'package:yaml/yaml.dart';

import '../data/lesson_data.dart' show normalizeDiacritics;
import '../models/form_label.dart';

/// A violation of one of the schema rules S1-S20.
class SchemaError implements Exception {
  final String rule;
  final String path;
  final String message;
  final String? item;
  final FormKey? key;

  SchemaError(this.rule, this.path, this.message, {this.item, this.key});

  @override
  String toString() {
    final where = [
      '$rule in $path',
      if (item != null) 'item "$item"',
      if (key != null) 'key "$key"',
    ].join(', ');
    return '$where: $message';
  }
}

String _norm(String text) => normalizeDiacritics(text).toLowerCase();

/// S20: every text shown to the learner is given in each of these languages.
const dataLanguages = ['de', 'en'];

/// The language the course is written in: what a learner reads when no other
/// data language is asked for.
const courseLanguage = 'de';

final _letters = RegExp(r'^[a-zāēīōūȳăĕĭŏŭ]+$', caseSensitive: false);
final _macron = RegExp(r'[āēīōūȳĀĒĪŌŪȲ]');

// ---------------------------------------------------------------- model

/// A principal part the items of a file may give.
final class PartSpec {
  final String name;
  final String label;

  /// false for parts that are internal, like a prefix.
  final bool display;

  PartSpec({required this.name, required this.label, this.display = true});
}

/// One `type_inference` rule (S11).
final class InferenceRule {
  final String part;
  final String suffix;
  final int? minLength;
  final List<String> types;

  InferenceRule({
    required this.part,
    required this.suffix,
    required this.types,
    this.minLength,
  });

  bool get isAmbiguous => types.length > 1;

  /// S11: a macronized suffix matches only an equally macronized spelling.
  bool matches(String spelling) {
    if (minLength != null && spelling.length < minLength!) return false;
    return _macron.hasMatch(suffix)
        ? spelling.toLowerCase().endsWith(suffix.toLowerCase())
        : _norm(spelling).endsWith(_norm(suffix));
  }

  @override
  String toString() => '$part suffix "$suffix" → ${types.join("/")}';
}

enum SandhiReplace { literal, short, doubleNext }

/// One rule of a file's sandhi library (S16).
final class SandhiRuleSpec {
  final String id;

  /// 'vowel', 'consonant' or a letter string the left side ends with.
  final String end;

  /// 'vowel' or 'consonant'; null when [beforeStarts] is given.
  final String? beforeClass;

  /// Letter strings the right side starts with; an entry ending in `$` matches
  /// only at a word-final seam, `"$"` alone matches the empty ending.
  final List<String>? beforeStarts;

  final SandhiReplace replace;

  /// The replacement text when [replace] is [SandhiReplace.literal].
  final String replaceText;

  final String explain;

  /// S9: the rule produces both spellings.
  final bool variant;

  SandhiRuleSpec({
    required this.id,
    required this.end,
    required this.replace,
    required this.replaceText,
    required this.explain,
    this.beforeClass,
    this.beforeStarts,
    this.variant = false,
  });
}

/// A form template: `{<stem>}<ending>` or a literal (S2).
final class FormTemplate {
  final String? stemName;
  final String ending;

  FormTemplate({this.stemName, required this.ending});

  @override
  String toString() => stemName == null ? ending : '{$stemName}$ending';
}

/// How one named stem of a type is built.
final class StemSpec {
  final String name;

  /// The principal part it is cut from, null for a pure [template].
  final String? from;

  /// Suffixes tried in order (S3); empty list means nothing is cut.
  final List<String> remove;

  /// Used when the item lacks [from].
  final FormTemplate? defaultTemplate;

  /// Used always; mutually exclusive with [from].
  final FormTemplate? template;

  final String? display;

  StemSpec({
    required this.name,
    this.from,
    this.remove = const [],
    this.defaultTemplate,
    this.template,
    this.display,
  });

  /// The template that builds this stem from another stem, if any.
  FormTemplate? get fromStem => template ?? defaultTemplate;
}

/// Endings of another type applied to own stems (S14).
final class DelegateSpec {
  final String name;
  final String type;

  /// Target stem name → own stem name.
  final Map<String, String> bind;

  /// Feature axis id → code added to every delegated key.
  final Map<String, String> set;

  /// false for internal forms (S8).
  final bool emit;

  DelegateSpec({
    required this.name,
    required this.type,
    required this.bind,
    required this.set,
    this.emit = true,
  });
}

sealed class ComposePart {
  /// S21: the text between this part and the next one; null takes the rule's.
  final String? join;

  /// S22: a part without a form drops out instead of removing the key.
  final bool optional;

  ComposePart({this.join, this.optional = false});

  /// Feature axis id → code set on the looked-up key.
  Map<String, String> get set;

  /// Feature axis ids passed from the composed key.
  List<String> get pass;

  /// Feature axis id → code translation table; the axis is passed implicitly.
  Map<String, Map<String, String>> get map;

  /// S13: the lexeme's own keys are used instead of a key built from axes.
  bool get passAll;
}

/// A form of a delegate of the same type.
final class SelfPart extends ComposePart {
  final String delegate;
  @override
  final Map<String, String> set;
  @override
  final List<String> pass;
  @override
  final Map<String, Map<String, String>> map;
  @override
  bool get passAll => false;

  SelfPart({
    required this.delegate,
    this.set = const {},
    this.pass = const [],
    this.map = const {},
    super.join,
    super.optional,
  });
}

/// A form of another item of the same file.
final class LexemePart extends ComposePart {
  final String lexeme;
  @override
  final Map<String, String> set;
  @override
  final List<String> pass;
  @override
  final Map<String, Map<String, String>> map;
  @override
  final bool passAll;

  LexemePart({
    required this.lexeme,
    this.set = const {},
    this.pass = const [],
    this.map = const {},
    this.passAll = false,
    super.join,
    super.optional,
  });
}

/// S23: a form of the item that the composing item names for [slot].
final class SlotPart extends ComposePart {
  final String slot;
  @override
  final Map<String, String> set;
  @override
  final List<String> pass;
  @override
  final Map<String, Map<String, String>> map;
  @override
  bool get passAll => false;

  SlotPart({
    required this.slot,
    this.set = const {},
    this.pass = const [],
    this.map = const {},
    super.join,
    super.optional,
  });
}

/// A stem used as an affix.
final class StemPart extends ComposePart {
  final String stem;
  @override
  Map<String, String> get set => const {};
  @override
  List<String> get pass => const [];
  @override
  Map<String, Map<String, String>> get map => const {};
  @override
  bool get passAll => false;

  /// S18: false keeps the seam after the stem free of sandhi.
  final bool sandhi;

  StemPart(this.stem, {this.sandhi = true, super.join, super.optional});
}

/// S23: the item id a slot names for [item]: its own, else its type's.
String? slotFiller(GrammarType type, GrammarItem item, String slot) =>
    item.slots[slot] ?? type.slots[slot];

/// One composition rule (S13).
final class ComposeSpec {
  /// Feature axis id → the codes this rule makes keys for.
  final Map<String, List<String>> match;
  final String join;
  final List<ComposePart> parts;

  /// S24: the rule adds accepted variants to keys another rule makes.
  final bool variant;

  ComposeSpec({
    required this.match,
    required this.join,
    required this.parts,
    this.variant = false,
  });
}

/// S10: the tempora in which a word is deponent.
final class DeponentSpec {
  final bool all;
  final List<String> tempora;

  DeponentSpec.all() : all = true, tempora = const [];
  DeponentSpec.tempora(this.tempora) : all = false;

  bool contains(String tempus) => all || tempora.contains(tempus);
}

/// A declension or conjugation type, as written or after inheritance (S6).
final class GrammarType {
  final String name;
  final bool isAbstract;

  /// S19: the word class of a concrete type, null for an abstract one.
  final String? wordClass;

  /// S20: what the learner reads for a concrete type, null for an abstract one.
  final String? display;

  final String? inheritsFrom;
  final List<String> requiredStems;
  final Map<String, StemSpec> stems;

  /// Feature key → templates; the first is shown, all are accepted (S9).
  final Map<FormKey, List<FormTemplate>> forms;

  final List<DelegateSpec> delegates;
  final List<ComposeSpec> composes;

  /// S23: slot name → the item id a slot part reads unless the item names one.
  final Map<String, String> slots;

  /// Sandhi rule ids of the file's library, in application order (S16).
  final List<String> sandhi;

  final DeponentSpec? deponent;

  GrammarType({
    required this.name,
    this.isAbstract = false,
    this.wordClass,
    this.display,
    this.inheritsFrom,
    this.requiredStems = const [],
    this.stems = const {},
    this.forms = const {},
    this.delegates = const [],
    this.composes = const [],
    this.slots = const {},
    this.sandhi = const [],
    this.deponent,
  });

  bool get isLeaf => delegates.isEmpty && composes.isEmpty;

  /// S6: parent first, child wins per stem name, per key and per delegate name;
  /// compose lists append; a child's sandhi list replaces the parent's; the
  /// child wins per slot name.
  GrammarType inheriting(GrammarType parent) => GrammarType(
    name: name,
    isAbstract: isAbstract,
    wordClass: wordClass,
    display: display,
    inheritsFrom: inheritsFrom,
    requiredStems: {...parent.requiredStems, ...requiredStems}.toList(),
    stems: {...parent.stems, ...stems},
    forms: {...parent.forms, ...forms},
    delegates: [
      for (final d in parent.delegates)
        delegates.firstWhere((own) => own.name == d.name, orElse: () => d),
      ...delegates.where(
        (own) => !parent.delegates.any((d) => d.name == own.name),
      ),
    ],
    composes: [...parent.composes, ...composes],
    slots: {...parent.slots, ...slots},
    sandhi: sandhi.isNotEmpty ? sandhi : parent.sandhi,
    deponent: deponent ?? parent.deponent,
  );
}

/// One vocabulary item (lexeme).
final class GrammarItem {
  final String id;
  final String translation;

  /// Part name → spellings; the first is shown and traced (S9).
  final Map<String, List<String>> parts;

  /// Explicit overrides by feature key (S9: several accepted spellings).
  final Map<FormKey, List<String>> forms;

  final DeponentSpec? deponent;

  /// The id of the item in german_verbs.yaml that translates this verb.
  final String? deVerb;

  /// S23: slot name → item id of the same file.
  final Map<String, String> slots;

  /// S15: feature patterns whose keys this item does not have.
  final List<Map<String, String>> absent;

  /// The type given in the data, null when inference decides.
  final String? declaredType;

  /// The resolved type name and the inference rule that matched, if any (S11).
  final String typeName;
  final InferenceRule? typeRule;

  /// The lesson key: the first spelling of the file's lemma part.
  final String lemma;

  /// S25: `passiv: unpersönlich`.
  final bool impersonalPassive;

  GrammarItem({
    required this.id,
    required this.translation,
    required this.parts,
    required this.forms,
    required this.absent,
    required this.typeName,
    required this.lemma,
    this.deponent,
    this.deVerb,
    this.slots = const {},
    this.declaredType,
    this.typeRule,
    this.impersonalPassive = false,
  });

  /// The first spelling of [part], or null.
  String? part(String name) => parts[name]?.first;

  /// S8, S25: whether the keys of [delegate] are practised.
  bool emits(DelegateSpec delegate) =>
      delegate.emit &&
      !(impersonalPassive && delegate.set['genus_verbi'] == 'pass');

  /// S25: the key a `self` part looks up, given the [genusVerbi] of the
  /// composed key.
  Map<String, String> selfLookup(
    Map<String, String> wanted,
    String? genusVerbi,
  ) => impersonalPassive && genusVerbi == 'pass' && wanted.containsKey('genus')
      ? {...wanted, 'genus': 'n'}
      : wanted;
}

/// The keys one item has, after S4, S10, S13 and S15.
final class ItemKeys {
  /// Practised keys.
  final Set<FormKey> emitted;

  /// `emit: false` delegate keys: for compositions and the oracle (S8).
  final Set<FormKey> internal;

  /// Keys moved from a passive key by S10.
  final Set<FormKey> deponent;

  /// Stems the item can build (S4).
  final Set<String> stems;

  ItemKeys({
    required this.emitted,
    required this.internal,
    required this.deponent,
    required this.stems,
  });

  bool has(FormKey key) => emitted.contains(key) || internal.contains(key);
}

/// One parsed data file.
final class GrammarFile {
  final String path;

  /// The language of every text of this parse (S20).
  final String language;
  final String dataFileId;
  final Axes axes;
  final Map<String, PartSpec> parts;
  final String? givenPart;
  final String? lemmaPart;

  /// Rules in part declaration order, then list order (S11).
  final List<InferenceRule> typeInference;

  final Map<String, SandhiRuleSpec> sandhi;

  /// S19: the word classes the types of this file may name.
  final Set<String> classes;

  /// Types as written, before inheritance.
  final Map<String, GrammarType> declaredTypes;

  /// Filled right after parsing; the linker replaces them by typed ones (S11).
  final List<GrammarItem> items = [];

  /// Types after S6.
  late final Map<String, GrammarType> types;

  /// Item id → its keys.
  late final Map<String, ItemKeys> keysByItem;

  GrammarFile({
    required this.path,
    required this.language,
    required this.dataFileId,
    required this.axes,
    required this.parts,
    required this.typeInference,
    required this.sandhi,
    required this.classes,
    required this.declaredTypes,
    this.givenPart,
    this.lemmaPart,
  });

  GrammarItem item(String id) => items.firstWhere(
    (i) => i.id == id,
    orElse: () => throw ArgumentError('$path has no item "$id"'),
  );

  GrammarType type(String name) {
    final type = types[name];
    if (type == null) throw ArgumentError('$path has no type "$name"');
    return type;
  }
}

// ---------------------------------------------------------------- parsing

/// The `axes:` and `label:` blocks of one data file, with their S1 and S17
/// checks. The v1 loader needs these without the rest of the schema.
Axes parseAxes(
  YamlMap root, {
  required String path,
  String language = courseLanguage,
}) => _FileParser(path, root, language)._axes();

/// Parses one data file. Use [parseGrammarFiles] when types cross file
/// borders (S12).
GrammarFile parseGrammarFile(
  String source, {
  required String path,
  String language = courseLanguage,
}) => parseGrammarFiles({path: source}, language: language).single;

/// Parses all data files together and runs the cross-file checks (S12). The
/// texts come in [language]; S20 checks every language on every parse.
List<GrammarFile> parseGrammarFiles(
  Map<String, String> sourceByPath, {
  String language = courseLanguage,
}) {
  assert(dataLanguages.contains(language), 'no data language "$language"');
  final files = <GrammarFile>[];
  for (final entry in sourceByPath.entries) {
    final documents = loadYamlDocuments(entry.value);
    if (documents.length != 1) {
      _fail(
        'file',
        entry.key,
        'a data file is one YAML document, this source holds '
            '${documents.length}',
      );
    }
    files.add(
      _FileParser(
        entry.key,
        documents.single.contents as YamlMap,
        language,
      ).parse(),
    );
  }
  _Linker(files).link();
  return files;
}

Never _fail(
  String rule,
  String path,
  String message, {
  String? item,
  FormKey? key,
}) => throw SchemaError(rule, path, message, item: item, key: key);

/// Reads the structure of one YAML document. Checks everything that needs only
/// this document's text; [_Linker] does the rest.
class _FileParser {
  final String path;
  final YamlMap root;
  final String language;

  _FileParser(this.path, this.root, this.language);

  Never _bad(String rule, String message, {String? item, FormKey? key}) =>
      _fail(rule, path, message, item: item, key: key);

  /// S20: a map from each data language to a non-empty text.
  Map<String, String> _texts(Object? node, String where) {
    if (node is! YamlMap ||
        node.length != dataLanguages.length ||
        !dataLanguages.every(node.containsKey)) {
      _bad('S20', '$where: give a map of the languages $dataLanguages');
    }
    return {
      for (final code in dataLanguages)
        code: switch (node[code]) {
          final String text when text.trim().isNotEmpty => text,
          _ => _bad('S20', '$where: the "$code" text is missing or empty'),
        },
    };
  }

  String _text(Object? node, String where) => _texts(node, where)[language]!;

  /// Every top-level key a data file may carry. `shared:` holds YAML anchors
  /// items alias; nothing reads it.
  static const _topLevelKeys = {
    'data_file_id',
    'axes',
    'label',
    'parts',
    'defaults',
    'type_inference',
    'sandhi',
    'classes',
    'types',
    'items',
    'shared',
  };

  GrammarFile parse() {
    for (final key in root.keys) {
      if (!_topLevelKeys.contains(key)) {
        _bad('file', 'unknown top-level key "$key"');
      }
    }
    final axes = _axes();
    final parts = _parts();
    final defaults = root['defaults'] as YamlMap?;
    final classes = _classes();
    final file = GrammarFile(
      path: path,
      language: language,
      dataFileId: root['data_file_id'] as String,
      axes: axes,
      parts: parts,
      givenPart: defaults?['given_part'] as String?,
      lemmaPart: defaults?['lemma_part'] as String?,
      typeInference: _typeInference(parts),
      sandhi: _sandhi(),
      classes: classes,
      declaredTypes: _types(axes, classes),
    );
    file.items.addAll(_items(file));
    return file;
  }

  Axes _axes() {
    final axesNode = root['axes'] as YamlMap;
    final axes = <GrammarAxis>[];
    final codeOwner = <String, String>{};
    for (final entry in axesNode.entries) {
      final id = entry.key as String;
      final spec = entry.value as YamlMap;
      final values = <(String, String)>[];
      for (final value in (spec['values'] as YamlMap).entries) {
        final code = '${value.key}';
        final owner = codeOwner[code];
        if (owner != null) {
          _bad('S1', 'code "$code" is declared by axis $owner and axis $id');
        }
        codeOwner[code] = id;
        values.add((code, _text(value.value, 'axis $id code $code')));
      }
      final hidden = (spec['hidden_in_label'] as YamlList?) ?? const [];
      for (final code in hidden) {
        if (!values.any((v) => v.$1 == '$code')) {
          _bad('S1', 'axis $id hides the unknown code "$code"');
        }
      }
      axes.add(
        GrammarAxis(
          id: id,
          name: _text(spec['name'], 'axis $id name'),
          values: values,
          hiddenInLabel: {for (final code in hidden) '$code'},
        ),
      );
    }

    final label = root['label'] as YamlMap;
    final head = [for (final a in label['head'] as YamlList) '$a'];
    final tail = [for (final a in label['tail'] as YamlList) '$a'];
    final ids = axes.map((a) => a.id).toSet();
    for (final id in [...head, ...tail]) {
      if (!ids.contains(id)) _bad('S17', 'label names the unknown axis "$id"');
    }
    if ({...head, ...tail}.length != ids.length ||
        head.length + tail.length != ids.length) {
      _bad('S17', 'label head and tail must list every axis exactly once');
    }
    final mergeAxis = label['merge_axis'] as String;
    if (!ids.contains(mergeAxis)) {
      _bad('S17', 'merge_axis names the unknown axis "$mergeAxis"');
    }

    final overrides = <LabelOverride>[];
    for (final node in (label['overrides'] as YamlList?) ?? const []) {
      final spec = node as YamlMap;
      final axisId = spec['axis'] as String;
      final axis = axes.where((a) => a.id == axisId).firstOrNull;
      if (axis == null) {
        _bad('S17', 'override names the unknown axis "$axisId"');
      }
      final when = <String, Set<String>>{};
      for (final entry in (spec['when'] as YamlMap).entries) {
        final whenAxis = axes.where((a) => a.id == '${entry.key}').firstOrNull;
        if (whenAxis == null) {
          _bad('S17', 'override "when" names the unknown axis "${entry.key}"');
        }
        final codes = {for (final code in _asList(entry.value)) '$code'};
        for (final code in codes) {
          if (whenAxis.indexOf(code) < 0) {
            _bad(
              'S17',
              'override "when" names the unknown code "$code" '
                  'of axis ${whenAxis.id}',
            );
          }
        }
        when['${entry.key}'] = codes;
      }
      final values = <String, String>{};
      for (final entry in (spec['values'] as YamlMap).entries) {
        final code = '${entry.key}';
        if (axis.indexOf(code) < 0) {
          _bad('S17', 'override names the unknown code "$code" of $axisId');
        }
        values[code] = _text(entry.value, 'override of $axisId code $code');
      }
      overrides.add(LabelOverride(when: when, axis: axisId, values: values));
    }

    return Axes(
      axes: axes,
      head: head,
      tail: tail,
      mergeAxis: mergeAxis,
      labelOverrides: overrides,
    );
  }

  Map<String, PartSpec> _parts() {
    final node = (root['parts'] as YamlMap?) ?? YamlMap();
    return {
      for (final entry in node.entries)
        '${entry.key}': PartSpec(
          name: '${entry.key}',
          label: _text((entry.value as YamlMap)['label'], 'part ${entry.key}'),
          display: (entry.value as YamlMap)['display'] as bool? ?? true,
        ),
    };
  }

  List<InferenceRule> _typeInference(Map<String, PartSpec> parts) {
    final node = (root['type_inference'] as YamlMap?) ?? YamlMap();
    final rules = <InferenceRule>[];
    for (final entry in node.entries) {
      final part = '${entry.key}';
      if (!parts.containsKey(part)) {
        _bad('S11', 'type_inference names the unknown part "$part"');
      }
      for (final ruleNode in entry.value as YamlList) {
        final spec = ruleNode as YamlMap;
        final types = [for (final t in spec['types'] as YamlList) '$t'];
        if (types.isEmpty) {
          _bad('S11', 'type_inference rule on $part has no types');
        }
        rules.add(
          InferenceRule(
            part: part,
            suffix: '${spec['suffix']}',
            minLength: spec['min_length'] as int?,
            types: types,
          ),
        );
      }
    }
    return rules;
  }

  Map<String, SandhiRuleSpec> _sandhi() {
    final node = (root['sandhi'] as YamlMap?) ?? YamlMap();
    final rules = <String, SandhiRuleSpec>{};
    for (final entry in node.entries) {
      final id = '${entry.key}';
      final spec = entry.value as YamlMap;

      final end = '${spec['end']}';
      if (end != 'vowel' && end != 'consonant' && !_letters.hasMatch(end)) {
        _bad('S16', 'rule $id: "end" must be letters, vowel or consonant');
      }

      String? beforeClass;
      List<String>? beforeStarts;
      final before = spec['before'];
      if (before is String && (before == 'vowel' || before == 'consonant')) {
        beforeClass = before;
      } else if (before is YamlList) {
        if (before.isEmpty) _bad('S16', 'rule $id: "before" list is empty');
        beforeStarts = [for (final b in before) '$b'];
        for (final start in beforeStarts) {
          final letters = start.endsWith(r'$')
              ? start.substring(0, start.length - 1)
              : start;
          if (letters.isNotEmpty && !_letters.hasMatch(letters)) {
            _bad('S16', 'rule $id: "before" entry "$start" is not letters');
          }
          if (letters.isEmpty && start != r'$') {
            _bad('S16', 'rule $id: "before" has an empty entry');
          }
        }
      } else {
        _bad(
          'S16',
          'rule $id: "before" must be vowel, consonant or a list of letters',
        );
      }

      final replaceNode = spec['replace'];
      if (replaceNode == null) _bad('S16', 'rule $id has no "replace"');
      final replaceText = '$replaceNode';
      final replace = switch (replaceText) {
        'short' => SandhiReplace.short,
        'double_next' => SandhiReplace.doubleNext,
        _ => SandhiReplace.literal,
      };
      if (replace == SandhiReplace.literal &&
          replaceText.isNotEmpty &&
          !_letters.hasMatch(replaceText)) {
        _bad(
          'S16',
          'rule $id: "replace" must be letters, short or double_next',
        );
      }

      final explain = _text(spec['explain'], 'sandhi rule $id explain');

      rules[id] = SandhiRuleSpec(
        id: id,
        end: end,
        beforeClass: beforeClass,
        beforeStarts: beforeStarts,
        replace: replace,
        replaceText: replace == SandhiReplace.literal ? replaceText : '',
        explain: explain,
        variant: spec['variant'] as bool? ?? false,
      );
    }
    return rules;
  }

  Set<String> _classes() {
    final names = <String>{};
    for (final node in (root['classes'] as YamlList?) ?? const []) {
      if (!names.add('$node')) {
        _bad('S19', 'class "$node" is declared twice');
      }
    }
    return names;
  }

  Map<String, GrammarType> _types(Axes axes, Set<String> classes) {
    final node = (root['types'] as YamlMap?) ?? YamlMap();
    final types = <String, GrammarType>{};
    final typeOfDisplay = <(String, String), String>{};
    for (final entry in node.entries) {
      final name = '${entry.key}';
      final spec = (entry.value as YamlMap?) ?? YamlMap();
      final isAbstract = spec['abstract'] as bool? ?? false;
      final wordClass = _wordClass(
        name,
        spec['class'] as String?,
        isAbstract,
        classes,
      );
      final displays = _typeDisplays(name, spec['display'], isAbstract);
      for (final display in displays.entries) {
        final other = typeOfDisplay[(display.key, display.value)];
        if (other != null) {
          _bad(
            'S20',
            'types $other and $name share the ${display.key} display '
                '"${display.value}"',
          );
        }
        typeOfDisplay[(display.key, display.value)] = name;
      }
      types[name] = GrammarType(
        name: name,
        isAbstract: isAbstract,
        wordClass: wordClass,
        display: displays[language],
        inheritsFrom: spec['inherits_from'] as String?,
        requiredStems: [
          for (final s in (spec['required_stems'] as YamlList?) ?? const [])
            '$s',
        ],
        stems: _stems(name, spec['stems'] as YamlMap?),
        forms: _forms(name, spec['forms'] as YamlMap?, axes),
        delegates: _delegates(name, spec['delegate'] as YamlList?),
        composes: _composes(name, spec['compose'] as YamlList?, axes),
        slots: _slots(spec['slots'], 'type $name'),
        sandhi: [
          for (final id in (spec['sandhi'] as YamlList?) ?? const []) '$id',
        ],
        deponent: _deponent(spec['deponent'], 'type $name'),
      );
    }
    return types;
  }

  /// S20: a concrete type has a display per language, an abstract one none.
  Map<String, String> _typeDisplays(
    String type,
    Object? node,
    bool isAbstract,
  ) {
    if (!isAbstract) return _texts(node, 'type $type display');
    if (node != null) {
      _bad('S20', 'type $type is abstract, so it takes no "display"');
    }
    return const {};
  }

  /// S19: a concrete type names one of the file's classes, an abstract one
  /// names none.
  String? _wordClass(
    String type,
    String? given,
    bool isAbstract,
    Set<String> classes,
  ) {
    if (isAbstract) {
      if (given != null) {
        _bad('S19', 'type $type is abstract, so it takes no "class"');
      }
      return null;
    }
    if (given == null) _bad('S19', 'type $type has no "class"');
    if (!classes.contains(given)) {
      _bad('S19', 'type $type names the unknown class "$given"');
    }
    return given;
  }

  Map<String, StemSpec> _stems(String type, YamlMap? node) {
    final stems = <String, StemSpec>{};
    for (final entry in (node ?? YamlMap()).entries) {
      final name = '${entry.key}';
      final spec = entry.value as YamlMap;
      final from = spec['from'] as String?;
      final template = spec['template'] as String?;
      if ((from == null) == (template == null)) {
        _bad('S2', 'type $type stem $name needs either "from" or "template"');
      }
      stems[name] = StemSpec(
        name: name,
        from: from,
        remove: spec.containsKey('remove')
            ? [for (final s in _asList(spec['remove'])) '$s']
            : const [],
        defaultTemplate: spec['default'] == null
            ? null
            : _template('${spec['default']}', 'type $type stem $name'),
        template: template == null
            ? null
            : _template(template, 'type $type stem $name'),
        display: spec['display'] == null
            ? null
            : _text(spec['display'], 'type $type stem $name display'),
      );
    }
    return stems;
  }

  /// S2: one placeholder, at the start, or a literal only.
  FormTemplate _template(String text, String where) {
    final open = text.indexOf('{');
    if (open < 0) {
      if (text.contains('}')) _bad('S2', '$where: template "$text" has a "}"');
      return FormTemplate(ending: text);
    }
    if (open != 0) {
      _bad('S2', '$where: template "$text" has text before the placeholder');
    }
    final close = text.indexOf('}');
    if (close < 0) _bad('S2', '$where: template "$text" is not closed');
    final stem = text.substring(1, close);
    final ending = text.substring(close + 1);
    if (stem.isEmpty) _bad('S2', '$where: template "$text" names no stem');
    if (ending.contains('{') || ending.contains('}')) {
      _bad('S2', '$where: template "$text" has more than one placeholder');
    }
    return FormTemplate(stemName: stem, ending: ending);
  }

  Map<FormKey, List<FormTemplate>> _forms(
    String type,
    YamlMap? node,
    Axes axes,
  ) {
    final forms = <FormKey, List<FormTemplate>>{};
    for (final entry in (node ?? YamlMap()).entries) {
      final key = '${entry.key}';
      _checkKey(key, axes, 'type $type');
      final texts = [for (final t in _asList(entry.value)) '$t'];
      _checkVariants(texts, 'type $type', key);
      forms[key] = [
        for (final text in texts) _template(text, 'type $type key $key'),
      ];
    }
    return forms;
  }

  void _checkKey(FormKey key, Axes axes, String where) {
    try {
      axes.parseKey(key);
    } on ArgumentError catch (error) {
      _bad('S1', '$where: ${error.message}', key: key);
    }
  }

  /// S9: a variant list holds at least two spellings, none norm-equal.
  void _checkVariants(List<String> values, String where, [FormKey? key]) {
    if (values.length == 1) return;
    if (values.isEmpty) _bad('S9', '$where: empty value list', key: key);
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(_norm(value))) {
        _bad(
          'S9',
          '$where: "$value" differs from another spelling only in quantity '
              'marks',
          key: key,
        );
      }
    }
  }

  List<DelegateSpec> _delegates(String type, YamlList? node) {
    final delegates = <DelegateSpec>[];
    for (final entry in node ?? const []) {
      final spec = entry as YamlMap;
      final name = spec['name'] as String?;
      if (name == null || name.isEmpty) {
        _bad('S14', 'type $type has a delegate without "name"');
      }
      delegates.add(
        DelegateSpec(
          name: name,
          type: spec['type'] as String,
          bind: {
            for (final b in ((spec['bind'] as YamlMap?) ?? YamlMap()).entries)
              '${b.key}': '${b.value}',
          },
          set: {
            for (final s in ((spec['set'] as YamlMap?) ?? YamlMap()).entries)
              '${s.key}': '${s.value}',
          },
          emit: spec['emit'] as bool? ?? true,
        ),
      );
    }
    return delegates;
  }

  List<ComposeSpec> _composes(String type, YamlList? node, Axes axes) {
    final composes = <ComposeSpec>[];
    for (final entry in node ?? const []) {
      final spec = entry as YamlMap;
      for (final key in spec.keys) {
        if (!_composeKeys.contains(key)) {
          _bad('S13', 'type $type: a compose rule has no key "$key"');
        }
      }
      final match = <String, List<String>>{};
      for (final m in ((spec['match'] as YamlMap?) ?? YamlMap()).entries) {
        final axisId = '${m.key}';
        final codes = [for (final c in _asList(m.value)) '$c'];
        final axis = axes.axes.where((a) => a.id == axisId).firstOrNull;
        if (axis == null) {
          _bad('S13', 'type $type: compose match names no axis "$axisId"');
        }
        for (final code in codes) {
          if (axis.indexOf(code) < 0) {
            _bad(
              'S13',
              'type $type: compose match code "$code" is no $axisId value',
            );
          }
        }
        match[axisId] = codes;
      }
      final parts = [
        for (final part in spec['parts'] as YamlList)
          _composePart(type, part as YamlMap, axes),
      ];
      if (parts.last.join != null) {
        _bad('S21', 'type $type: the last compose part takes no "join"');
      }
      if (parts.every((part) => part.optional)) {
        _bad(
          'S22',
          'type $type: a compose rule needs a part that is not optional',
        );
      }
      composes.add(
        ComposeSpec(
          match: match,
          join: '${spec['join'] ?? ''}',
          parts: parts,
          variant: spec['variant'] as bool? ?? false,
        ),
      );
    }
    return composes;
  }

  static const _composeKeys = {'match', 'join', 'parts', 'variant'};
  static const _partKeys = {
    'self',
    'lexeme',
    'slot',
    'stem',
    'set',
    'pass',
    'map',
    'join',
    'optional',
    'sandhi',
  };

  /// S23: slot name → item id.
  Map<String, String> _slots(Object? node, String where) => {
    for (final entry in ((node as YamlMap?) ?? YamlMap()).entries)
      '${entry.key}': '${entry.value}',
  };

  ComposePart _composePart(String type, YamlMap spec, Axes axes) {
    for (final key in spec.keys) {
      if (!_partKeys.contains(key)) {
        _bad('S13', 'type $type: a compose part has no key "$key"');
      }
    }
    final join = spec['join'] as String?;
    final optional = spec['optional'] as bool? ?? false;
    final set = {
      for (final s in ((spec['set'] as YamlMap?) ?? YamlMap()).entries)
        '${s.key}': '${s.value}',
    };
    for (final entry in set.entries) {
      final axis = axes.axes.where((a) => a.id == entry.key).firstOrNull;
      if (axis == null || axis.indexOf(entry.value) < 0) {
        _bad(
          'S13',
          'type $type: compose part sets "${entry.key}: ${entry.value}", '
              'which is no axis value',
        );
      }
    }

    final passNode = spec['pass'];
    final passAll = passNode is String && passNode == 'all';
    final pass = passAll
        ? const <String>[]
        : [for (final p in passNode ?? const []) '$p'];
    final map = <String, Map<String, String>>{
      for (final m in ((spec['map'] as YamlMap?) ?? YamlMap()).entries)
        '${m.key}': {
          for (final v in (m.value as YamlMap).entries)
            '${v.key}': '${v.value}',
        },
    };
    for (final axisId in [...pass, ...map.keys]) {
      if (!axes.axes.any((a) => a.id == axisId)) {
        _bad('S13', 'type $type: compose part passes no axis "$axisId"');
      }
    }
    if (passAll && map.isNotEmpty) {
      _bad('S13', 'type $type: "map" is not allowed with "pass: all"');
    }

    if (spec.containsKey('stem')) {
      if (set.isNotEmpty || pass.isNotEmpty || map.isNotEmpty || passAll) {
        _bad('S13', 'type $type: a "stem" part takes no set, pass or map');
      }
      final sandhi = spec['sandhi'] ?? true;
      if (sandhi is! bool) {
        _bad('S13', 'type $type: "sandhi" is true or false, not "$sandhi"');
      }
      return StemPart(
        '${spec['stem']}',
        sandhi: sandhi,
        join: join,
        optional: optional,
      );
    }
    if (spec.containsKey('sandhi')) {
      _bad('S13', 'type $type: only a "stem" part takes "sandhi"');
    }
    if (passAll && !spec.containsKey('lexeme')) {
      _bad('S13', 'type $type: "pass: all" is only allowed on a lexeme part');
    }
    if (spec.containsKey('self')) {
      return SelfPart(
        delegate: '${spec['self']}',
        set: set,
        pass: pass,
        map: map,
        join: join,
        optional: optional,
      );
    }
    if (spec.containsKey('slot')) {
      return SlotPart(
        slot: '${spec['slot']}',
        set: set,
        pass: pass,
        map: map,
        join: join,
        optional: optional,
      );
    }
    if (spec.containsKey('lexeme')) {
      return LexemePart(
        lexeme: '${spec['lexeme']}',
        set: set,
        pass: pass,
        map: map,
        passAll: passAll,
        join: join,
        optional: optional,
      );
    }
    _bad('S13', 'type $type: a compose part needs self, lexeme, slot or stem');
  }

  DeponentSpec? _deponent(Object? node, String where) {
    if (node == null) return null;
    if (node is String && node == 'all') return DeponentSpec.all();
    if (node is YamlList) {
      return DeponentSpec.tempora([for (final t in node) '$t']);
    }
    _bad('S10', '$where: "deponent" must be all or a list of tempus codes');
  }

  /// Items need the file's axes and parts, so they are read last; their type
  /// and keys are settled by [_Linker].
  List<GrammarItem> _items(GrammarFile file) {
    final node = (root['items'] as YamlList?) ?? YamlList();
    final items = <GrammarItem>[];
    final ids = <String>{};
    for (final entry in node) {
      final spec = entry as YamlMap;
      final parts = <String, List<String>>{};
      for (final p in ((spec['parts'] as YamlMap?) ?? YamlMap()).entries) {
        final name = '${p.key}';
        if (!file.parts.containsKey(name)) {
          _bad('S3', 'item gives the unknown part "$name"');
        }
        final spellings = [for (final s in _asList(p.value)) '$s'];
        _checkVariants(spellings, 'part $name');
        parts[name] = spellings;
      }

      final lemmaPart = file.lemmaPart ?? file.givenPart;
      final lemma = parts[lemmaPart]?.first;
      if (lemma == null) {
        _bad('S3', 'item ${spec['parts']} lacks the lemma part "$lemmaPart"');
      }
      final id = spec['id'] as String? ?? _norm(lemma);
      if (!ids.add(id)) _bad('S5', 'two items share the id "$id"', item: id);

      final forms = <FormKey, List<String>>{};
      for (final f in ((spec['forms'] as YamlMap?) ?? YamlMap()).entries) {
        final key = '${f.key}';
        _checkKey(key, file.axes, 'item $id');
        final spellings = [for (final s in _asList(f.value)) '$s'];
        _checkVariants(spellings, 'item $id', key);
        forms[key] = spellings;
      }

      final impersonal = switch (spec['passiv']) {
        null => false,
        'unpersönlich' => true,
        final other => _bad(
          'S25',
          '"passiv: $other" is not "unpersönlich"',
          item: id,
        ),
      };
      if (impersonal && spec['deponent'] != null) {
        _bad('S25', 'a deponent has no impersonal passive', item: id);
      }
      final absent = <Map<String, String>>[];
      for (final pattern in [
        ...(spec['absent'] as YamlList?) ?? const [],
        if (impersonal) ..._personalPassive,
      ]) {
        final features = <String, String>{};
        for (final a in (pattern as Map).entries) {
          final axis = file.axes.axes
              .where((x) => x.id == '${a.key}')
              .firstOrNull;
          if (axis == null || axis.indexOf('${a.value}') < 0) {
            _bad(
              'S15',
              'absent pattern "${a.key}: ${a.value}" is no axis value',
              item: id,
            );
          }
          features['${a.key}'] = '${a.value}';
        }
        if (features.isEmpty) {
          _bad('S15', 'an absent pattern is empty', item: id);
        }
        absent.add(features);
      }

      items.add(
        GrammarItem(
          id: id,
          translation: _text(spec['translation'], 'item $id translation'),
          parts: parts,
          forms: forms,
          absent: absent,
          declaredType: spec['type'] as String?,
          typeName: '', // settled by _Linker
          lemma: lemma,
          deponent: _deponent(spec['deponent'], 'item $id'),
          deVerb: spec['de_verb'] as String?,
          slots: _slots(spec['slots'], 'item $id'),
          impersonalPassive: impersonal,
        ),
      );
    }
    return items;
  }
}

/// S25: the passive keys with a person as subject.
const _personalPassive = [
  {'genus_verbi': 'pass', 'person': '1'},
  {'genus_verbi': 'pass', 'person': '2'},
  {'genus_verbi': 'pass', 'person': '3', 'numerus': 'pl'},
];

Iterable<Object?> _asList(Object? node) => node is YamlList ? node : [node];

// ---------------------------------------------------------------- linking

/// Resolves inheritance, item types and key sets across all files, and checks
/// the rules that need more than one declaration.
class _Linker {
  final List<GrammarFile> files;
  final Map<String, GrammarFile> _fileOfType = {};
  final Map<String, GrammarType> _typeByName = {};

  _Linker(this.files);

  void link() {
    _registerTypes();
    for (final file in files) {
      file.types = {
        for (final name in file.declaredTypes.keys) name: _resolve(file, name),
      };
      for (final type in file.types.values) {
        _checkSandhiList(file, type);
        _checkDelegates(file, type);
      }
    }
    for (final file in files) {
      final typed = [for (final item in file.items) _withType(file, item)];
      file.items
        ..clear()
        ..addAll(typed);
    }
    for (final file in files) {
      _checkItems(file);
    }
  }

  /// S12: type names are unique across all data files.
  void _registerTypes() {
    for (final file in files) {
      for (final name in file.declaredTypes.keys) {
        final other = _fileOfType[name];
        if (other != null) {
          _fail(
            'S12',
            file.path,
            'type "$name" is also declared in ${other.path}',
          );
        }
        _fileOfType[name] = file;
      }
    }
  }

  GrammarFile _fileOf(String typeName, String path) {
    final file = _fileOfType[typeName];
    if (file == null) _fail('S6', path, 'no type "$typeName"');
    return file;
  }

  /// S6 with a cycle guard (S5).
  GrammarType _resolve(GrammarFile file, String name, [List<String>? seen]) {
    final cached = _typeByName[name];
    if (cached != null) return cached;
    final chain = [...?seen, name];
    final declared = file.declaredTypes[name]!;
    final parentName = declared.inheritsFrom;
    var resolved = declared;
    if (parentName != null) {
      if (chain.contains(parentName)) {
        _fail(
          'S5',
          file.path,
          'inheritance cycle ${chain.join(" → ")} → $parentName',
        );
      }
      final parentFile = _fileOf(parentName, file.path);
      resolved = declared.inheriting(_resolve(parentFile, parentName, chain));
    }
    _typeByName[name] = resolved;
    return resolved;
  }

  /// S16: a type's sandhi list names rules of its own file's library.
  void _checkSandhiList(GrammarFile file, GrammarType type) {
    for (final id in type.sandhi) {
      if (!file.sandhi.containsKey(id)) {
        _fail('S16', file.path, 'type ${type.name} names no sandhi rule "$id"');
      }
    }
  }

  /// S14 and the delegated part of S12.
  void _checkDelegates(GrammarFile file, GrammarType type) {
    for (final delegate in type.delegates) {
      final targetFile = _fileOf(delegate.type, file.path);
      final target = _resolve(targetFile, delegate.type);
      if (!target.isLeaf) {
        _fail(
          'S14',
          file.path,
          'type ${type.name} delegates to ${target.name}, which is not a leaf '
              '(it has delegate or compose)',
        );
      }
      for (final entry in target.forms.entries) {
        for (final template in entry.value) {
          final stem = template.stemName;
          if (stem != null && !delegate.bind.containsKey(stem)) {
            _fail(
              'S14',
              file.path,
              'delegate ${delegate.name} does not bind the stem "$stem" that '
                  '${target.name} uses',
              key: entry.key,
            );
          }
        }
      }
      for (final key in target.forms.keys) {
        final codes = key.split('.');
        for (final code in codes) {
          // S12: the delegating file writes the key again, so it must know
          // every code of it and put it on the same axis.
          final here = file.axes.axisOfCode(code);
          final there = targetFile.axes.axisOfCode(code)!;
          if (here == null) {
            _fail(
              'S12',
              file.path,
              'delegate ${delegate.name}: ${target.name}\'s code "$code" is '
                  'unknown in ${file.dataFileId}',
              key: key,
            );
          }
          if (here.id != there.id) {
            _fail(
              'S12',
              file.path,
              'delegate ${delegate.name}: code "$code" is axis ${here.id} in '
                  '${file.dataFileId} but ${there.id} in '
                  '${targetFile.dataFileId}',
              key: key,
            );
          }
        }
        for (final axisId in delegate.set.keys) {
          if (codes.any((c) => file.axes.axisOfCode(c)!.id == axisId)) {
            _fail(
              'S14',
              file.path,
              'delegate ${delegate.name} sets $axisId, which occurs in '
                  '${target.name}\'s keys',
              key: key,
            );
          }
        }
      }
    }
  }

  /// S11: the type an item uses, from `type` or from the inference rules.
  GrammarItem _withType(GrammarFile file, GrammarItem item) {
    InferenceRule? matched;
    for (final rule in file.typeInference) {
      final spelling = item.part(rule.part);
      if (spelling == null) continue;
      if (rule.matches(spelling)) {
        matched = rule;
        break;
      }
    }
    final declared = item.declaredType;
    if (matched != null && matched.isAmbiguous && declared == null) {
      _fail(
        'S11',
        file.path,
        'rule "$matched" is ambiguous, so the item must give "type"',
        item: item.id,
      );
    }
    if (declared == null && matched == null) {
      _fail(
        'S11',
        file.path,
        'no type_inference rule matches and the item gives no "type"',
        item: item.id,
      );
    }
    final name = declared ?? matched!.types.single;
    if (!_typeByName.containsKey(name)) {
      _fail(
        'S6',
        file.path,
        'item uses the unknown type "$name"',
        item: item.id,
      );
    }
    // S12: the item's keys are written in its own file's axes, so only
    // `delegate` reaches across files.
    if (!file.declaredTypes.containsKey(name)) {
      _fail(
        'S12',
        file.path,
        'type "$name" is declared in ${_fileOfType[name]!.path}; an item uses '
            'a type of its own file',
        item: item.id,
      );
    }
    return GrammarItem(
      id: item.id,
      translation: item.translation,
      parts: item.parts,
      forms: item.forms,
      absent: item.absent,
      typeName: name,
      lemma: item.lemma,
      deponent: item.deponent,
      deVerb: item.deVerb,
      slots: item.slots,
      declaredType: declared,
      typeRule: matched,
      impersonalPassive: item.impersonalPassive,
    );
  }

  void _checkItems(GrammarFile file) {
    file.keysByItem = {};
    for (final item in file.items) {
      final type = file.type(item.typeName);
      _checkStems(file, item, type);
      _checkDeponent(file, item, type);
      _checkSlots(file, item, type);
      _checkLexemeAcyclic(file, item, [item.id]);
    }
    for (final item in file.items) {
      file.keysByItem[item.id] = _planKeys(file, item);
    }
  }

  /// S3 and S4.
  void _checkStems(GrammarFile file, GrammarItem item, GrammarType type) {
    for (final stem in type.stems.values) {
      final from = stem.from;
      if (from == null) continue;
      if (!file.parts.containsKey(from)) {
        _fail(
          'S3',
          file.path,
          'type ${type.name} stem ${stem.name} reads the unknown part "$from"',
          item: item.id,
        );
      }
      final spellings = item.parts[from];
      if (spellings == null) continue;
      if (stem.remove.isEmpty) continue;
      for (final spelling in spellings) {
        final matched = stem.remove.any(
          (suffix) => _norm(spelling).endsWith(_norm(suffix)),
        );
        if (!matched) {
          _fail(
            'S3',
            file.path,
            'stem ${stem.name}: no suffix of [${stem.remove.join(", ")}] '
                'matches "$spelling"',
            item: item.id,
          );
        }
      }
    }
    // S2: a type an item uses must declare every stem its templates name.
    // A delegate target names the target's stems instead; S14 checks those.
    for (final entry in type.forms.entries) {
      for (final template in entry.value) {
        final stem = template.stemName;
        if (stem != null && !type.stems.containsKey(stem)) {
          _fail(
            'S2',
            file.path,
            'type ${type.name} has no stem "$stem"',
            item: item.id,
            key: entry.key,
          );
        }
      }
    }
    for (final stem in type.stems.values) {
      final base = stem.fromStem?.stemName;
      if (base != null && !type.stems.containsKey(base)) {
        _fail(
          'S2',
          file.path,
          'type ${type.name} stem ${stem.name} builds on "$base", which the '
              'type does not declare',
          item: item.id,
        );
      }
    }

    final available = _availableStems(file, item, type);
    for (final name in type.requiredStems) {
      if (!type.stems.containsKey(name)) {
        _fail(
          'S4',
          file.path,
          'type ${type.name} requires the stem "$name", which it does not '
              'declare',
        );
      }
      if (!available.contains(name)) {
        _fail(
          'S4',
          file.path,
          'the required stem "$name" is missing',
          item: item.id,
        );
      }
    }
  }

  /// S4: a stem is available when it comes from a part the item gives, or from
  /// a template whose base is available.
  Set<String> _availableStems(
    GrammarFile file,
    GrammarItem item,
    GrammarType type,
  ) {
    final available = <String>{};
    bool resolve(String name, List<String> chain) {
      if (available.contains(name)) return true;
      final stem = type.stems[name];
      if (stem == null) return false;
      if (chain.contains(name)) {
        _fail(
          'S5',
          file.path,
          'stem cycle ${chain.join(" → ")} → $name',
          item: item.id,
        );
      }
      if (stem.from != null && item.parts.containsKey(stem.from)) {
        available.add(name);
        return true;
      }
      final template = stem.from == null ? stem.template : stem.defaultTemplate;
      if (template == null) return false;
      final base = template.stemName;
      if (base != null && !resolve(base, [...chain, name])) return false;
      available.add(name);
      return true;
    }

    for (final name in type.stems.keys) {
      resolve(name, const []);
    }
    return available;
  }

  /// S10: `deponent` is all or a list of tempus codes of the file.
  void _checkDeponent(GrammarFile file, GrammarItem item, GrammarType type) {
    final deponent = item.deponent ?? type.deponent;
    if (deponent == null) return;
    if (!file.axes.axes.any((a) => a.id == 'genus_verbi')) {
      _fail(
        'S10',
        file.path,
        '${file.dataFileId} has no genus_verbi axis',
        item: item.id,
      );
    }
    if (deponent.all) return;
    final tempus = file.axes.axes.where((a) => a.id == 'tempus').firstOrNull;
    if (tempus == null) {
      _fail(
        'S10',
        file.path,
        '${file.dataFileId} has no tempus axis',
        item: item.id,
      );
    }
    for (final code in deponent.tempora) {
      if (tempus.indexOf(code) < 0) {
        _fail('S10', file.path, '"$code" is no tempus code', item: item.id);
      }
    }
  }

  /// S23: an item names only slots that a part of its type reads.
  void _checkSlots(GrammarFile file, GrammarItem item, GrammarType type) {
    final read = {
      for (final compose in type.composes)
        for (final part in compose.parts)
          if (part is SlotPart) part.slot,
    };
    for (final slot in item.slots.keys) {
      if (!read.contains(slot)) {
        _fail(
          'S23',
          file.path,
          'no compose part of ${type.name} reads the slot "$slot"',
          item: item.id,
        );
      }
    }
  }

  /// S5: an item's forms must not depend on the item itself through `lexeme:`
  /// or `slot:`.
  void _checkLexemeAcyclic(
    GrammarFile file,
    GrammarItem item,
    List<String> chain,
  ) {
    final type = file.type(item.typeName);
    for (final compose in type.composes) {
      for (final part in compose.parts) {
        final lexeme = switch (part) {
          LexemePart(:final lexeme) => lexeme,
          SlotPart(:final slot) => slotFiller(type, item, slot),
          _ => null,
        };
        if (lexeme == null) continue;
        final target = file.items.where((i) => i.id == lexeme).firstOrNull;
        if (target == null) {
          _fail(
            'S5',
            file.path,
            'compose names the unknown lexeme "$lexeme"',
            item: item.id,
          );
        }
        if (chain.contains(target.id)) {
          _fail(
            'S5',
            file.path,
            'composition cycle ${chain.join(" → ")} → ${target.id}',
            item: item.id,
          );
        }
        _checkLexemeAcyclic(file, target, [...chain, target.id]);
      }
    }
  }

  /// The keys of one item: own and inherited templates with an available stem,
  /// delegated keys, composed keys, item overrides, minus `absent`, with the
  /// deponent move applied (S4, S10, S13, S14, S15).
  ItemKeys _planKeys(GrammarFile file, GrammarItem item) {
    final cached = file.keysByItem[item.id];
    if (cached != null) return cached;

    final type = file.type(item.typeName);
    final stems = _availableStems(file, item, type);
    final axes = file.axes;
    final emitted = <FormKey, String>{}; // key → source, for the collision rule
    final internal = <FormKey>{};

    void add(FormKey key, String source) {
      final other = emitted[key];
      if (other != null) {
        _fail(
          'collision',
          file.path,
          'key is produced by $other and by $source',
          item: item.id,
          key: key,
        );
      }
      emitted[key] = source;
    }

    for (final entry in type.forms.entries) {
      final stem = entry.value.first.stemName;
      if (stem != null && !stems.contains(stem)) continue;
      add(entry.key, 'the templates of ${type.name}');
    }

    for (final delegate in type.delegates) {
      final target = _typeByName[delegate.type]!;
      // S12: the target may live in another file, whose axis order differs, so
      // the key is read there and written again here.
      final targetAxes = _fileOfType[delegate.type]!.axes;
      for (final entry in target.forms.entries) {
        final targetStem = entry.value.first.stemName;
        if (targetStem != null && !stems.contains(delegate.bind[targetStem])) {
          continue;
        }
        final key = axes.formatKey({
          ...targetAxes.parseKey(entry.key),
          ...delegate.set,
        });
        if (item.emits(delegate)) {
          add(key, 'delegate ${delegate.name}');
        } else {
          internal.add(key);
        }
      }
    }

    final composed = <FormKey>{};
    for (final compose in type.composes.where((c) => !c.variant)) {
      for (final key in _composedKeys(file, item, compose, stems)) {
        add(key, 'a compose rule of ${type.name}');
        composed.add(key);
      }
    }
    for (final compose in type.composes.where((c) => c.variant)) {
      final orphan = _composedKeys(
        file,
        item,
        compose,
        stems,
      ).difference(composed);
      if (orphan.isNotEmpty) {
        _fail(
          'S24',
          file.path,
          'a variant rule of ${type.name} makes a key no other rule makes',
          item: item.id,
          key: orphan.first,
        );
      }
    }

    // S10 moves passive keys onto their active key before item overrides.
    final deponent = <FormKey>{};
    final deponentSpec = item.deponent ?? type.deponent;
    if (deponentSpec != null) {
      final moved = <FormKey, String>{};
      for (final entry in emitted.entries) {
        final features = axes.parseKey(entry.key);
        final genus = features['genus_verbi'];
        if (genus == 'pass') {
          if (!_deponentMoves(features, deponentSpec)) continue;
          final key = axes.formatKey({...features, 'genus_verbi': 'akt'});
          moved[key] = entry.value;
          deponent.add(key);
        } else if (genus == 'akt' && _deponentDrops(features, deponentSpec)) {
          continue; // the passive form takes this key, or nothing does
        } else {
          moved[entry.key] = entry.value;
        }
      }
      emitted
        ..clear()
        ..addAll(moved);
    }

    final keys = emitted.keys.toSet();
    for (final pattern in item.absent) {
      final removed = keys
          .where((key) => _patternMatches(axes.parseKey(key), pattern))
          .toSet();
      if (removed.isEmpty) {
        _fail(
          'S15',
          file.path,
          'absent pattern $pattern removes no key',
          item: item.id,
        );
      }
      final overridden = removed.intersection(item.forms.keys.toSet());
      if (overridden.isNotEmpty) {
        _fail(
          'S15',
          file.path,
          'absent pattern $pattern removes the overridden key '
              '${overridden.first}',
          item: item.id,
        );
      }
      keys.removeAll(removed);
      internal.removeWhere(
        (key) => _patternMatches(axes.parseKey(key), pattern),
      );
    }
    keys.addAll(item.forms.keys);

    return ItemKeys(
      emitted: keys,
      internal: internal,
      deponent: deponent,
      stems: stems,
    );
  }

  /// S10: the passive key moves onto its active key.
  bool _deponentMoves(Map<String, String> features, DeponentSpec deponent) =>
      _deponentDrops(features, deponent) ||
      (features['modus'] == 'part' &&
          features['tempus'] == 'perf' &&
          deponent.contains('perf'));

  /// S10: the active key goes, whether or not a passive form takes it.
  bool _deponentDrops(Map<String, String> features, DeponentSpec deponent) {
    final modus = features['modus'];
    final tempus = features['tempus'];
    if (tempus == null || !deponent.contains(tempus)) return false;
    if (modus == 'ind' || modus == 'konj' || modus == 'imp') return true;
    return modus == 'inf' && (tempus == 'praes' || tempus == 'perf');
  }

  /// Whether [features] has one of the listed codes on every named axis.
  bool _matchesAny(
    Map<String, String> features,
    Map<String, List<String>> match,
  ) => match.entries.every((e) => e.value.contains(features[e.key]));

  bool _patternMatches(
    Map<String, String> features,
    Map<String, String> pattern,
  ) => pattern.entries.every((e) => features[e.key] == e.value);

  /// S13: the keys one compose rule makes.
  Set<FormKey> _composedKeys(
    GrammarFile file,
    GrammarItem item,
    ComposeSpec compose,
    Set<String> stems,
  ) {
    final axes = file.axes;
    final type = file.type(item.typeName);

    final passAllPart = compose.parts
        .whereType<LexemePart>()
        .where((p) => p.passAll)
        .firstOrNull;
    if (passAllPart != null) {
      final target = file.item(passAllPart.lexeme);
      final targetKeys = _planKeys(file, target);
      if (compose.parts.whereType<StemPart>().any(
        (p) => !stems.contains(p.stem),
      )) {
        return const {};
      }
      return {
        for (final key in {...targetKeys.emitted, ...targetKeys.internal})
          if (_matchesAny(axes.parseKey(key), compose.match)) key,
      };
    }

    final axisCodes = <String, List<String>>{};
    for (final entry in compose.match.entries) {
      axisCodes[entry.key] = entry.value;
    }
    for (final part in compose.parts) {
      for (final axisId in [...part.pass, ...part.map.keys]) {
        axisCodes.putIfAbsent(axisId, () => axes.byId(axisId).codes.toList());
      }
    }

    var bundles = <Map<String, String>>[{}];
    for (final entry in axisCodes.entries) {
      bundles = [
        for (final bundle in bundles)
          for (final code in entry.value) {...bundle, entry.key: code},
      ];
    }

    final keys = <FormKey>{};
    for (final bundle in bundles) {
      if (compose.parts.every(
        (p) => p.optional || _partResolves(file, item, type, p, bundle, stems),
      )) {
        keys.add(axes.formatKey(bundle));
      }
    }
    return keys;
  }

  /// Whether one compose part has a form for [bundle] (S13).
  bool _partResolves(
    GrammarFile file,
    GrammarItem item,
    GrammarType type,
    ComposePart part,
    Map<String, String> bundle,
    Set<String> stems,
  ) {
    if (part is StemPart) return stems.contains(part.stem);

    final features = <String, String>{...part.set};
    for (final axisId in part.pass) {
      final code = bundle[axisId];
      if (code != null) features[axisId] = code;
    }
    for (final entry in part.map.entries) {
      final code = bundle[entry.key];
      if (code != null) features[entry.key] = entry.value[code] ?? code;
    }

    if (part is SelfPart) {
      final delegate = type.delegates
          .where((d) => d.name == part.delegate)
          .firstOrNull;
      if (delegate == null) {
        _fail(
          'S13',
          file.path,
          'compose names the unknown delegate "${part.delegate}"',
          item: item.id,
        );
      }
      final target = _typeByName[delegate.type]!;
      final targetAxes = _fileOfType[delegate.type]!.axes;
      final wanted = {...item.selfLookup(features, bundle['genus_verbi'])}
        ..removeWhere((axis, value) => delegate.set[axis] == value);
      return target.forms.entries.any((entry) {
        final targetStem = entry.value.first.stemName;
        if (targetStem != null && !stems.contains(delegate.bind[targetStem])) {
          return false;
        }
        return _patternMatches(targetAxes.parseKey(entry.key), wanted);
      });
    }

    final lexeme = switch (part) {
      LexemePart(:final lexeme) => lexeme,
      SlotPart(:final slot) => slotFiller(type, item, slot),
      _ => throw StateError('$part is a self or stem part'),
    };
    if (lexeme == null) return false;
    final target = file.item(lexeme);
    return _planKeys(file, target).has(file.axes.formatKey(features));
  }
}
