fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

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

### android internal

```sh
[bundle exec] fastlane android internal
```

Upload to Google Play Store Internal Testing

### android alpha

```sh
[bundle exec] fastlane android alpha
```

Upload to Google Play Store Alpha

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
