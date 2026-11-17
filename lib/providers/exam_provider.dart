import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/exam.dart';
import '../data/languages/language.dart' show Language;
import '../data/practice_data.dart';
import '../data/token_lessons.dart';
import '../models/course.dart';
import '../models/form_label.dart' show Axes, GrammarAxis;
import '../models/fsrs_card.dart';
import '../services/exam_storage.dart';
import '../services/fsrs_storage.dart';
import 'course_provider.dart';
import 'curriculum_provider.dart';
import 'fsrs_provider.dart';
import 'lesson_provider.dart';
import 'locale_provider.dart';

part 'exam_provider.g.dart';

/// The language whose codes and rules the exam packs use.
@riverpod
Future<Language> examLanguage(Ref ref) => loadLanguage();

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

/// The axes of the course's grammar files that the language forms words
/// with (`form`), in the language of the UI; an axis id that several files
/// declare is taken from the first. These are the analysis keys that have a
/// dropdown, with the codes of the language's `analyse` only.
@riverpod
Future<Axes> examAxes(Ref ref) async {
  final course = await ref.watch(courseProvider.future);
  final language = await ref.watch(dataLanguageProvider.future);
  final examLanguage = await ref.watch(examLanguageProvider.future);
  final form = examLanguage.form;
  final byId = <String, GrammarAxis>{};
  for (final file in course.grammarFiles) {
    final grammar = await loadGrammarFile(file.id, language: language);
    for (final axis in grammar.axes.axes.where((a) => form.contains(a.id))) {
      final codes = {for (final c in examLanguage.analyse[axis.id]!) '$c'};
      byId.putIfAbsent(
        axis.id,
        () => GrammarAxis(
          id: axis.id,
          name: axis.name,
          values: [
            for (final v in axis.values)
              if (codes.contains(v.$1)) v,
          ],
          hiddenInLabel: axis.hiddenInLabel.intersection(codes),
        ),
      );
    }
  }
  final ids = byId.keys.toList();
  return Axes(
    axes: byId.values.toList(),
    head: ids,
    tail: const [],
    mergeAxis: ids.first,
  );
}

typedef ExamWord = ({
  String meaning,
  List<String> cardIds,
  List<WordFile> files,
});

/// The app's words by lemma: the meaning in the UI language, and the word
/// card id and data file, one per data file that lists the lemma.
@riverpod
Future<Map<String, ExamWord>> examWords(Ref ref) async {
  final language = await ref.watch(dataLanguageProvider.future);
  final words = <String, ExamWord>{};
  for (final item in await loadAllPracticeItems(language: language)) {
    final known = words[item.lemma];
    words[item.lemma] = (
      meaning: known?.meaning ?? item.translation,
      cardIds: [...?known?.cardIds, PracticeItemCard.generateItemId(item)],
      files: [...?known?.files, (dataFileId: item.dataFileId, type: item.type)],
    );
  }
  return words;
}

/// Where the course teaches the words of the exam sheet.
@riverpod
Future<LessonLookup> lessonLookup(Ref ref) async {
  final words = await ref.watch(examWordsProvider.future);
  return LessonLookup(
    await ref.watch(examLanguageProvider.future),
    await ref.watch(lessonDataProvider.future),
    await ref.watch(curriculumProvider.future),
    {for (final MapEntry(:key, :value) in words.entries) key: value.files},
  );
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
