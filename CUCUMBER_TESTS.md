# Cucumber tests

The BDD scenarios are written in Gherkin and run through `pickled_cucumber`.

## Layout

- `test/features/` — the scenarios, one `.feature` file per screen:
  `home_screen.feature`, `practice_screen.feature`,
  `word_classification.feature`, `settings_screen.feature`
- `test/step_definitions/app_steps.dart` — the step definitions, annotated with
  `@Given` / `@When` / `@Then`
- `test/step_definitions/app_steps.pickled.dart` — generated from the two
  above; never edit it by hand
- `test/features_test.dart` — headless runner
- `integration_test/app_test.dart` — runner in the real app

## Running

```bash
flutter test test/features_test.dart      # headless, no device
flutter test integration_test/ -d macos   # in the real app
```

Both runners execute the same scenarios. `integration_test/run_5x_macos.sh`
repeats the macOS run five times; use it after touching a step definition,
because a flaky step shows up only over several runs.

## Changing scenarios or steps

After editing a `.feature` file or `app_steps.dart`, regenerate the runner:

```bash
dart run build_runner build --delete-conflicting-outputs
```

A step must assert something. A step that only calls `pumpAndSettle()`, or that
acts only when a finder is non-empty, passes even when the screen it describes
never appeared.

## Screenshots

`I take a screenshot named "..."` writes a shot only on Android and iOS, where
the `integration_test` screenshot channel exists; on macOS and in the headless
run the step returns at once. The Fastlane lanes in `android/fastlane/Fastfile`
collect the shots from `fastlane/screenshots/` for the Play Store upload.
