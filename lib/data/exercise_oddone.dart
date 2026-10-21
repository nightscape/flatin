import 'dart:math';

import '../models/derivation.dart' show norm;
import '../models/exercise.dart';
import '../models/practice_item.dart';

/// Four forms of one word: three share the value of one feature, the fourth
/// differs in exactly that feature. The learner picks the fourth.
/// Produced here; read by the generic exercise screen and `attribute`.
class OddOneOutGenerator implements ExerciseGenerator {
  static const _majority = 3;

  /// Quartets drawn before the build gives up.
  static const maxDraws = 200;

  const OddOneOutGenerator();

  @override
  ExerciseKind get kind => ExerciseKind.irrlaeufer;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    final unlocked = ctx.unlocked;
    assert(unlocked.contains(bundle), 'the bundle $bundle is not unlocked');
    final inBundle = [
      for (final key in word.formOrder)
        if (bundleOf(word, key) == bundle) key,
    ];
    if (inBundle.length < _majority) {
      throw CannotBuild(
        '${word.id} has fewer than $_majority forms in $bundle',
      );
    }
    final unlockedKeys = [
      for (final key in word.formOrder)
        if (unlocked.contains(bundleOf(word, key))) key,
    ];
    final (majority, odd) =
        _draw(word, inBundle, unlockedKeys, rng) ??
        (throw CannotBuild(
          '${word.id} has no unambiguous odd form in $bundle '
          'after $maxDraws draws',
        ));
    FormOption option(FormKey key) => FormOption(
      text: word.forms[word.formOrder.indexOf(key)],
      formKey: key,
      lexemeId: word.id,
    );
    final right = option(odd);
    final options = [
      option(majority[0]),
      option(majority[1]),
      option(majority[2]),
      right,
    ]..shuffle(rng);
    return Exercise(
      wordCardId: word.id,
      grammarCardId: GrammarCardId(word.dataFileId, bundle),
      kind: kind,
      questionKey: 'exercise.oddone.question',
      answer: ChoiceAnswer(options, right),
    );
  }

  Map<String, String> _features(PracticeItem word, FormKey key) =>
      word.formLabels[word.formOrder.indexOf(key)].features;

  /// Draws up to [maxDraws] quartets: the three majority keys and the odd key.
  /// A quartet is [m0] and two more keys of [inBundle] that share a feature
  /// with it, plus [m0] with that feature changed.
  (List<FormKey>, FormKey)? _draw(
    PracticeItem word,
    List<FormKey> inBundle,
    List<FormKey> unlockedKeys,
    Random rng,
  ) {
    for (int draw = 0; draw < maxDraws; draw++) {
      final m0 = inBundle[rng.nextInt(inBundle.length)];
      final asked = _features(word, m0);
      final axes = asked.keys.toList();
      final axis = axes[rng.nextInt(axes.length)];
      final sharing = [
        for (final key in inBundle)
          if (key != m0 && _features(word, key)[axis] == asked[axis]) key,
      ];
      final odds = [
        for (final key in unlockedKeys)
          if (_differing(asked, _features(word, key)).length == 1 &&
              _features(word, key)[axis] != asked[axis])
            key,
      ];
      if (sharing.length < 2 || odds.isEmpty) continue;
      final i = rng.nextInt(sharing.length);
      var j = rng.nextInt(sharing.length - 1);
      if (j >= i) j++;
      final majority = [m0, sharing[i], sharing[j]];
      final odd = odds[rng.nextInt(odds.length)];
      if (_unambiguous(word, majority, odd)) return (majority, odd);
    }
    return null;
  }

  Iterable<String> _differing(Map<String, String> a, Map<String, String> b) =>
      {...a.keys, ...b.keys}.where((axis) => a[axis] != b[axis]);

  /// No spelling of the odd form is a spelling of a majority form, and no
  /// other form is the lone one on any feature.
  bool _unambiguous(PracticeItem word, List<FormKey> majority, FormKey odd) {
    final spellings = <String>{};
    for (final key in majority) {
      final accepted = word.acceptedForms[word.formOrder.indexOf(key)];
      final normed = accepted.map(norm).toSet();
      if (normed.any(spellings.contains)) return false;
      spellings.addAll(normed);
    }
    final oddAccepted = word.acceptedForms[word.formOrder.indexOf(odd)];
    if (oddAccepted.any((s) => spellings.contains(norm(s)))) return false;

    final quartet = [...majority, odd];
    final axes = {for (final key in quartet) ..._features(word, key).keys};
    for (final axis in axes) {
      for (final lone in quartet) {
        final others = quartet.where((k) => k != lone);
        final values = others.map((k) => _features(word, k)[axis]).toSet();
        final isLone =
            values.length == 1 && _features(word, lone)[axis] != values.single;
        if (isLone && lone != odd) return false;
      }
    }
    return true;
  }
}
