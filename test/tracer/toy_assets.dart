import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/course.dart';

const toyDir = 'test/fixtures/toy_course';

/// The toy course, read as the app reads the one course of [coursesAsset].
final toyCourse = Course.parse(
  '$toyDir/course.yaml',
  File('$toyDir/course.yaml').readAsStringSync(),
);

/// Makes the asset bundle answer [coursesAsset] with the list of the toy
/// course; every other asset is the app's own, read as the test binding reads
/// it, or else the repo file the toy manifest names.
void injectToyCourse() {
  final appAssets = Platform.environment['UNIT_TEST_ASSETS']!;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
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
