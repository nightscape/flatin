// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The [FormIndex] of the active course. It stays until a course switch
/// rebuilds it.

@ProviderFor(formIndex)
final formIndexProvider = FormIndexProvider._();

/// The [FormIndex] of the active course. It stays until a course switch
/// rebuilds it.

final class FormIndexProvider
    extends
        $FunctionalProvider<
          AsyncValue<FormIndex>,
          FormIndex,
          FutureOr<FormIndex>
        >
    with $FutureModifier<FormIndex>, $FutureProvider<FormIndex> {
  /// The [FormIndex] of the active course. It stays until a course switch
  /// rebuilds it.
  FormIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formIndexHash();

  @$internal
  @override
  $FutureProviderElement<FormIndex> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FormIndex> create(Ref ref) {
    return formIndex(ref);
  }
}

String _$formIndexHash() => r'66b0f6fe6538d59c68c2907082745aa30c2ab321';
