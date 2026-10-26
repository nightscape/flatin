# What runs on a release tag

Pushing a tag `vX.Y.Z` starts the job `testflight` in `.github/workflows/deploy.yml`. It runs only for tags without a pre-release part (`v1.9.0`, not `v1.9.0-alpha.3`), like the Play job. A manual start runs the job only with the tick `ios_signing_check`, on any branch or tag, and then it runs `signing_check` (no upload, see below). A manual start without the tick runs no job. Only a tag push runs `fastlane beta` on a macOS runner:

1. Reads the "What to test" text from `android/fastlane/metadata/android/{de-DE,en-US}/changelogs/<buildNumber>.txt`. Each release needs both files; add them before you create the tag. A missing file fails the lane at once, before the key and the build.
2. `flutter build ios --config-only --no-codesign` (the step writes the Xcode configuration and needs no certificate) with `--build-name` and `--build-number` from the tag (`fastlane/version_from_tag.rb`). The build number is `major*10000 + minor*100 + patch`, the same as the Android version code. There is no `increment_build_number`.
3. `build_app` archives and exports the app with automatic signing: `-allowProvisioningUpdates` plus the App Store Connect API key lets Xcode create the certificate and the App Store profile in Apple's cloud. No certificate or profile is stored in the repository or in a secret. The key goes to `xcodebuild` once, through `xcargs`: gym adds `xcargs` to the archive and to the export command (gym 2.228.0 has no `api_key` option of its own), so `export_xcargs` must not repeat it.
4. `upload_to_testflight` uploads the build, waits for Apple's processing (limit 40 minutes), sends the build to beta review and adds it to the external group "Tester". The public link serves the build once Apple accepts the review. The wait is needed because a build can only join an external group after processing.

## Xcode version

The job runs on `macos-15` and selects `/Applications/Xcode_26.3.app` with `xcode-select` (iOS 26.2 SDK) before anything else uses Xcode. The image default is Xcode 16.4 (iOS 18.5 SDK), which Apple rejects at upload: "All iOS and iPadOS apps must be built with the iOS 26 SDK or later". The step "Print Xcode and iOS SDK version" writes `xcodebuild -version` and the `iphoneos` SDK version to the log. If GitHub removes that Xcode from the image, the select step fails; pick a newer `Xcode_26.x.app` from the [macos-15-arm64 image list](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md) (the `macos-26` image has 26.6 as default).

## Check the signing before a tag

Start the workflow by hand (Actions, "Deploy to Stores", Run workflow) and tick `ios_signing_check`. The job `testflight` then runs `fastlane signing_check`: the same configuration and `build_app` steps as `beta`, with the fixed version `0.0.1 (1)`, and no upload and no changelog. A manual start never runs `beta`, never uploads and never runs the Play and GitHub release jobs, also on a final tag. Only a tag push does that.

## Secrets

| Secret | Content |
|---|---|
| `ASC_KEY_ID` | Key ID of the App Store Connect API key |
| `ASC_ISSUER_ID` | Issuer ID of the team |
| `ASC_KEY_P8` | The `.p8` private key, base64 encoded (`base64 -i AuthKey_XXXX.p8`) |

The key needs the role "Admin": cloud-managed distribution certificates are only created for that role. The job writes the key to a temporary file (mode 600) and deletes it at the end, also on failure.

## What must exist in App Store Connect

- The app "Latein Lernen" (bundle id `dev.mauch.flatin`, team `Y8F4WDWJ59`).
- The external group "Tester" with the public link enabled.
- The beta app information for external testing: contact details of the beta review, feedback email and description. Apple asks for them with the first build that goes to external review.

## Local run

Export `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` (path of the `.p8` file) and `GITHUB_REF_NAME` (for example `v1.9.0`), then `bundle exec fastlane ios beta`. This uploads a real build.
