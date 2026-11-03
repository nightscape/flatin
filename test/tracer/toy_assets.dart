import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const toyDir = 'test/fixtures/toy_course';

/// The app's course asset paths and the toy file that answers each; null:
/// the toy course has no such file, so the asset is missing.
const toyAssets = {
  'lib/data/latin_nouns.yaml': '$toyDir/toy_words.yaml',
  'lib/data/latin_verbs.yaml': null,
  'lib/data/latin_vocab.yaml': null,
  'lib/data/german_nouns.yaml': null,
  'lib/data/german_verbs.yaml': null,
  'lib/data/agite_1.yaml': '$toyDir/toy_book_1.yaml',
  'lib/data/agite_2.yaml': '$toyDir/toy_book_2.yaml',
  'lib/data/sentences.yaml': '$toyDir/toy_sentences.yaml',
};

/// Makes the asset bundle answer the course paths of [toyAssets] with the
/// toy course; every other asset (translations, fonts, game rules) is the
/// app's own, read as the test binding reads it.
void injectToyCourse() {
  final appAssets = Platform.environment['UNIT_TEST_ASSETS']!;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        final file = toyAssets.containsKey(key)
            ? toyAssets[key]
            : '$appAssets/$key';
        if (file == null || !File(file).existsSync()) return null;
        return ByteData.sublistView(
          Uint8List.fromList(File(file).readAsBytesSync()),
        );
      });
}
