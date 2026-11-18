import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart';
import 'package:latin_practice/models/course.dart' show loadLanguage;
import 'package:latin_practice/providers/course_provider.dart';
import 'package:latin_practice/providers/exam_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/lookup_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_language.dart';
import 'tracer/toy_assets.dart';

base class _BuildCounter extends ProviderObserver {
  int builds = 0;

  void _count(ProviderObserverContext context, Object? value) {
    if (context.provider == formIndexProvider &&
        value is AsyncValue &&
        value.isLoading) {
      builds++;
    }
  }

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) =>
      _count(context, value);

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) => _count(context, newValue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the form index is built once per course load, however often it is '
    'opened, and after a switch it holds the items of the new course',
    () async {
      for (var seed = 0; seed < 12; seed++) {
        final r = Random(seed);
        final courses = drawnCourses(r, min: 2);
        resetPracticeData();
        injectToyCourse(served: servedCourses(courses));
        SharedPreferences.setMockInitialValues({});
        final counter = _BuildCounter();
        Language? language;
        final c = ProviderContainer(
          retry: noRetry,
          observers: [counter],
          overrides: [
            dataLanguageProvider.overrideWith((ref) => 'de'),
            if (seed.isOdd)
              courseLanguageProvider.overrideWith(
                (ref) async => language ??= await loadLanguage(),
              ),
          ],
        );
        addTearDown(c.dispose);
        var active = courses.first;
        var stale = true;
        var expectedBuilds = 0;
        final log = <String>[];

        for (var step = 0; step < 10; step++) {
          if (r.nextBool()) {
            final other = courses.where((k) => k.id != active.id).toList();
            active = other[r.nextInt(other.length)];
            log.add('switch ${active.id}');
            await c.read(activeCourseProvider.notifier).select(active.id);
            stale = true;
          } else {
            log.add('open');
            final open = c.listen(formIndexProvider, (_, _) {});
            final index = await c.read(formIndexProvider.future);
            open.close();
            await Future<void>.delayed(Duration.zero);
            if (stale) expectedBuilds++;
            stale = false;
            final items = await loadAllPracticeItems(language: 'de');
            final readings = index.find(items.first.forms.first);
            expect(
              readings.map((x) => x.file.dataFileId).toSet(),
              {active.dataFileId},
              reason: 'seed $seed, ${log.join(', ')}',
            );
          }
          expect(
            counter.builds,
            expectedBuilds,
            reason: 'seed $seed, ${log.join(', ')}',
          );
        }
      }
    },
  );
}
