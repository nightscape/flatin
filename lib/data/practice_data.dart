import 'dart:async';

import 'asset_text.dart';
import '../grammar/engine.dart';
import '../grammar/schema.dart';
import '../models/derivation.dart';
import '../models/practice_item.dart';
import 'word_focus.dart' show irregularVerbTypes;

/// The data files, by data file id. Nouns and verbs are parsed together
/// because the verbs delegate their participles to noun ending tables.
const _assets = {
  'nouns': 'lib/data/latin_nouns.yaml',
  'verbs': 'lib/data/latin_verbs.yaml',
  'vocab': 'lib/data/latin_vocab.yaml',
};

/// What the settings screen offers for one data file.
class FormMetadata {
  final String dataFileId;
  final Axes axes;

  /// Every key that some item of the file practises, in S7 order.
  final List<FormKey> formOrder;
  final Map<FormKey, FormLabel> formLabelsByKey;

  /// The types that items of the file have, sorted.
  final List<String> availableTypes;

  /// S20: each of [availableTypes] as the learner reads it.
  final Map<String, String> displayByType;

  FormMetadata({
    required this.dataFileId,
    required this.axes,
    required this.formOrder,
    required this.formLabelsByKey,
    required this.availableTypes,
    required this.displayByType,
  });
}

/// One parse of the data files, with every text in one language.
class _Parsed {
  final GrammarEngine engine;
  final Map<String, List<PracticeItem>> itemsByFile = {};
  final Map<String, FormMetadata> metadataByFile = {};

  _Parsed(this.engine);

  GrammarFile file(String dataFileId) =>
      engine.files.singleWhere((f) => f.dataFileId == dataFileId);
}

/// The texts of the data files, parsed once per language on first use. The
/// course language is parsed at once, so a broken file fails the first load.
class _Loaded {
  final Map<String, String> sources;
  final Map<String, _Parsed> _byLanguage = {};

  _Loaded(this.sources) {
    parsed(courseLanguage);
  }

  _Parsed parsed(String language) => _byLanguage[language] ??= _Parsed(
    GrammarEngine(parseGrammarFiles(sources, language: language)),
  );
}

_Loaded? _loaded;
Zone? _parsingZone;
final _waiting = <Completer<_Loaded>>[];

/// Awaited before the data files are read, so a test can hold a load open and
/// abandon it. The app leaves the no-op default in place.
Future<void> Function() parseGate = () async {};

/// Puts the loader back to the state of a fresh process, so a test can drive
/// the first load again.
void resetPracticeDataForTest() {
  _loaded = null;
  _parsingZone = null;
  _waiting.clear();
}

/// No future is kept between calls: awaiting one resumes in the zone that
/// created it, and a widget test's fake-time zone is dead as soon as its test
/// ends. Callers of the parsing zone share the parse through a completer of
/// their own; a caller of any other zone parses for itself rather than wait
/// on a zone that may never run again. The take-over adopts the callers that
/// were queued behind the parse it replaces: they get its result, or its
/// error.
Future<_Loaded> _load() async {
  if (_loaded != null) return _loaded!;
  if (identical(_parsingZone, Zone.current)) {
    final waiter = Completer<_Loaded>();
    _waiting.add(waiter);
    return waiter.future;
  }
  _parsingZone = Zone.current;
  final _Loaded loaded;
  try {
    loaded = await _parse();
  } catch (error, stack) {
    _release((waiter) => waiter.completeError(error, stack));
    rethrow;
  }
  _loaded ??= loaded;
  _release((waiter) => waiter.complete(_loaded!));
  return _loaded!;
}

/// Hands the parse result to every queued caller, whichever zone owns the
/// parse now, and gives up ownership unless another zone has taken it over.
void _release(void Function(Completer<_Loaded>) finish) {
  if (identical(_parsingZone, Zone.current)) _parsingZone = null;
  _waiting.forEach(finish);
  _waiting.clear();
}

Future<_Loaded> _parse() async {
  await parseGate();
  final sources = {
    for (final path in _assets.values) path: await loadAssetText(path),
  };
  return _Loaded(sources);
}

String _dataFileIdOf(String assetPath) =>
    _assets.entries.singleWhere((e) => e.value == assetPath).key;

Future<FormMetadata> getFormMetadata(
  String assetPath, {
  String language = courseLanguage,
}) async {
  final loaded = (await _load()).parsed(language);
  final dataFileId = _dataFileIdOf(assetPath);
  return loaded.metadataByFile[dataFileId] ??= _metadata(
    loaded.file(dataFileId),
  );
}

