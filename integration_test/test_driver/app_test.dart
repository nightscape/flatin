import 'package:flutter_gherkin/flutter_gherkin.dart';
import 'package:gherkin/gherkin.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latin_practice/main.dart' as app;
import '../step_definitions/navigation_steps.dart';
import '../step_definitions/assertion_steps.dart';
import '../step_definitions/interaction_steps.dart';
import '../step_definitions/screenshot_steps.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Configure Gherkin
  final config = FlutterTestConfiguration()
    ..features = [
      RegExp(r'integration_test/features/.*\.feature'),
    ]
    ..stepDefinitions = [
      givenAppIsRunning(),
      whenOnHomeScreen(),
      whenOpenDrawer(),
      whenTapOnText(),
      whenTapOnButton(),
      thenShouldSeeText(),
      thenShouldSeeTextInAppBar(),
      thenShouldSeeButtonWithText(),
      thenShouldSeeTextInDrawer(),
      thenShouldSeePracticeScreen(),
      thenShouldSeeInputFields(),
      thenShouldSeeValidationResults(),
      thenShouldSeeRatingButtons(),
      thenShouldSeeWordClassification(),
      thenShouldSeeWordDisplayed(),
      thenShouldSeeClassificationDropdowns(),
      thenShouldSeeSettingsSections(),
      thenShouldSeeCheckboxes(),
      thenCheckboxStateChanged(),
      thenShouldSeeValidationFeedback(),
      whenEnterAnswers(),
      whenWaitForPracticeScreen(),
      whenWaitForRatingButtons(),
      whenWaitForWord(),
      whenSelectClassificationOptions(),
      whenWaitForSettings(),
      whenToggleCheckbox(),
      takeScreenshotStep(),
    ]
    ..customStepParameterDefinitions = []
    ..reporters = [
      StdoutReporter(MessageLevel.error),
      ProgressReporter(),
      TestRunSummaryReporter(),
    ]
    ..order = ExecutionOrder.sequential
    ..defaultTimeout = const Duration(seconds: 30);

  // Run the app
  app.main();

  // Wait for app to settle
  await binding.waitForFirstFrame();

  // Run Gherkin tests
  await GherkinRunner().execute(config);
}

