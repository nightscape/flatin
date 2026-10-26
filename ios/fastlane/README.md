# What runs on a release tag

Pushing a tag `vX.Y.Z` starts the job `testflight` in `.github/workflows/deploy.yml`. It runs only for tags without a pre-release part (`v1.9.0`, not `v1.9.0-alpha.3`), like the Play job. A manual start does this: from a branch without the tick `ios_signing_check`, the job does not run; from a branch with the tick, it runs `signing_check` (no upload, see below); from a final tag, it runs `beta` like a tag push and uploads. It runs `fastlane beta` on a macOS runner:

1. Reads the "What to test" text from `android/fastlane/metadata/android/{de-DE,en-US}/changelogs/<buildNumber>.txt`. A missing file fails the lane before the build.
2. `flutter build ios --config-only --no-codesign` (the step writes the Xcode configuration and needs no certificate) with `--build-name` and `--build-number` from the tag (`fastlane/version_from_tag.rb`). The build number is `major*10000 + minor*100 + patch`, the same as the Android version code. There is no `increment_build_number`.
3. `build_app` archives and exports the app with automatic signing: `-allowProvisioningUpdates` plus the App Store Connect API key lets Xcode create the certificate and the App Store profile in Apple's cloud. No certificate or profile is stored in the repository or in a secret.
4. `upload_to_testflight` uploads the build, waits for Apple's processing (limit 40 minutes), sends the build to beta review and adds it to the external group "Tester". The public link serves the build once Apple accepts the review. The wait is needed because a build can only join an external group after processing.

## Check the signing before a tag

Start the workflow by hand (Actions, "Deploy to Stores", Run workflow) and tick `ios_signing_check`. The job `testflight` then runs `fastlane signing_check`: the same configuration and `build_app` steps as `beta`, with the fixed version `0.0.1 (1)`, and no upload and no changelog. Start the check from a branch, not from a final tag: a manual start on a final tag without the tick runs `beta` and uploads, as a tag push does. A tag push does what it did before.

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
