// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The language the learner picked, or null while they follow the device.

@ProviderFor(LocaleOverride)
final localeOverrideProvider = LocaleOverrideProvider._();

/// The language the learner picked, or null while they follow the device.
final class LocaleOverrideProvider
    extends $AsyncNotifierProvider<LocaleOverride, Locale?> {
  /// The language the learner picked, or null while they follow the device.
  LocaleOverrideProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeOverrideProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeOverrideHash();

  @$internal
  @override
  LocaleOverride create() => LocaleOverride();
}

String _$localeOverrideHash() => r'235f3535113471c91927b167fa8f967cc11a3520';

/// The language the learner picked, or null while they follow the device.

abstract class _$LocaleOverride extends $AsyncNotifier<Locale?> {
  FutureOr<Locale?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Locale?>, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Locale?>, Locale?>,
              AsyncValue<Locale?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The language of the data texts: the language the app shows.
// shortcut: reads the device languages once, so a change of them while the
// app runs shows in the data texts after a restart; upgrade when that matters.

@ProviderFor(dataLanguage)
final dataLanguageProvider = DataLanguageProvider._();

/// The language of the data texts: the language the app shows.
// shortcut: reads the device languages once, so a change of them while the
// app runs shows in the data texts after a restart; upgrade when that matters.

final class DataLanguageProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The language of the data texts: the language the app shows.
  // shortcut: reads the device languages once, so a change of them while the
  // app runs shows in the data texts after a restart; upgrade when that matters.
  DataLanguageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataLanguageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataLanguageHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return dataLanguage(ref);
  }
}

String _$dataLanguageHash() => r'e5c577a8f85beea621dc95cbcdac600fc3a469ec';
