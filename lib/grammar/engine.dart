/// Fills the key plan of `schema.dart` with forms and their trace (3.2).
///
/// `GrammarFile.keysByItem` is the key plan: the engine never decides which
/// keys an item has, only what stands under them. A key the plan names and the
/// engine cannot fill is a contract defect and throws.
library;

import '../data/lesson_data.dart' show normalizeDiacritics;
import '../models/derivation.dart';
import '../models/form_label.dart';
import 'schema.dart';
import 'type_inference.dart';

// ---------------------------------------------------------------- letters

const _vowels = 'aeiouy';
final _combining = RegExp(r'[̀-ͯ]');

/// The letters of [word]; a letter carries its combining marks.
List<String> letters(String word) {
  final out = <String>[];
  for (final rune in word.runes) {
    final char = String.fromCharCode(rune);
    if (out.isNotEmpty && _combining.hasMatch(char)) {
      out[out.length - 1] += char;
    } else {
      out.add(char);
    }
  }
  return out;
}

/// [letter] without its quantity mark.
String _short(String letter) =>
    normalizeDiacritics(letter.replaceAll(_combining, ''));

bool _isVowel(String letter) => _vowels.contains(_short(letter).toLowerCase());

// ---------------------------------------------------------------- sandhi

/// A seam after S16: the left side as it is written, and the rule that
/// changed it.
typedef Seam = ({String text, SandhiRule? rule});

/// S16: the first rule of [rules] that matches the seam [left]|[right].
///
/// The first entry is the spelling that is shown; a `variant: true` rule adds
/// the other one, ordered by how [lemma] writes it.
List<Seam> sandhiSeam(
  List<SandhiRuleSpec> rules,
  String left,
  String right, {
  required bool wordFinal,
  String lemma = '',
}) {
  final leftLetters = letters(left);
  final Seam plain = (text: left, rule: null);
  if (leftLetters.isEmpty) return [plain];

  for (final spec in rules) {
    final cut = _endMatch(spec, leftLetters);
    if (cut == 0) continue;
    if (!_beforeMatch(spec, right, wordFinal: wordFinal)) continue;
    final text = _replace(spec, leftLetters, cut, right);
    if (text == left) return [plain]; // a no-op rule is not recorded
    final applied = (
      text: text,
      rule: SandhiRule(id: spec.id, explain: spec.explain),
    );
    if (!spec.variant) return [applied];
    final written = norm(lemma);
    if (written.startsWith(norm(left)) && !written.startsWith(norm(text))) {
      return [plain, applied];
    }
    return [applied, plain];
  }
  return [plain];
}

/// The shown side of the seam (I2).
Seam sandhi(
  List<SandhiRuleSpec> rules,
  String left,
  String right, {
  required bool wordFinal,
  String lemma = '',
}) => sandhiSeam(rules, left, right, wordFinal: wordFinal, lemma: lemma).first;

/// How many letters of the left side the rule replaces, 0 if it does not
/// match.
int _endMatch(SandhiRuleSpec spec, List<String> left) {
  if (spec.end == 'vowel') return _isVowel(left.last) ? 1 : 0;
  if (spec.end == 'consonant') return _isVowel(left.last) ? 0 : 1;
  final want = letters(spec.end);
  if (want.length > left.length) return 0;
  final start = left.length - want.length;
  for (var i = 0; i < want.length; i++) {
    if (norm(left[start + i]) != norm(want[i])) return 0;
  }
  return want.length;
}

bool _beforeMatch(
  SandhiRuleSpec spec,
  String right, {
  required bool wordFinal,
}) {
  final rightLetters = letters(right);
  final beforeClass = spec.beforeClass;
  if (beforeClass != null) {
    if (rightLetters.isEmpty) return false;
    return _isVowel(rightLetters.first) == (beforeClass == 'vowel');
  }
  for (final start in spec.beforeStarts!) {
    if (start == r'$') {
      if (wordFinal && right.isEmpty) return true;
    } else if (start.endsWith(r'$')) {
      final want = start.substring(0, start.length - 1);
      if (wordFinal && norm(right) == norm(want)) return true;
    } else if (norm(right).startsWith(norm(start))) {
      return true;
    }
  }
  return false;
}

