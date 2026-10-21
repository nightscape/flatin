import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/exercise_choice.dart';
import '../data/practice_data.dart';
import '../data/topics.dart';
import 'curriculum_provider.dart';
import 'fsrs_provider.dart';
import 'locale_provider.dart';

part 'round_providers.g.dart';

/// The topics the course offers now, in course order.
@riverpod
Future<List<Topic>> topics(Ref ref) async {
  final byType = await ref.watch(practicableItemsByTypeProvider.future);
  final filter = await ref.watch(courseFilterProvider.future);
  final curriculum = await ref.watch(curriculumProvider.future);
  final language = await ref.watch(dataLanguageProvider.future);
  final nouns = await getFormMetadata(
    'lib/data/latin_nouns.yaml',
    language: language,
  );
  final all = topicsOf(
    [for (final items in byType.values) ...items],
    curriculum,
    nounTypeDisplays: nouns.displayByType,
  );
  return [
    for (final topic in all)
      if (offeredBundles(
        topic,
        unlockedBundles(filter, byType[topic.dataFileId]!),
      ).isNotEmpty)
        topic,
  ];
}