FormMetadata _metadata(GrammarFile file) {
  final keys =
      {
        for (final item in file.items) ...file.keysByItem[item.id]!.emitted,
      }.toList()..sort(
        (a, b) =>
            file.axes.compare(file.axes.parseKey(a), file.axes.parseKey(b)),
      );
  final types = {for (final item in file.items) item.typeName}.toList()..sort();
  return FormMetadata(
    dataFileId: file.dataFileId,
    axes: file.axes,
    formOrder: keys,
    formLabelsByKey: {
      for (final key in keys) key: FormLabel.fromKey(key, file.axes),
    },
    availableTypes: types,
    displayByType: {for (final type in types) type: file.type(type).display!},
  );
}

Future<List<PracticeItem>> loadPracticeItems(
  String assetPath, {
  String language = courseLanguage,
}) async {
  final all = await _load();
  final loaded = all.parsed(language);
  final file = loaded.file(_dataFileIdOf(assetPath));
  final book = {
    for (final item in all.parsed(courseLanguage).file(file.dataFileId).items)
      item.id: item.translation,
  };
  final cached = loaded.itemsByFile[file.dataFileId];
  if (cached != null) return cached;
  final endings = endingSetsOf(loaded.engine, file);
  return loaded.itemsByFile[file.dataFileId] = [
    for (final item in file.items)
      _practiceItem(loaded.engine, file, item, book[item.id]!, endings),
  ];
}

/// The items of every data file, nouns first.
Future<List<PracticeItem>> loadAllPracticeItems({
  String language = courseLanguage,
}) async => [
  for (final path in _assets.values)
    ...await loadPracticeItems(path, language: language),
];

/// The parsed data file [dataFileId] in the course language.
Future<GrammarFile> loadGrammarFile(String dataFileId) async =>
    (await _load()).parsed(courseLanguage).file(dataFileId);

PracticeItem _practiceItem(
  GrammarEngine engine,
  GrammarFile file,
  GrammarItem item,
  String bookTranslation,
  Map<String, List<EndingSet>> endings,
) {
  final derivation = engine.of(file.dataFileId, item.id);
  final keys = derivation.forms.keys.toList();
  final forms = derivation.forms.values;

  // The lemma part leads; the given part is a practised form, so it carries
  // no label of its own.
  final lemmaPart = (file.lemmaPart ?? file.givenPart)!;
  final partNames = [
    lemmaPart,
    ...item.parts.keys.where((name) => name != lemmaPart),
  ].where((name) => file.parts[name]!.display);

  return PracticeItem(
    id: '${file.dataFileId}:${item.id}',
    lemma: item.lemma,
    type: item.typeName,
    translation: item.translation,
    bookTranslation: bookTranslation,
    principalParts: [
      for (final name in partNames)
        (
          name == file.givenPart ? '' : file.parts[name]!.label,
          item.part(name)!,
        ),
    ],
    forms: [for (final form in forms) form.result],
    acceptedForms: [for (final form in forms) form.variants],
    formLabels: [for (final key in keys) FormLabel.fromKey(key, file.axes)],
    possibleTypes: item.typeRule?.types,
    dataFileId: file.dataFileId,
    formOrder: keys,
    derivation: derivation,
    // A vocab item is asked only for its meaning.
    baseFormKeys: file.dataFileId == 'vocab'
        ? const []
        : _baseFormKeys(
            file,
            item,
            derivation,
            engine.regularOf(file.dataFileId, item.id),
            endings,
          ),
    genus: file.genusOf(item),
    inferredForms: [
      for (final form in forms)
        form is IrregularForm && form.regular != null
            ? form.regular!.result
            : form.result,
    ],
  );
}

/// The file's base forms, then the item's displayed parts, then every form
/// the rules cannot give and its [regular] reading writes otherwise, minus the
/// forms [dropFollowing] removes; without the lemma's key, which the screen
/// shows.
List<FormKey> _baseFormKeys(
  GrammarFile file,
  GrammarItem item,
  Derivation derivation,
  Derivation? regular,
  Map<String, List<EndingSet>> endings,
) {
  final asked = baseFormKeysBeforeRules(file, item, derivation, regular);
  final lemmaKey = _keyOf(
    file,
    item,
    derivation,
    file.lemmaPart ?? file.givenPart!,
  );
  return dropFollowing(
    asked,
    {lemmaKey},
    derivation.forms,
    regular?.forms,
    item.impersonalPassive,
    endings,
  );
}

FormKey _keyOf(
  GrammarFile file,
  GrammarItem item,
  Derivation derivation,
  String part,
) => file.parts[part]!.keys.firstWhere(
  derivation.forms.containsKey,
  orElse: () => throw StateError(
    '${file.dataFileId}:${item.id} has no key for its part "$part"',
  ),
);

