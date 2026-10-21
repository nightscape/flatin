import '../grammar/engine.dart';
import '../grammar/schema.dart';
import '../models/practice_item.dart';

/// The German text of one Latin form.
/// Implemented by the German form data; read by the generators.
abstract interface class GermanForms {
  /// Whether [render] has German text for the form [key] of [item].
  bool covers(PracticeItem item, FormKey key);

  String render(PracticeItem item, FormKey key);
}

/// Renders a Latin form from `german_verbs.yaml` for the Latin items with a
/// `de_verb`, and from `german_nouns.yaml` for those with a `de_noun`. A noun
/// form reads the German key that is its Latin key; a verb form reads the
/// Latin key cut to modus, tempus and genus verbi for an infinitive or a
/// participle.
class GrammarGermanForms implements GermanForms {
  GrammarGermanForms(
    String germanVerbsYaml,
    GrammarFile latinVerbs, {
    ({String yaml, GrammarFile latin})? nouns,
  }) : _engine = GrammarEngine(
         parseGrammarFiles({
           'lib/data/german_verbs.yaml': germanVerbsYaml,
           if (nouns != null) 'lib/data/german_nouns.yaml': nouns.yaml,
         }),
       ),
       germanVerbOf = _germanOf(latinVerbs, (item) => item.deVerb),
       germanNounOf = nouns == null
           ? const {}
           : _germanOf(nouns.latin, (item) => item.deNoun) {
    for (final germanId in germanVerbOf.values) {
      _engine.of('german_verbs', germanId);
    }
    for (final germanId in germanNounOf.values) {
      _engine.of('german_nouns', germanId);
    }
  }

  static Map<String, String> _germanOf(
    GrammarFile latin,
    String? Function(GrammarItem) germanId,
  ) => {
    for (final item in latin.items)
      if (germanId(item) != null)
        '${latin.dataFileId}:${item.id}': germanId(item)!,
  };

  final GrammarEngine _engine;

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

  /// Every German text accepted for [key]; the first is the shown one (S9).
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
      return _engine.of('german_nouns', nounId).forms[key]?.variants;
    }
    final verbId = germanVerbOf[item.id];
    if (verbId == null) return null;
    return _engine.of('german_verbs', verbId).forms[germanKeyOf(key)]?.variants;
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
}
