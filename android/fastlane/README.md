fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# What runs on a release tag

Pushing a tag `vX.Y.Z` (or `vX.Y.Z-label.N`) starts `.github/workflows/deploy.yml` with three independent jobs:

- `github-release` builds the signed APK and attaches it to the GitHub Release.
- `play-alpha` runs only for tags without a pre-release part (`v1.9.0`, not `v1.9.0-alpha.3`), because a pre-release shares the version code of its release and Play rejects a repeated code. It runs `fastlane alpha`: it builds the signed app bundle and uploads it to the Google Play closed-testing track "Alpha", together with the listing text and images from `metadata/`. Before the upload it runs `fastlane store_pictures`, which makes the phone pictures headless and copies them into `metadata/android/<locale>/images/phoneScreenshots`. The job fails before the upload if `de-DE` or `en-US` has fewer than 2 `store-*.png` pictures.
- `testflight` runs for the same final tags and uploads the iOS build; see `ios/fastlane/README.md`.

The jobs take version name and code from the tag (`fastlane/version_from_tag.rb`), so the bundle and the APK carry the same values. Version code is `major*10000 + minor*100 + patch`.

An open Play review does not fail the upload: fastlane retries the commit with `changesNotSentForReview` (`rescue_changes_not_sent_for_review`, on by default). The job fails only on a real upload error. After such a retry the new release waits in the Play Console under "Publishing overview" until someone sends the changes for review.

Each release needs `metadata/android/<locale>/changelogs/<versionCode>.txt` for `de-DE` and `en-US` (at most 500 characters). Add both files before you create the tag. The job `play-alpha` checks them in the step "Check changelogs", right after the Ruby setup, and fails there when one is missing or empty (`supply` would skip a missing file silently). The iOS lane reads the same files.

The workflow needs the secrets `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`. Locally, point `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH` to the service-account file and run `bundle exec fastlane android alpha validate_only:true` to check an upload without publishing it.

# Available Actions

## Android

### android build

```sh
[bundle exec] fastlane android build
```

Build the Android release APK

### android build_bundle

```sh
[bundle exec] fastlane android build_bundle
```

Build the Android App Bundle (AAB) for Play Store

### android screenshots

```sh
[bundle exec] fastlane android screenshots
```

Run integration tests and collect screenshots

### android cucumber_tests

```sh
[bundle exec] fastlane android cucumber_tests
```

Run Cucumber tests and collect screenshots

### android internal

```sh
[bundle exec] fastlane android internal
```

Upload to Google Play Store Internal Testing

### android alpha

```sh
[bundle exec] fastlane android alpha
```

Upload to Google Play Store Alpha (validate_only:true checks the upload without publishing)

### android beta

```sh
[bundle exec] fastlane android beta
```

Upload to Google Play Store Beta

### android release

```sh
[bundle exec] fastlane android release
```

Upload to Google Play Store Production

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