/// The base forms before [dropFollowing] removes the ones a rule gives.
List<FormKey> baseFormKeysBeforeRules(
  GrammarFile file,
  GrammarItem item,
  Derivation derivation,
  Derivation? regular,
) {
  final forms = derivation.forms;
  return ({
        ...file.baseForms.where(forms.containsKey),
        for (final name in item.parts.keys)
          if (file.parts[name]!.display) _keyOf(file, item, derivation, name),
        for (final MapEntry(:key, :value) in forms.entries)
          if (value is IrregularForm &&
              !_writes(regular?.forms[key], value) &&
              !_writes(_gerundiveOf(key, forms), value))
            key,
      }..remove(
        _keyOf(file, item, derivation, (file.lemmaPart ?? file.givenPart)!),
      ))
      .toList();
}

/// What a rule reads: the item's [forms], its [regular] reading (empty without
/// one), whether it has the [impersonalPassive], the [endings] of the file and
/// the forms [available], asked or shown.
class FollowContext {
  final Map<FormKey, FormDerivation> forms;
  final Map<FormKey, FormDerivation> regular;
  final bool impersonalPassive;
  final Map<String, List<EndingSet>> endings;
  final Set<FormKey> available;

  const FollowContext(
    this.forms,
    this.regular,
    this.impersonalPassive,
    this.endings,
    this.available,
  );
}

/// The spellings a rule gives a form from the available form [source].
class Follow {
  final FormKey source;
  final List<String> gives;

  const Follow(this.source, this.gives);

  bool writes(FormDerivation form) =>
      gives.join('|') == form.variants.join('|');
}

/// What a rule gives `key` from an available form, or null when the rule does
/// not apply to `key`.
typedef FollowRule = Follow? Function(FormKey key, FollowContext context);

/// S28: the rules.
const followRules = <FollowRule>[
  followByFirstPerson,
  followByImperfectSubjunctive,
  followByPluperfectSubjunctive,
  followByImpersonalPassive,
];

/// The form `key` follows from by some rule that gives the data's spelling.
FormKey? followedFrom(
  FormKey key,
  FollowContext context, [
  List<FollowRule> rules = followRules,
]) {
  for (final rule in rules) {
    final follow = rule(key, context);
    if (follow != null && follow.writes(context.forms[key]!)) {
      return follow.source;
    }
  }
  return null;
}

/// S28: [asked] without the forms some rule gives from a form that is asked or
/// [shown]; a source that is dropped itself leads back to an asked or shown
/// form, because no rule reads a form that depends on its own target.
List<FormKey> dropFollowing(
  List<FormKey> asked,
  Set<FormKey> shown,
  Map<FormKey, FormDerivation> forms,
  Map<FormKey, FormDerivation>? regular,
  bool impersonalPassive,
  Map<String, List<EndingSet>> endings,
) {
  final context = FollowContext(
    forms,
    regular ?? const {},
    impersonalPassive,
    endings,
    {...asked, ...shown},
  );
  return [
    for (final key in asked)
      if (followedFrom(key, context) == null) key,
  ];
}

/// The endings one tense, voice and mood swaps for another person, by person
/// (`2.sg`): the ending the 1 sg spelling loses and the ending it takes.
typedef EndingSet = Map<String, (String, String)>;

/// The ending sets of the impersonal passive are filed under this tense voice.
const impersonal = 'impersonal';

const _persons = ['2.sg', '3.sg', '1.pl', '2.pl', '3.pl'];

/// S28: the [EndingSet]s of each tense, voice and mood (`ind.fut.akt`) that
/// the generated forms of the regular conjugation types show, never those of
/// an irregular type, whose paradigm is the verb's own; the impersonal passive's sets
/// are filed under `mood.tense.impersonal`.
Map<String, List<EndingSet>> endingSetsOf(
  GrammarEngine engine,
  GrammarFile file,
) {
  final byFamily = <String, Map<String, EndingSet>>{};
  final doneTypes = <String>{};
  for (final item in file.items.where(
    (i) => !irregularVerbTypes.contains(i.typeName),
  )) {
    final forms = engine.of(file.dataFileId, item.id).forms;
    for (final key in forms.keys.where((k) => k.endsWith('.1.sg'))) {
      final family = key.substring(0, key.length - 5);
      final generated = [
        for (final person in ['1.sg', ..._persons]) forms['$family.$person'],
      ];
      if (generated.any((f) => f == null || f is IrregularForm) ||
          !doneTypes.add('${item.typeName}/$family')) {
        continue;
      }
      final one = generated.first!.result;
      byFamily.putIfAbsent(family, () => {})[item.typeName] = {
        for (var i = 0; i < _persons.length; i++)
          _persons[i]: _swap(one, generated[i + 1]!.result),
      };
    }
    for (final key in forms.keys.where((k) => k.endsWith('.akt.3.sg'))) {
      final active = forms[key]!;
      final passive = forms[key.replaceFirst('.akt.', '.pass.')];
      final family = '${key.substring(0, key.length - 9)}.$impersonal';
      if (passive == null ||
          active is IrregularForm ||
          passive is IrregularForm ||
          !doneTypes.add('${item.typeName}/$family')) {
        continue;
      }
      byFamily.putIfAbsent(family, () => {})[item.typeName] = {
        '3.sg': _swap(active.result, passive.result),
      };
    }
  }
  return {
    for (final MapEntry(:key, :value) in byFamily.entries)
      key: {
        for (final set in value.values) set.toString(): set,
      }.values.toList(),
  };
}