String _replace(SandhiRuleSpec spec, List<String> left, int cut, String right) {
  final kept = left.sublist(0, left.length - cut).join();
  final replaced = left.sublist(left.length - cut);
  return switch (spec.replace) {
    SandhiReplace.literal => kept + spec.replaceText,
    SandhiReplace.short => kept + replaced.map(_short).join(),
    SandhiReplace.doubleNext => kept + letters(right).first,
  };
}

// ---------------------------------------------------------------- engine

/// Builds the forms and the trace of every item of a parsed data file set.
final class GrammarEngine {
  final List<GrammarFile> files;

  final Map<String, GrammarFile> _byDataFile = {};
  final Map<String, GrammarFile> _byType = {};
  final Map<String, Derivation> _done = {};
  final Set<String> _busy = {};

  late final Grammar grammar;

  GrammarEngine(this.files) {
    for (final file in files) {
      _byDataFile[file.dataFileId] = file;
      for (final name in file.declaredTypes.keys) {
        _byType[name] = file;
      }
    }
    grammar = Grammar(
      {
        for (final file in files)
          for (final type in file.declaredTypes.entries)
            type.key: {
              for (final form in type.value.forms.entries)
                form.key: Template(
                  stemName: form.value.first.stemName,
                  endings: [for (final template in form.value) template.ending],
                ),
            },
      },
      {
        for (final file in files)
          for (final type in file.declaredTypes.entries)
            if (type.value.wordClass case final wordClass?) type.key: wordClass,
      },
    );
  }

  Derivation of(String dataFileId, String itemId) {
    final file = _byDataFile[dataFileId]!;
    return _derive(file, file.item(itemId));
  }

  GrammarType _resolved(String typeName) => _byType[typeName]!.types[typeName]!;

  /// S6: the type that wrote [key]'s template — the first of the inheritance
  /// chain that declares it.
  String _endingType(String typeName, FormKey key) {
    var name = typeName;
    while (true) {
      final declared = _byType[name]!.declaredTypes[name]!;
      if (declared.forms.containsKey(key)) return name;
      name = declared.inheritsFrom!;
    }
  }

  Derivation _derive(GrammarFile file, GrammarItem item) {
    final id = '${file.dataFileId}/${item.id}';
    final done = _done[id];
    if (done != null) return done;
    if (!_busy.add(id)) throw StateError('composition cycle at $id');
    final built = _ItemBuilder(this, file, item).build();
    _busy.remove(id);
    return _done[id] = built;
  }
}

/// A form whose key is not settled yet: S10 may still move it.
final class _Made {
  final List<String> variants;
  final FormDerivation Function(FormKey key) build;

  _Made(this.variants, this.build);
}

/// One spelling of a composed form: its parts and the text each contributes.
typedef _Rendering = ({List<FormPart> parts, List<String> texts});

/// One part of a composition: what it may read, and how it is written down.
final class _PartSource {
  final List<String> variants;
  final bool isAffix;
  final FormPart Function(String text, SandhiRule? rule) make;

  _PartSource({
    required this.variants,
    required this.isAffix,
    required this.make,
  });
}

final class _ItemBuilder {
  final GrammarEngine engine;
  final GrammarFile file;
  final GrammarItem item;
  final GrammarType type;
  final ItemKeys plan;
  final Axes axes;
  final List<SandhiRuleSpec> rules;

  final Map<String, StemDerivation> stems = {};
  final Map<FormKey, _Made> made = {};
  final Map<FormKey, _Made> internal = {};

  /// Delegate name → its output before S10 and before item overrides (S13).
  final Map<String, Map<FormKey, FormDerivation>> delegated = {};

  final Set<FormKey> deponentKeys = {};
  final Set<FormKey> overridden = {};

  _ItemBuilder(this.engine, this.file, this.item)
    : type = file.type(item.typeName),
      plan = file.keysByItem[item.id]!,
      axes = file.axes,
      rules = [
        for (final id in file.type(item.typeName).sandhi) file.sandhi[id]!,
      ];

  Derivation build() {
    for (final name in plan.stems) {
      _stem(name, const []);
    }
    _ownForms();
    _delegates();
    _deponent(made);
    _applyOverrides(made.containsKey);
    _compose();
    _applyOverrides((_) => true);
    made.removeWhere((key, _) => !plan.emitted.contains(key));
    internal.removeWhere((key, _) => !plan.internal.contains(key));
    _checkPlan();

    return Derivation(
      type: item.typeName,
      recognition: recognizeType(item),
      stems: stems,
      forms: _ordered(made),
      deponentKeys: deponentKeys.intersection(made.keys.toSet()),
      fullDeponent: (item.deponent ?? type.deponent)?.all ?? false,
      internal: _ordered(internal),
      grammar: engine.grammar,
    );
  }

