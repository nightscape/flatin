import 'dart:io';

/// The working directory at the first read. test/features_test.dart reads it
/// before it moves the working directory away, so outputs that `fastlane` and
/// the README read land in the repo's `build/`.
final repoDir = Directory.current.path;
