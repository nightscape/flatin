// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'round_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The topics the course offers now, in course order.

@ProviderFor(topics)
const topicsProvider = TopicsProvider._();

/// The topics the course offers now, in course order.

final class TopicsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Topic>>,
          List<Topic>,
          FutureOr<List<Topic>>
        >
    with $FutureModifier<List<Topic>>, $FutureProvider<List<Topic>> {
  /// The topics the course offers now, in course order.
  const TopicsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topicsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topicsHash();

  @$internal
  @override
  $FutureProviderElement<List<Topic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Topic>> create(Ref ref) {
    return topics(ref);
  }
}

String _$topicsHash() => r'a6e4800b4c166e691a0ad6a13d56951d2173837e';