  // -------------------------------------------------------------- stems

  StemDerivation _stem(String name, List<String> chain) {
    final cached = stems[name];
    if (cached != null) return cached;
    assert(!chain.contains(name), 'stem cycle ${chain.join(" → ")} → $name');
    final spec = type.stems[name]!;
    final display = spec.display ?? name;
    final from = spec.from;
    final given = from == null ? null : item.parts[from];

    if (given != null) {
      final cuts = [for (final spelling in given) _cut(spec, spelling)];
      return stems[name] = StemFromPart(
        name: name,
        display: display,
        variants: [for (final cut in cuts) cut.$1],
        part: from!,
        sourceWord: given.first,
        removedSuffix: cuts.first.$2,
      );
    }

    final template = (from == null ? spec.template : spec.defaultTemplate)!;
    final base = _stem(template.stemName!, [...chain, name]);
    final variants = <String>[];
    SandhiRule? rule;
    for (final spelling in base.variants) {
      final seams = sandhiSeam(
        rules,
        spelling,
        template.ending,
        wordFinal: false,
        lemma: item.lemma,
      );
      for (final seam in seams) {
        if (variants.isEmpty) rule = seam.rule;
        variants.add(seam.text + template.ending);
      }
    }
    return stems[name] = StemFromDefault(
      name: name,
      display: display,
      variants: _distinct(variants),
      template: template.toString(),
      base: base,
      sandhiRule: rule,
    );
  }

  /// S3: the first suffix that matches macron-insensitively, with the item's
  /// own macrons kept.
  (String, String) _cut(StemSpec spec, String spelling) {
    if (spec.remove.isEmpty) return (spelling, '');
    final suffix = spec.remove.firstWhere(
      (suffix) => norm(spelling).endsWith(norm(suffix)),
    );
    final written = letters(spelling);
    final keep = written.length - letters(suffix).length;
    return (written.sublist(0, keep).join(), suffix);
  }

  // -------------------------------------------------------------- forms

  void _ownForms() {
    for (final entry in type.forms.entries) {
      final stemName = entry.value.first.stemName;
      if (stemName != null && !stems.containsKey(stemName)) continue;
      made[entry.key] = _fromTemplates(
        entry.value,
        stemName,
        engine._endingType(type.name, entry.key),
      );
    }
  }

  void _delegates() {
    for (final delegate in type.delegates) {
      final target = engine._resolved(delegate.type);
      final targetAxes = engine._byType[delegate.type]!.axes;
      final output = delegated[delegate.name] = {};
      for (final entry in target.forms.entries) {
        final targetStem = entry.value.first.stemName;
        final bound = targetStem == null ? null : delegate.bind[targetStem];
        if (targetStem != null && !stems.containsKey(bound)) continue;
        final key = axes.formatKey({
          ...targetAxes.parseKey(entry.key),
          ...delegate.set,
        });
        final form = _fromTemplates(
          entry.value,
          bound,
          engine._endingType(delegate.type, entry.key),
        );
        output[key] = form.build(key);
        (delegate.emit ? made : internal)[key] = form;
      }
    }
  }

  /// S9: stem variants × template spellings, stem-major, each with its seam.
  _Made _fromTemplates(
    List<FormTemplate> templates,
    String? stemName,
    String endingType,
  ) {
    if (stemName == null) {
      final literals = [for (final template in templates) template.ending];
      return _Made(
        literals,
        (key) => IrregularForm(formKey: key, variants: literals),
      );
    }
    final variants = <String>[];
    SandhiRule? rule;
    for (final spelling in stems[stemName]!.variants) {
      for (final template in templates) {
        final seams = sandhiSeam(
          rules,
          spelling,
          template.ending,
          wordFinal: true,
          lemma: item.lemma,
        );
        for (final seam in seams) {
          if (variants.isEmpty) rule = seam.rule;
          variants.add(seam.text + template.ending);
        }
      }
    }
    final all = _distinct(variants);
    final ending = templates.first.ending;
    return _Made(
      all,
      (key) => GeneratedForm(
        formKey: key,
        variants: all,
        stemName: stemName,
        ending: ending,
        endingType: endingType,
        sandhiRule: rule,
      ),
    );
  }

