import 'package:flutter_gherkin/flutter_gherkin.dart';
import 'package:gherkin/gherkin.dart';
import 'package:integration_test/integration_test.dart';
import 'dart:io';

/// Step definition for taking screenshots
StepDefinitionGeneric takeScreenshotStep() {
  return then(
    RegExp(r'I take a screenshot named {string}'),
    (context) async {
      final name = context.read<String>();
      final integrationTestBinding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

      // Wait for the app to settle
      await context.world.appDriver.waitForAppToSettle();

      // Take screenshot
      await integrationTestBinding.takeScreenshot(name);

      // Ensure fastlane screenshots directory exists
      final screenshotsDir = Directory('fastlane/screenshots');
      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }

      // Screenshots are saved in the device-specific directory
      // We'll handle copying in the Fastfile
    },
  );
}

