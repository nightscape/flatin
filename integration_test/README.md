# Integration Tests with Screenshots

This directory contains Cucumber-style integration tests for the Latin Practice app, along with screenshot functionality for Fastlane.

## Structure

- `features/` - Gherkin feature files describing test scenarios
- `step_definitions/` - Step definitions for Cucumber tests (using flutter_gherkin)
- `test_driver/` - Alternative test driver using flutter_gherkin
- `app_test.dart` - Main integration test file using integration_test directly

## Running Tests

### Option 1: Direct Integration Tests (Recommended)

Run the integration tests directly:

```bash
flutter test integration_test/app_test.dart
```

This will:
- Run all test scenarios
- Take screenshots at key points
- Save screenshots to `fastlane/screenshots/`

### Option 2: Using Fastlane

Run tests and collect screenshots via Fastlane:

```bash
cd android
fastlane screenshots
```

This will:
- Build the debug APK
- Run integration tests
- Collect screenshots in `fastlane/screenshots/`

### Option 3: Cucumber Tests (Advanced)

If you want to use the full Cucumber/Gherkin setup:

```bash
cd android
fastlane cucumber_tests
```

Note: This requires proper setup of flutter_gherkin and may need additional configuration.

## Screenshots

Screenshots are automatically taken at key points in the tests:
- `home_screen` - Initial home screen
- `home_screen_drawer` - Home screen with drawer open
- `settings_screen` - Settings screen
- `practice_noun_initial` - Noun practice screen (initial state)
- `practice_noun_checked` - Noun practice screen (after checking answers)
- `practice_noun_rating` - Noun practice screen (with rating buttons)
- `practice_verb_initial` - Verb practice screen
- `word_classification_initial` - Word classification screen (initial state)
- `word_classification_checked` - Word classification screen (after checking)

Screenshots are saved to `fastlane/screenshots/` and can be used by Fastlane for Play Store uploads.

## Writing New Tests

To add new test scenarios:

1. Add a new test in `app_test.dart` following the existing pattern
2. Optionally add a corresponding feature file in `features/`
3. Use `takeScreenshot(tester, 'screenshot_name')` to capture screenshots

## Requirements

- Flutter SDK
- A connected device or emulator for running tests
- Fastlane (for automated screenshot collection)

