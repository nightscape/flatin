import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/asset_text.dart';

/// `rootBundle.loadString` would hand this asset to a background isolate,
/// which fake time never lets answer, so the test would time out instead.
void main() {
  testWidgets('an asset over 50 KiB loads inside fake time', (tester) async {
    const path = 'lib/data/latin_verbs.yaml';
    final text = await loadAssetText(path);
    expect(utf8.encode(text).length, greaterThan(50 * 1024), reason: path);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