  // ----------------------------------------------------------- deponent

  void _deponent(Map<FormKey, _Made> forms) {
    final spec = item.deponent ?? type.deponent;
    if (spec == null) return;
    assert(
      axes.axes.any((axis) => axis.id == 'genus_verbi'),
      'S10 is checked at load',
    );
    final moved = <FormKey, _Made>{};
    for (final entry in forms.entries) {
      final features = axes.parseKey(entry.key);
      final genus = features['genus_verbi'];
      if (genus == 'pass') {
        if (!_moves(features, spec)) continue;
        final key = axes.formatKey({...features, 'genus_verbi': 'akt'});
        moved[key] = entry.value;
        deponentKeys.add(key);
      } else if (genus == 'akt' && _drops(features, spec)) {
        continue; // the passive form takes this key, or nothing does
      } else {
        moved[entry.key] = entry.value;
      }
    }
    forms
      ..clear()
      ..addAll(moved);
  }

  bool _moves(Map<String, String> features, DeponentSpec spec) =>
      _drops(features, spec) ||
      (features['modus'] == 'part' &&
          features['tempus'] == 'perf' &&
          spec.contains('perf'));

  bool _drops(Map<String, String> features, DeponentSpec spec) {
    final modus = features['modus'];
    final tempus = features['tempus'];
    if (tempus == null || !spec.contains(tempus)) return false;
    if (modus == 'ind' || modus == 'konj' || modus == 'imp') return true;
    return modus == 'inf' && (tempus == 'praes' || tempus == 'perf');
  }

  // ---------------------------------------------------------- overrides

  void _applyOverrides(bool Function(FormKey key) now) {
    for (final entry in item.forms.entries) {
      if (overridden.contains(entry.key) || !now(entry.key)) continue;
      overridden.add(entry.key);
      final regular = made[entry.key];
      // I4: an override that only repeats the rule is no irregularity. The
      // macron is part of the form, so a quantity-only override is a
      // correction and stays.
      if (regular != null && _sameWriting(regular.variants, entry.value)) {
        continue;
      }
      final rule = regular?.build(entry.key);
      made[entry.key] = _Made(
        entry.value,
        (key) =>
            IrregularForm(formKey: key, variants: entry.value, regular: rule),
      );
    }
  }

  // ------------------------------------------------------------ compose

  void _compose() {
    for (final key in plan.emitted) {
      if (made.containsKey(key)) continue;
      final source = plan.deponent.contains(key)
          ? axes.formatKey({...axes.parseKey(key), 'genus_verbi': 'pass'})
          : key;
      final features = axes.parseKey(source);
      for (final spec in type.composes) {
        final form = _composed(spec, features, source);
        if (form == null) continue;
        made[key] = form;
        if (source != key) deponentKeys.add(key);
        break;
      }
    }
  }

  /// S13: the composition [spec] gives for [key], or null if it does not
  /// produce that key or a part has no form.
  _Made? _composed(
    ComposeSpec spec,
    Map<String, String> features,
    FormKey key,
  ) {
    if (!spec.match.entries.every(
      (axis) => axis.value.contains(features[axis.key]),
    )) {
      return null;
    }
    final passAll = spec.parts.any((part) => part.passAll);
    if (!passAll) {
      final written = {
        ...spec.match.keys,
        for (final part in spec.parts) ...[...part.pass, ...part.map.keys],
      };
      if (written.length != features.length ||
          !written.containsAll(features.keys)) {
        return null;
      }
    }

    final sources = <_PartSource>[];
    for (final part in spec.parts) {
      final source = _partSource(part, features, key);
      if (source == null) return null;
      sources.add(source);
    }

    final seen = <String>{};
    final variants = <String>[];
    List<FormPart>? shown;
    for (final combination in _product([
      for (final source in sources) source.variants,
    ])) {
      for (final rendering in _render(sources, combination)) {
        final text = rendering.texts.join(spec.join);
        if (!seen.add(norm(text))) continue;
        variants.add(text);
        shown ??= rendering.parts;
      }
    }
    return _Made(
      variants,
      (formKey) => ComposedForm(
        formKey: formKey,
        variants: variants,
        parts: shown!,
        join: spec.join,
      ),
    );
  }

