// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The [FormIndex] of the active course; a course switch rebuilds it.

@ProviderFor(formIndex)
final formIndexProvider = FormIndexProvider._();

/// The [FormIndex] of the active course; a course switch rebuilds it.

final class FormIndexProvider
    extends
        $FunctionalProvider<
          AsyncValue<FormIndex>,
          FormIndex,
          FutureOr<FormIndex>
        >
    with $FutureModifier<FormIndex>, $FutureProvider<FormIndex> {
  /// The [FormIndex] of the active course; a course switch rebuilds it.
  FormIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formIndexProvider',
        isAutoDispose: true,
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

String _$formIndexHash() => r'f1c7cd9ec9a014a2195082c70fbf2f9ac1703cef';
