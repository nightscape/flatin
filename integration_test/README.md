# Integration tests

`app_test.dart` runs the BDD scenarios in the real app through the
`integration_test` binding. The scenarios themselves live outside this
directory — see `CUCUMBER_TESTS.md` for the full setup.

## Structure

- `app_test.dart` — the runner; calls `runFeatures()` from
  `test/step_definitions/app_steps.pickled.dart`
- `run_5x_macos.sh` — runs the macOS suite five times and reports the failures;
  use it after touching a step definition
- scenarios: `test/features/*.feature`
- steps: `test/step_definitions/app_steps.dart`

## Running

```bash
flutter test integration_test/ -d macos
```

The same scenarios also run headless, without a device, through
`test/features_test.dart`.

## Screenshots

The `integration_test` screenshot channel exists only on Android and iOS, so
`I take a screenshot named ...` is a no-op on macOS and in the headless run.
On a mobile device the shots are collected into `fastlane/screenshots/` for the
Play Store upload lanes.
