import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart';
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/providers/course_provider.dart';
import 'package:latin_practice/providers/lesson_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_language.dart';
import 'tracer/toy_assets.dart';

/// Serves [served] like [injectToyCourse], but holds the asset [held] until
/// [gate] completes.
void _serveHolding(Map<String, String> served, String held, Future<void> gate) {
  final appAssets = Platform.environment['UNIT_TEST_ASSETS']!;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == held) await gate;
        if (served.containsKey(key)) {
          return ByteData.sublistView(
            Uint8List.fromList(utf8.encode(served[key]!)),
          );
        }
        final file = [
          if (key == coursesAsset) '$toyDir/courses.yaml',
          '$appAssets/$key',
          key,
        ].firstWhere((path) => File(path).existsSync(), orElse: () => '');
        if (file.isEmpty) return null;
        return ByteData.sublistView(
          Uint8List.fromList(File(file).readAsBytesSync()),
        );
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a switch while the items of the old course still load gives the new '
      'course its own items', () async {
    for (var seed = 0; seed < 10; seed++) {
      final r = Random(seed);
      final courses = drawnCourses(r, min: 2);
      final from = courses.first;
      final to = courses[1 + r.nextInt(courses.length - 1)];
      final gate = Completer<void>();
      resetPracticeData();
      _serveHolding(
        servedCourses(courses),
        'drawn/${from.id}/words.yaml',
        gate.future,
      );
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(retry: noRetry);
      addTearDown(c.dispose);
      expect(await c.read(activeCourseProvider.future), from.id);
      final oldLoad = loadAllPracticeItems();
      await Future<void>.delayed(Duration.zero);
      await c.read(activeCourseProvider.notifier).select(to.id);
      gate.complete();
      await oldLoad;
      final items = await c.read(practiceItemsProvider.future);
      expect(
        {for (final i in items) i.dataFileId},
        {to.dataFileId},
        reason: 'seed $seed: switch ${from.id} -> ${to.id} during a load',
      );
    }
  });
}
