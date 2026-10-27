import 'dart:async';

import 'asset_text.dart';
import '../grammar/engine.dart';
import '../grammar/schema.dart';
import '../models/derivation.dart';
import '../models/practice_item.dart';

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
  return loaded.itemsByFile[file.dataFileId] ??= [
    for (final item in file.items)
      _practiceItem(loaded.engine, file, item, book[item.id]!),
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
    inferredForms: [
      for (final form in forms)
        form is IrregularForm && form.regular != null
            ? form.regular!.result
            : form.result,
    ],
  );
}
