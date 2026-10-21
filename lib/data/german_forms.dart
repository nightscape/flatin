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

/// Renders a Latin verb form from `german_verbs.yaml`, for the Latin items
/// with a `de_verb`: the German key is the Latin key, cut to modus, tempus and
/// genus verbi for an infinitive or a participle.
class GrammarGermanForms implements GermanForms {
  GrammarGermanForms(String germanVerbsYaml, GrammarFile latinVerbs)
    : _engine = GrammarEngine(
        parseGrammarFiles({'lib/data/german_verbs.yaml': germanVerbsYaml}),
      ),
      germanVerbOf = {
        for (final item in latinVerbs.items)
          if (item.deVerb != null)
            '${latinVerbs.dataFileId}:${item.id}': item.deVerb!,
      } {
    for (final germanId in germanVerbOf.values) {
      _engine.of('german_verbs', germanId);
    }
  }

  final GrammarEngine _engine;

  /// Practice item id → id of its German verb.
  final Map<String, String> germanVerbOf;

  @override
  bool covers(PracticeItem item, FormKey key) =>
      _courseGroups.contains(key.split('.').first) &&
      _variants(item, key) != null;

  @override
  String render(PracticeItem item, FormKey key) => accepted(item, key).first;

  /// Every German text accepted for [key]; the first is the shown one (S9).
  List<String> accepted(PracticeItem item, FormKey key) {
    final germanId = germanVerbOf[item.id];
    if (germanId == null) throw ArgumentError('no German verb for ${item.id}');
    final germanKey = germanKeyOf(key);
    final variants = _variants(item, key);
    if (variants == null) {
      throw ArgumentError('$germanId has no German form $germanKey ($key)');
    }
    return variants;
  }

  static const _courseGroups = {'ind', 'konj', 'inf', 'part'};

  /// Null when [item] has no German verb or the verb lacks the form; [key]
  /// must be in a course group.
  List<String>? _variants(PracticeItem item, FormKey key) {
    final germanId = germanVerbOf[item.id];
    if (germanId == null) return null;
    return _engine
        .of('german_verbs', germanId)
        .forms[germanKeyOf(key)]
        ?.variants;
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
