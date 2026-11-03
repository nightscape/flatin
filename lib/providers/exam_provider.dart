import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/asset_text.dart';
import '../data/exam.dart';
import '../data/languages/language.dart';
import '../data/practice_data.dart';
import '../models/fsrs_card.dart';
import '../services/exam_storage.dart';
import '../services/fsrs_storage.dart';
import 'fsrs_provider.dart';
import 'locale_provider.dart';

part 'exam_provider.g.dart';

/// The language whose codes and rules the exam packs use.
@riverpod
Future<Language> examLanguage(Ref ref) async =>
    Language.parse(await loadAssetText(latinAsset));

/// The imported exam packs.
@riverpod
class ExamPacks extends _$ExamPacks {
  @override
  Future<List<Exam>> build() async =>
      ExamStorage.load(await ref.watch(examLanguageProvider.future));

  /// Throws [ExamRejected] and keeps the list when the pack breaks a rule.
  Future<void> import(String source) async {
    final language = await ref.read(examLanguageProvider.future);
    await ExamStorage.add(source, language);
    state = AsyncValue.data(await ExamStorage.load(language));
  }

  Future<void> delete(String id) async {
    await ExamStorage.delete(id);
    state = AsyncValue.data(
      await ExamStorage.load(await ref.read(examLanguageProvider.future)),
    );
  }
}

/// The app's words by lemma: the meaning in the UI language and the word
/// card ids, one per data file that lists the lemma.
@riverpod
Future<Map<String, ({String meaning, List<String> cardIds})>> examWords(
  Ref ref,
) async {
  final language = await ref.watch(dataLanguageProvider.future);
  final words = <String, ({String meaning, List<String> cardIds})>{};
  for (final item in await loadAllPracticeItems(language: language)) {
    final known = words[item.lemma];
    words[item.lemma] = (
      meaning: known?.meaning ?? item.translation,
      cardIds: [...?known?.cardIds, PracticeItemCard.generateItemId(item)],
    );
  }
  return words;
}

/// [cards] with each word card of [wordCardIds] due by the start of the day
/// after [now] at the latest; every other card and field stays.
Map<String, PracticeItemCard> queueHelpedWords(
  Map<String, PracticeItemCard> cards,
  Set<String> wordCardIds,
  DateTime now,
) {
  for (final id in wordCardIds) {
    assert(!id.startsWith('grammar:') && cards.containsKey(id), id);
  }
  final local = now.toLocal();
  final tomorrow = DateTime(local.year, local.month, local.day + 1).toUtc();
  return {
    for (final MapEntry(key: id, value: card) in cards.entries)
      id: wordCardIds.contains(id) && card.due.isAfter(tomorrow)
          ? card.copyWith(due: tomorrow)
          : card,
  };
}

/// Queues the word cards of [lemmas] and stores the cards; returns how many
/// lemmas have a word card. A lemma the app does not list is not queued.
Future<int> queueHelpedLemmas(WidgetRef ref, Set<String> lemmas) async {
  final words = await ref.read(examWordsProvider.future);
  final cards = await ref.read(fsrsCardsProvider.future);
  final known = lemmas.where(words.containsKey);
  final ids = {for (final lemma in known) ...words[lemma]!.cardIds};
  await FsrsStorage.saveCards(queueHelpedWords(cards, ids, DateTime.now()));
  ref.invalidate(fsrsCardsProvider);
  return known.length;
}
