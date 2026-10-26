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

## Store pictures

`test/features/store_bilder.feature` makes the Play Store phone pictures with
the step `the screen looks like "store-NNNN-<slug>.png"`. The step renders the
screen at 1080 x 1920 with the real fonts (`test/support/app_fonts.dart`) and
writes it to `build/store_shots/<locale>/`; `build/` is git-ignored, so no
picture enters the history. Nothing is compared yet.

- Numbers have 4 digits and gaps of 100 (`store-1100`, `store-1200`); the
  order of the store pictures comes only from the number.
  `test/store_picture_names_test.dart` fails on a duplicate number.
- One run per locale:
  `flutter test test/features_test.dart --plain-name "Store pictures" --dart-define=STORE_LOCALE=en-US`
  (default `de-DE`). It runs headless, no device needed.
- A release makes the pictures with `cd android && bundle exec fastlane
  store_pictures`: it runs both locales and copies the `store-*.png` files in
  sorted order into `android/fastlane/metadata/android/<locale>/images/phoneScreenshots/`.
  Run it in the release CI job before `upload_to_play_store`; do not commit
  the copies. `deploy.yml` does not call it yet.
- Comparing pictures between macOS and Linux fonts is a later card.

## Step pictures

`--dart-define=STEP_SHOTS=true` saves one picture after every Cucumber step,
so a run reads as a visual flow through the app. Off by default.

```
flutter test test/features_test.dart --dart-define=STEP_SHOTS=true
```

- Folder: `build/step_shots/<run timestamp>/`, flat files
  `<counter>-<feature>-<scenario>-<step>.png`. The counter has 4 digits and
  runs over the whole run, so `ls` lists the steps in execution order. Slugs
  are lowercase, umlauts become `ae oe ue ss`, other characters become `-`,
  each slug has at most 40 characters. A failed step has the suffix `-FAILED`.
  `test/step_shots_names_test.dart` tests the rule.
- The picture has the size of the test window. A step that runs before the
  app exists (for example `Given I have 1250 coins`) gets a blank picture.
- pickled_cucumber has no step hook. `tool/step_shots_builder.dart` replaces
  its generator in `build.yaml` and wraps every generated step call in
  `step(...)` from `test/support/step_shots.dart`. After a change to this
  builder, run `dart run build_runner build --delete-conflicting-outputs`.
- Both runners use the generated `runFeatures()`, so `integration_test/app_test.dart`
  has the same hook. On a device the files go to the device file system; this
  is not checked.
