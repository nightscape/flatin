// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The language the learner picked, or null while they follow the device.

@ProviderFor(LocaleOverride)
const localeOverrideProvider = LocaleOverrideProvider._();

/// The language the learner picked, or null while they follow the device.
final class LocaleOverrideProvider
    extends $AsyncNotifierProvider<LocaleOverride, Locale?> {
  /// The language the learner picked, or null while they follow the device.
  const LocaleOverrideProvider._()
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

String _$localeOverrideHash() => r'8f722d2575e2555828de6890e7107912b0d9a2d3';

/// The language the learner picked, or null while they follow the device.

abstract class _$LocaleOverride extends $AsyncNotifier<Locale?> {
  FutureOr<Locale?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<Locale?>, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Locale?>, Locale?>,
              AsyncValue<Locale?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
