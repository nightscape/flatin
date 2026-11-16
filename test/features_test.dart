import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/app_fonts.dart';
import 'support/repo_dir.dart';
import 'step_definitions/app_steps.pickled.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  // No repo-relative path resolves, as on the device.
  final repo = Directory(repoDir);
  setUpAll(
    () => Directory.current = Directory.systemTemp.createTempSync('no_repo'),
  );
  tearDownAll(() => Directory.current = repo);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  runFeatures();
}
