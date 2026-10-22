/// The (word, bundle) pairs of a round, before any exercise is built.
library;

import '../models/course_filter.dart';
import '../models/exercise.dart';
import '../models/fsrs_card.dart';
import '../models/practice_item.dart';
import 'selection.dart';
import 'topics.dart';

typedef RoundPair = ({PracticeItem word, GrammarBundle bundle});

const roundLength = 10;

/// The arguments of [selectPair] apart from `taken`.
typedef SelectionInput = ({
  Map<String, PracticeItemCard> cards,
  List<PracticeItem> items,
  CourseFilter filter,
  Retrievability retrievability,
  DateTime now,
});

SelectedPair? _select(
  SelectionInput input,
  BundleIndex index,
  Set<String> taken,
) => selectPair(
  index: index,
  cards: input.cards,
  items: input.items,
  filter: input.filter,
  retrievability: input.retrievability,
  now: input.now,
  taken: taken,
);

/// Blocked: the [offered] bundles of [topic] in turn, weakest bundle card
/// first; per slot the strongest word that has the bundle and is not used yet
/// in this round; when every such word is used, the bundle's words repeat in
/// the same order.
List<RoundPair> planBlocked(
  Topic topic,
  Set<GrammarBundle> offered,
  SelectionInput input,
) {
  assert(offered.isNotEmpty && topic.bundles.toSet().containsAll(offered));
  final index = BundleIndex(input.items, input.filter);
  double r(String id) => input.retrievability(input.cards[id]!);

  final bundles = [
    for (final b in topic.bundles)
      if (offered.contains(b)) b,
  ];
  bundles.sort((a, b) {
    final byR = r(
      GrammarCardId(topic.dataFileId, a),
    ).compareTo(r(GrammarCardId(topic.dataFileId, b)));
    return byR != 0
        ? byR
        : topic.bundles.indexOf(a).compareTo(topic.bundles.indexOf(b));
  });

  final wordsOf = {
    for (final bundle in bundles)
      bundle:
          [
            ...index
                .wordsOfBundle[GrammarCardId(topic.dataFileId, bundle)]!
                .words,
          ]..sort((a, b) {
            final idA = PracticeItemCard.generateItemId(a);
            final idB = PracticeItemCard.generateItemId(b);
            final byR = r(idB).compareTo(r(idA));
            if (byR != 0) return byR;
            final byLesson = index.lessonOf[idA]!.compareTo(
              index.lessonOf[idB]!,
            );
            return byLesson != 0 ? byLesson : idA.compareTo(idB);
          }),
  };

  final used = <PracticeItem>{};
  final repeats = <GrammarBundle, int>{};
  return [
    for (var i = 0; i < roundLength; i++)
      () {
        final bundle = bundles[i % bundles.length];
        final words = wordsOf[bundle]!;
        final fresh = words.where((w) => !used.contains(w)).firstOrNull;
        final word =
            fresh ??
            words[repeats.update(bundle, (n) => n + 1, ifAbsent: () => 0) %
                words.length];
        used.add(word);
        return (word: word, bundle: bundle);
      }(),
  ];
}

/// Mixed: repeated [selectPair] with the anchors and words so far and every
/// grammar card without a review taken; then reordered so that two neighbours
/// share no topic where that is possible.
List<RoundPair> planMixed(SelectionInput input, List<Topic> topics) {
  final taken = {
    for (final card in input.cards.values)
      if (card.itemId.startsWith('grammar:') && card.lastReview == null)
        card.itemId,
  };
  final index = BundleIndex(input.items, input.filter);
  final pairs = <RoundPair>[];
  while (pairs.length < roundLength) {
    final pair = _select(input, index, taken);
    if (pair == null) break;
    pairs.add((word: pair.word, bundle: pair.bundle));
    taken.add(PracticeItemCard.generateItemId(pair.word));
    if (pair.anchorIsGrammar) taken.add(pair.grammarCardId);
  }

  final topicOf = {
    for (final topic in topics)
      for (final bundle in topic.bundles)
        GrammarCardId(topic.dataFileId, bundle): topic.id,
  };
  return spreadTopics(
    pairs,
    (p) => topicOf[GrammarCardId(p.word.dataFileId, p.bundle)]!,
  );
}

/// Greedy: next comes a pair whose topic differs from the last one, from the
/// topic with the most pairs left; earlier pairs win ties.
List<RoundPair> spreadTopics(
  List<RoundPair> pairs,
  String Function(RoundPair) topicOf,
) {
  final rest = [...pairs];
  final spread = <RoundPair>[];
  while (rest.isNotEmpty) {
    final left = <String, int>{};
    for (final p in rest) {
      left.update(topicOf(p), (n) => n + 1, ifAbsent: () => 1);
    }
    final last = spread.isEmpty ? null : topicOf(spread.last);
    final fits = rest.where((p) => topicOf(p) != last);
    final next = fits.isEmpty
        ? rest.first
        : fits.reduce((a, b) => left[topicOf(b)]! > left[topicOf(a)]! ? b : a);
    rest.remove(next);
    spread.add(next);
  }
  return spread;
}
