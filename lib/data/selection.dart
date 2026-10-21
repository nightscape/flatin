import 'dart:math';

import '../models/course_filter.dart';
import '../models/exercise.dart';
import '../models/fsrs_card.dart';
import '../models/practice_item.dart';

/// The retrievability R of a card, 0..1.
typedef Retrievability = double Function(PracticeItemCard card);

/// The word and the bundle of the next exercise.
/// Produced by [selectPair]; read by the generators.
final class SelectedPair {
  final PracticeItem word;
  final GrammarBundle bundle;

  /// Whether the grammar card, not the word card, was the due card with the
  /// lowest R.
  final bool anchorIsGrammar;

  const SelectedPair(this.word, this.bundle, {required this.anchorIsGrammar});

  GrammarCardId get grammarCardId => GrammarCardId(word.dataFileId, bundle);
}

/// The next exercise's word and bundle, or null when no card is due.
///
/// The anchor is the due card, word or grammar, with the lowest R among those
/// that have a review. Only when none is due, the anchor is a new card: the
/// one whose lesson comes first in the course; on equal lessons the data file
/// with fewer reviewed grammar cards, then the smaller card id. The partner is the
/// card of the other kind with the highest R among those that match the
/// anchor: the bundles the anchor word has, or the words that have the anchor
/// bundle; on equal R the earlier lesson, then the smaller card id. Only words
/// and bundles the course offers take part, so a new card is due once its
/// lesson is in range. Ties among reviewed anchors go to the earlier due date,
/// then to the smaller card id.
///
/// [cards] holds a card for every word and bundle of [items].
SelectedPair? selectPair({
  required Map<String, PracticeItemCard> cards,
  required List<PracticeItem> items,
  required CourseFilter filter,
  required Retrievability retrievability,
  required DateTime now,
}) {
  final bundlesOfWord = <PracticeItem, Set<GrammarBundle>>{};
  final wordsOfBundle =
      <GrammarCardId, ({GrammarBundle bundle, List<PracticeItem> words})>{};
  final lessonOf = <String, int>{};
  final fileOf = <String, String>{};
  void teach(String cardId, String dataFileId, int lesson) {
    fileOf[cardId] = dataFileId;
    final known = lessonOf[cardId];
    if (known == null || lesson < known) lessonOf[cardId] = lesson;
  }

  for (final word in items.where(filter.reachesPractice)) {
    teach(
      PracticeItemCard.generateItemId(word),
      word.dataFileId,
      filter.lessons.lessonNumberOf(word),
    );
    final typeLesson = filter.curriculum.typeLesson(word.dataFileId, word.type);
    for (final label in word.formLabels) {
      if (!filter.formPracticed(word.dataFileId, label)) continue;
      final formLesson = filter.curriculum.formLesson(
        word.dataFileId,
        label.key,
      );
      teach(
        GrammarCardId.of(word, label.key),
        word.dataFileId,
        max(typeLesson, formLesson),
      );
    }
    final bundles = {
      for (final label in word.formLabels)
        if (filter.formPracticed(word.dataFileId, label))
          bundleOf(word, label.key),
    };
    bundlesOfWord[word] = bundles;
    for (final bundle in bundles) {
      wordsOfBundle
          .putIfAbsent(
            GrammarCardId(word.dataFileId, bundle),
            () => (bundle: bundle, words: <PracticeItem>[]),
          )
          .words
          .add(word);
    }
  }

  PracticeItemCard cardOf(String id) =>
      cards[id] ?? (throw StateError('no card "$id"'));

  bool isDue(PracticeItemCard card) => !card.due.isAfter(now);

  int byWeakest(PracticeItemCard a, PracticeItemCard b) {
    final byR = retrievability(a).compareTo(retrievability(b));
    if (byR != 0) return byR;
    final byDue = a.due.compareTo(b.due);
    return byDue != 0 ? byDue : a.itemId.compareTo(b.itemId);
  }

  int byStrongest(PracticeItemCard a, PracticeItemCard b) {
    final byR = retrievability(b).compareTo(retrievability(a));
    if (byR != 0) return byR;
    final byLesson = lessonOf[a.itemId]!.compareTo(lessonOf[b.itemId]!);
    return byLesson != 0 ? byLesson : a.itemId.compareTo(b.itemId);
  }

  final wordCardOf = {
    for (final word in bundlesOfWord.keys)
      word: cardOf(PracticeItemCard.generateItemId(word)),
  };
  final all = [
    for (final card in [
      ...wordCardOf.values,
      ...wordsOfBundle.keys.map(cardOf),
    ])
      if (isDue(card)) card,
  ];
  if (all.isEmpty) return null;

  final reviewedIn = <String, int>{};
  for (final id in fileOf.keys) {
    if (id.startsWith('grammar:') && cardOf(id).lastReview != null) {
      reviewedIn.update(fileOf[id]!, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  int inCourseOrder(PracticeItemCard a, PracticeItemCard b) {
    final byLesson = lessonOf[a.itemId]!.compareTo(lessonOf[b.itemId]!);
    if (byLesson != 0) return byLesson;
    final byReviewed = (reviewedIn[fileOf[a.itemId]] ?? 0).compareTo(
      reviewedIn[fileOf[b.itemId]] ?? 0,
    );
    return byReviewed != 0 ? byReviewed : a.itemId.compareTo(b.itemId);
  }

  final reviewedDue = all.where((c) => c.lastReview != null);
  final anchor = reviewedDue.isNotEmpty
      ? reviewedDue.reduce((a, b) => byWeakest(a, b) <= 0 ? a : b)
      : all.reduce((a, b) => inCourseOrder(a, b) <= 0 ? a : b);

  T strongest<T>(
    Iterable<T> candidates,
    PracticeItemCard Function(T) cardFor,
  ) => candidates.reduce(
    (a, b) => byStrongest(cardFor(a), cardFor(b)) <= 0 ? a : b,
  );

  final anchorBundle = wordsOfBundle[anchor.itemId];
  if (anchorBundle != null) {
    final word = strongest(anchorBundle.words, (w) => wordCardOf[w]!);
    return SelectedPair(word, anchorBundle.bundle, anchorIsGrammar: true);
  }

  final word = wordCardOf.keys.singleWhere(
    (w) => wordCardOf[w]!.itemId == anchor.itemId,
  );
  final bundle = strongest(
    bundlesOfWord[word]!,
    (b) => cardOf(GrammarCardId(word.dataFileId, b)),
  );
  return SelectedPair(word, bundle, anchorIsGrammar: false);
}
