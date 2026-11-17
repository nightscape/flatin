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

/// The language of the active course: its codes, spelling folds and rules.
@riverpod
Future<Language> courseLanguage(Ref ref) async {
  await ref.watch(courseProvider.future);
  return loadLanguage();
}

/// The language whose codes and rules the exam packs of the active course use.
@riverpod
Future<Language> examLanguage(Ref ref) =>
    ref.watch(courseLanguageProvider.future);

/// The imported exam packs of the active course.
@riverpod
class ExamPacks extends _$ExamPacks {
  @override
  Future<List<Exam>> build() async => ExamStorage.load(
    await ref.watch(examLanguageProvider.future),
    await ref.watch(courseScopeProvider.future),
  );

  /// Throws [ExamRejected] and keeps the list when the pack breaks a rule or
  /// belongs to another course.
  Future<void> import(String source) async {
    final language = await ref.read(examLanguageProvider.future);
    final scope = await ref.read(courseScopeProvider.future);
    await ExamStorage.add(source, language, scope);
    state = AsyncValue.data(await ExamStorage.load(language, scope));
  }

  Future<void> delete(String id) async {
    final scope = await ref.read(courseScopeProvider.future);
    await ExamStorage.delete(id, scope);
    state = AsyncValue.data(
      await ExamStorage.load(
        await ref.read(examLanguageProvider.future),
        scope,
      ),
    );
  }
}

/// By data file id, each grammar file's axes that the language forms words
/// with (`form`), in the language of the UI and in the order of that file,
/// with the codes of the language's `analyse` only: the analysis keys that
/// have a dropdown. A file with no such axis is left out.
@riverpod
Future<Map<String, Axes>> examAxes(Ref ref) async {
  final course = await ref.watch(courseProvider.future);
  final language = await ref.watch(dataLanguageProvider.future);
  final examLanguage = await ref.watch(examLanguageProvider.future);
  final result = <String, Axes>{};
  for (final file in course.grammarFiles) {
    final grammar = await loadGrammarFile(file.id, language: language);
    final kept = <GrammarAxis>[];
    for (final axis in grammar.axes.axes.where(
      (a) => examLanguage.form.contains(a.id),
    )) {
      final codes = {for (final c in examLanguage.analyse[axis.id]!) '$c'};
      final values = [
        for (final v in axis.values)
          if (codes.contains(v.$1)) v,
      ];
      if (values.isEmpty) continue;
      kept.add(
        GrammarAxis(
          id: axis.id,
          name: axis.name,
          values: values,
          hiddenInLabel: axis.hiddenInLabel.intersection(codes),
        ),
      );
    }
    if (kept.isEmpty) continue;
    result[file.id] = Axes(
      axes: kept,
      head: [for (final a in kept) a.id],
      tail: const [],
      mergeAxis: kept.first.id,
    );
  }
  return result;
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

/// Where the course teaches its words.
@riverpod
Future<LessonLookup> lessonLookup(Ref ref) async {
  final words = await ref.watch(examWordsProvider.future);
  return LessonLookup(
    await ref.watch(courseLanguageProvider.future),
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
