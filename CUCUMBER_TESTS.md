# Cucumber Tests and Screenshots Setup

This project includes Cucumber-style integration tests with screenshot functionality for Fastlane.

## Overview

The integration tests are structured in two ways:

1. **Direct Integration Tests** (`integration_test/integration_test.dart`) - Uses Flutter's `integration_test` package directly
2. **Cucumber/Gherkin Tests** (`integration_test/test_driver/app_test.dart`) - Uses `flutter_gherkin` for BDD-style tests

## Feature Files

Cucumber feature files are located in `integration_test/features/`:
- `home_screen.feature` - Tests for the home screen
- `practice_screen.feature` - Tests for practice screens (nouns and verbs)
- `word_classification.feature` - Tests for word classification screen
- `settings_screen.feature` - Tests for settings screen

## Running Tests

### Option 1: Direct Integration Tests (Recommended)

```bash
flutter test integration_test/integration_test.dart
```

This runs the tests and takes screenshots automatically.

### Option 2: Using Fastlane

```bash
cd android
fastlane screenshots
```

This will:
1. Build the debug APK
2. Run integration tests
3. Collect screenshots in `fastlane/screenshots/`

### Option 3: Cucumber Tests (Advanced)

```bash
cd android
fastlane cucumber_tests
```

Note: Requires proper setup of `flutter_gherkin` package.

## Screenshots

Screenshots are automatically captured at key points:
- `home_screen` - Initial home screen view
- `home_screen_drawer` - Home screen with drawer open
- `settings_screen` - Settings screen
- `practice_noun_initial` - Noun practice screen (initial)
- `practice_noun_checked` - Noun practice screen (after checking)
- `practice_noun_rating` - Noun practice screen (with rating buttons)
- `practice_verb_initial` - Verb practice screen
- `word_classification_initial` - Word classification screen (initial)
- `word_classification_checked` - Word classification screen (after checking)

Screenshots are saved to `fastlane/screenshots/` and can be used by Fastlane for Play Store uploads.

## Dependencies

The following packages are required:
- `integration_test` (included in Flutter SDK)
- `flutter_gherkin` (for Cucumber/Gherkin tests)

Install dependencies:
```bash
flutter pub get
```

## Writing New Tests

### Adding a New Test Scenario

1. **For Direct Integration Tests**: Add a new `testWidgets` block in `integration_test/integration_test.dart`

2. **For Cucumber Tests**:
   - Add a scenario to the appropriate `.feature` file
   - Implement step definitions if needed in `integration_test/step_definitions/`

### Taking Screenshots

Use the `takeScreenshot` helper function:

```dart
await takeScreenshot(tester, 'screenshot_name');
```

## Fastlane Integration

Screenshots collected in `fastlane/screenshots/` are automatically used when uploading to the Play Store via Fastlane lanes (`internal`, `alpha`, `beta`, `release`).

## Troubleshooting

### Screenshots Not Appearing

- Ensure `fastlane/screenshots/` directory exists
- Check that tests are running on a device/emulator (screenshots require a visual environment)
- Verify integration_test package is properly configured

### Tests Failing

- Ensure the app builds successfully
- Check that all required dependencies are installed
- Verify that test data files are accessible

### Cucumber Tests Not Running

- Ensure `flutter_gherkin` is properly installed
- Check that step definitions match feature file steps
- Verify test driver configuration is correct