  _PartSource? _partSource(
    ComposePart part,
    Map<String, String> features,
    FormKey key,
  ) {
    if (part is StemPart) {
      final stem = stems[part.stem];
      if (stem == null) return null;
      return _PartSource(
        variants: stem.variants,
        isAffix: true,
        make: (text, rule) =>
            AffixPart(stemName: part.stem, text: text, sandhiRule: rule),
      );
    }

    final wanted = <String, String>{...part.set};
    for (final axis in part.pass) {
      final code = features[axis];
      if (code != null) wanted[axis] = code;
    }
    for (final entry in part.map.entries) {
      final code = features[entry.key];
      if (code != null) wanted[entry.key] = entry.value[code] ?? code;
    }

    final String lexemeId;
    final FormKey lookup;
    final FormDerivation? form;
    if (part is SelfPart) {
      final delegate = type.delegates.firstWhere(
        (candidate) => candidate.name == part.delegate,
      );
      lexemeId = item.id;
      lookup = axes.formatKey({...delegate.set, ...wanted});
      form = delegated[part.delegate]![lookup];
    } else {
      final target = file.item((part as LexemePart).lexeme);
      final derivation = engine._derive(file, target);
      lexemeId = target.id;
      lookup = part.passAll ? key : axes.formatKey(wanted);
      form = derivation.forms[lookup] ?? derivation.internal[lookup];
    }
    if (form == null) return null;
    return _PartSource(
      variants: form.variants,
      isAffix: false,
      make: (text, _) =>
          LexemeFormPart(lexemeId: lexemeId, key: lookup, derivation: form!),
    );
  }

  /// S18 c: the seam after an affix may add a variant of the whole word.
  /// A part's text is its own spelling; only [FormPart]s of the shown
  /// rendering are kept, so a `lexeme:` part keeps its own derivation (I3).
  List<_Rendering> _render(List<_PartSource> sources, List<String> texts) {
    var renderings = <_Rendering>[(parts: [], texts: [])];
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      if (!source.isAffix) {
        renderings = [
          for (final rendering in renderings)
            (
              parts: [...rendering.parts, source.make(texts[i], null)],
              texts: [...rendering.texts, texts[i]],
            ),
        ];
        continue;
      }
      final last = i == sources.length - 1;
      final seams = sandhiSeam(
        rules,
        texts[i],
        last ? '' : texts[i + 1],
        wordFinal: last,
        lemma: item.lemma,
      );
      renderings = [
        for (final rendering in renderings)
          for (final seam in seams)
            (
              parts: [...rendering.parts, source.make(seam.text, seam.rule)],
              texts: [...rendering.texts, seam.text],
            ),
      ];
    }
    return renderings;
  }

  // -------------------------------------------------------------- plan

  void _checkPlan() {
    final missing = plan.emitted.difference(made.keys.toSet());
    final missingInternal = plan.internal.difference(internal.keys.toSet());
    if (missing.isNotEmpty || missingInternal.isNotEmpty) {
      throw StateError(
        'item "${item.id}": the key plan names keys the engine cannot fill: '
        '${[...missing, ...missingInternal].join(", ")}',
      );
    }
    final planned = plan.deponent.intersection(plan.emitted);
    final moved = deponentKeys.intersection(made.keys.toSet());
    if (planned.length != moved.length || !planned.containsAll(moved)) {
      throw StateError(
        'item "${item.id}": the key plan moves $planned, the engine $moved',
      );
    }
  }

  /// S7.
  Map<FormKey, FormDerivation> _ordered(Map<FormKey, _Made> forms) {
    final keys = forms.keys.toList()
      ..sort((a, b) => axes.compare(axes.parseKey(a), axes.parseKey(b)));
    return {for (final key in keys) key: forms[key]!.build(key)};
  }
}

bool _sameWriting(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// S9: norm-equal spellings are one variant.
List<String> _distinct(List<String> values) {
  final seen = <String>{};
  return [
    for (final value in values)
      if (seen.add(norm(value))) value,
  ];
}

Iterable<List<String>> _product(List<List<String>> choices) {
  var rows = <List<String>>[[]];
  for (final choice in choices) {
    rows = [
      for (final row in rows)
        for (final value in choice) [...row, value],
    ];
  }
  return rows;
}
