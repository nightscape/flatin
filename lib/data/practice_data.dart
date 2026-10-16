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

  FormMetadata({
    required this.dataFileId,
    required this.axes,
    required this.formOrder,
    required this.formLabelsByKey,
    required this.availableTypes,
  });
}

class _Loaded {
  final GrammarEngine engine;
  final Map<String, List<PracticeItem>> itemsByFile = {};
  final Map<String, FormMetadata> metadataByFile = {};

  _Loaded(this.engine);

  GrammarFile file(String dataFileId) =>
      engine.files.singleWhere((f) => f.dataFileId == dataFileId);
}

Future<_Loaded>? _loaded;

Future<_Loaded> _load() => _loaded ??= _parse();

Future<_Loaded> _parse() async {
  final sources = {
    for (final path in _assets.values) path: await loadAssetText(path),
  };
  return _Loaded(GrammarEngine(parseGrammarFiles(sources)));
}

String _dataFileIdOf(String assetPath) =>
    _assets.entries.singleWhere((e) => e.value == assetPath).key;

Future<FormMetadata> getFormMetadata(String assetPath) async {
  final loaded = await _load();
  final dataFileId = _dataFileIdOf(assetPath);
  return loaded.metadataByFile[dataFileId] ??= _metadata(loaded.file(dataFileId));
}

FormMetadata _metadata(GrammarFile file) {
  final keys = {
    for (final item in file.items) ...file.keysByItem[item.id]!.emitted,
  }.toList()
    ..sort((a, b) =>
        file.axes.compare(file.axes.parseKey(a), file.axes.parseKey(b)));
  return FormMetadata(
    dataFileId: file.dataFileId,
    axes: file.axes,
    formOrder: keys,
    formLabelsByKey: {
      for (final key in keys) key: FormLabel.fromKey(key, file.axes),
    },
    availableTypes: {for (final item in file.items) item.typeName}.toList()
      ..sort(),
  );
}

Future<List<PracticeItem>> loadPracticeItems(String assetPath) async {
  final loaded = await _load();
  final file = loaded.file(_dataFileIdOf(assetPath));
  return loaded.itemsByFile[file.dataFileId] ??= [
    for (final item in file.items) _practiceItem(loaded.engine, file, item),
  ];
}

/// The items of every data file, nouns first.
Future<List<PracticeItem>> loadAllPracticeItems() async => [
      for (final path in _assets.values) ...await loadPracticeItems(path),
    ];

PracticeItem _practiceItem(
  GrammarEngine engine,
  GrammarFile file,
  GrammarItem item,
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
