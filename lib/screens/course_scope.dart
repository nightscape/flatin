import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_filter.dart';
import '../models/practice_item.dart';
import '../providers/curriculum_provider.dart';
import '../providers/lesson_provider.dart';

/// Builds [builder] once the course filter and the practice items are loaded.
/// A reload keeps the old content on screen, so a slider survives its own
/// drag.
class CourseScope extends ConsumerWidget {
  const CourseScope({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    CourseFilter filter,
    List<PracticeItem> items,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(courseFilterProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => loadErrorText(context, error),
          data: (filter) => ref
              .watch(practiceItemsProvider)
              .when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => loadErrorText(context, error),
                data: (items) => builder(context, filter, items),
              ),
        );
  }
}

Widget loadErrorText(BuildContext context, Object error) => Text(
  FlutterI18n.translate(
    context,
    'settings.error',
    translationParams: {'error': error.toString()},
  ),
);
