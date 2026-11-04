import '../grammar/engine.dart';
import '../grammar/schema.dart';
import '../models/practice_item.dart';

/// The German text of one Latin form.
/// Implemented by the German form data; read by the generators.
abstract interface class GermanForms {
  /// Whether [render] has German text for the form [key] of [item].
  bool covers(PracticeItem item, FormKey key);

  String render(PracticeItem item, FormKey key);

  /// Every German text accepted for [key]; the first is [render]'s (S9).
  List<String> accepted(PracticeItem item, FormKey key);
}

/// Renders a Latin form from the verb gloss file for the Latin items with a
/// `de_verb`, and from the noun gloss file for those with a `de_noun`. A noun
/// form reads the German key that is its Latin key; a verb form reads the
/// Latin key cut to modus, tempus and genus verbi for an infinitive or a
/// participle.
class GrammarGermanForms implements GermanForms {
  GrammarGermanForms(
    String germanVerbsYaml,
    GrammarFile latinVerbs, {
    ({String yaml, GrammarFile latin})? nouns,
  }) : this._(
         parseGrammarFiles({
           _verbSource: germanVerbsYaml,
           if (nouns != null) _nounSource: nouns.yaml,
         }),
         latinVerbs,
         nouns?.latin,
       );

  GrammarGermanForms._(
    List<GrammarFile> files,
    GrammarFile latinVerbs,
    GrammarFile? latinNouns,
  ) : _engine = GrammarEngine(files),
      _verbsId = _idOf(files, _verbSource),
      _nounsId = latinNouns == null ? null : _idOf(files, _nounSource),
      germanVerbOf = _germanOf(latinVerbs, (item) => item.deVerb),
      germanNounOf = latinNouns == null
          ? const {}
          : _germanOf(latinNouns, (item) => item.deNoun) {
    for (final germanId in germanVerbOf.values) {
      _engine.of(_verbsId, germanId);
    }
    for (final germanId in germanNounOf.values) {
      _engine.of(_nounsId!, germanId);
    }
  }

  static const _verbSource = 'verb gloss file';
  static const _nounSource = 'noun gloss file';

  static String _idOf(List<GrammarFile> files, String source) =>
      files.singleWhere((f) => f.path == source).dataFileId;

  static Map<String, String> _germanOf(
    GrammarFile latin,
    String? Function(GrammarItem) germanId,
  ) => {
    for (final item in latin.items)
      if (germanId(item) != null)
        '${latin.dataFileId}:${item.id}': germanId(item)!,
  };

  final GrammarEngine _engine;
  final String _verbsId;
  final String? _nounsId;

  /// Practice item id → id of its German verb.
  final Map<String, String> germanVerbOf;

  /// Practice item id → id of its German noun.
  final Map<String, String> germanNounOf;

  @override
  bool covers(PracticeItem item, FormKey key) =>
      (germanNounOf.containsKey(item.id) ||
          _courseGroups.contains(key.split('.').first)) &&
      _variants(item, key) != null;

  @override
  String render(PracticeItem item, FormKey key) => accepted(item, key).first;

  @override
  List<String> accepted(PracticeItem item, FormKey key) {
    final variants = _variants(item, key);
    if (variants == null) {
      throw ArgumentError('${item.id} has no German form $key');
    }
    return variants;
  }

  static const _courseGroups = {'ind', 'konj', 'inf', 'part'};

  /// Null when [item] has no German word or the word lacks the form; a verb
  /// [key] must be in a course group.
  List<String>? _variants(PracticeItem item, FormKey key) {
    final nounId = germanNounOf[item.id];
    if (nounId != null) {
      return _engine.of(_nounsId!, nounId).forms[key]?.variants;
    }
    final verbId = germanVerbOf[item.id];
    if (verbId == null) return null;
    return _engine.of(_verbsId, verbId).forms[germanKeyOf(key)]?.variants;
  }

  static FormKey germanKeyOf(FormKey latinKey) {
    final codes = latinKey.split('.');
    return switch (codes.first) {
      'ind' || 'konj' => latinKey,
      'inf' || 'part' => codes.take(3).join('.'),
      _ => throw ArgumentError('the course gives no German form for $latinKey'),
    };
  }
}

/// The forms for a UI language without form texts: no form is covered, so
/// the kinds that show form texts throw [CannotBuild].
class NoForms implements GermanForms {
  const NoForms();

  @override
  bool covers(PracticeItem item, FormKey key) => false;

  @override
  String render(PracticeItem item, FormKey key) =>
      throw StateError('NoForms has no text for ${item.id} $key');

  @override
  List<String> accepted(PracticeItem item, FormKey key) =>
      throw StateError('NoForms has no text for ${item.id} $key');
}

/// Renders `<lemma>@<key>`, so every form has its own German text.
/// Stands in for the German form data in tests of generators and screens.
class FakeGermanForms implements GermanForms {
  const FakeGermanForms({this.coversAll = true});

  final bool coversAll;

  @override
  bool covers(PracticeItem item, FormKey key) => coversAll;

  @override
  String render(PracticeItem item, FormKey key) => '${item.lemma}@$key';

  @override
  List<String> accepted(PracticeItem item, FormKey key) => [render(item, key)];
}