(String, String) _swap(String from, String to) {
  var common = 0;
  while (common < from.length &&
      common < to.length &&
      from[common] == to[common]) {
    common++;
  }
  return (from.substring(common), to.substring(common));
}

/// S28: another person of a tense follows from the first person singular
/// when exactly one ending set of the file fits that form's ending
/// (`ībās` from `ībam`, not `īs` from `eō`).
Follow? followByFirstPerson(FormKey key, FollowContext context) {
  final parts = key.split('.');
  if (parts.length != 5 ||
      !const {'ind', 'konj'}.contains(parts[0]) ||
      (parts[3] == '1' && parts[4] == 'sg')) {
    return null;
  }
  final family = parts.take(3).join('.');
  return _followByEndings(
    '$family.1.sg',
    family,
    '${parts[3]}.${parts[4]}',
    context,
  );
}

/// S28: the active imperfect subjunctive is the present infinitive plus an
/// ending (`ferrēs` from `ferre`).
Follow? followByImperfectSubjunctive(FormKey key, FollowContext context) =>
    key.startsWith('konj.impf.akt.')
    ? _followByRegularSwap('inf.praes.akt', key, context)
    : null;

/// S28: the active pluperfect subjunctive is the perfect infinitive plus an
/// ending (`īssem` from `īsse`).
Follow? followByPluperfectSubjunctive(FormKey key, FollowContext context) =>
    key.startsWith('konj.plusq.akt.')
    ? _followByRegularSwap('inf.perf.akt', key, context)
    : null;

/// S28: the impersonal passive follows from the active third person singular
/// of the same tense and mood (`ībātur` from `ībat`).
Follow? followByImpersonalPassive(FormKey key, FollowContext context) {
  final parts = key.split('.');
  return context.impersonalPassive &&
          parts.length == 5 &&
          parts[2] == 'pass' &&
          parts[3] == '3' &&
          parts[4] == 'sg'
      ? _followByEndings(
          '${parts[0]}.${parts[1]}.akt.3.sg',
          '${parts[0]}.${parts[1]}.$impersonal',
          '3.sg',
          context,
        )
      : null;
}

/// The spelling of `source` with the swap's ending replaced, or null when
/// `source` does not end in it.
List<String>? _swapped(Iterable<String> source, (String, String) swap) =>
    source.every((v) => v.endsWith(swap.$1))
    ? [
        for (final v in source)
          v.substring(0, v.length - swap.$1.length) + swap.$2,
      ]
    : null;

/// The spellings `source` gives for `person` when exactly one ending set under
/// `setsKey` fits it.
Follow? _followByEndings(
  FormKey source,
  String setsKey,
  String person,
  FollowContext context,
) {
  if (!context.available.contains(source)) return null;
  final one = context.forms[source]!.variants;
  final fitting = [
    for (final set in context.endings[setsKey] ?? const <EndingSet>[])
      if (set.values.every((swap) => _swapped(one, swap) != null)) set,
  ];
  return fitting.length == 1
      ? Follow(source, _swapped(one, fitting.single[person]!)!)
      : null;
}

/// The spellings `source` gives when its ending is swapped the way the
/// regular reading swaps it into `target`.
Follow? _followByRegularSwap(
  FormKey source,
  FormKey target,
  FollowContext context,
) {
  final from = context.regular[source]?.result;
  final to = context.regular[target]?.result;
  if (from == null || to == null || !context.available.contains(source)) {
    return null;
  }
  final gives = _swapped(context.forms[source]!.variants, _swap(from, to));
  return gives == null ? null : Follow(source, gives);
}

bool _writes(FormDerivation? form, FormDerivation value) =>
    form?.variants.join('|') == value.variants.join('|');

/// S27: the gerundive form a gerund key follows from, `ger.gen` from
/// `gerv.sg.gen.n`.
FormDerivation? _gerundiveOf(FormKey key, Map<FormKey, FormDerivation> forms) =>
    key.startsWith('ger.') ? forms['gerv.sg.${key.substring(4)}.n'] : null;
