import 'package:flutter_gherkin/flutter_gherkin.dart';
import 'package:gherkin/gherkin.dart';
import 'package:integration_test/integration_test.dart';
import 'dart:io';

/// Hook that runs before all tests
class AppHooks extends FlutterTestConfiguration {
  @override
  Future<void> onBeforeRun(TestConfiguration config) async {
    // Ensure screenshots directory exists
    final screenshotsDir = Directory('fastlane/screenshots');
    if (!await screenshotsDir.exists()) {
      await screenshotsDir.create(recursive: true);
    }
  }
}

