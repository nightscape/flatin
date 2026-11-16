import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'features_test.dart' as features;
import 'support/store_picture.dart' show storeLocale;

/// The store pictures that the headless features run left where
/// `fastlane store_pictures` collects them.
List<String> storePicturesInRepoBuild(Directory repo) {
  final dir = Directory('${repo.path}/build/store_shots/$storeLocale');
  if (!dir.existsSync()) return [];
  return [
    for (final f in dir.listSync())
      if (f.uri.pathSegments.last.startsWith('store-')) f.path,
  ];
}

void main() {
  final repo = Directory(Directory.current.absolute.path);
  setUpAll(() {
    final dir = Directory('${repo.path}/build/store_shots/$storeLocale');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  tearDownAll(
    () => expect(
      storePicturesInRepoBuild(repo),
      hasLength(greaterThanOrEqualTo(2)),
      reason: 'fastlane store_pictures copies build/store_shots/<locale>',
    ),
  );
  features.main();
}
