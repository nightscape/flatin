/// Feature axes and labels of one data file (schema 3.2, rules S1, S7, S17).
///
/// See `lib/data/SCHEMA.md`.
library;

/// A canonical form key: the value codes of a feature bundle in axis
/// declaration order, joined by "." (S1).
typedef FormKey = String;

/// One feature axis of a data file, e.g. Kasus with nom/gen/dat/...
final class GrammarAxis {
  final String id;
  final String name;

  /// Value codes with their label text, in declaration order.
  final List<(String code, String display)> values;

  /// Codes a label does not name (ind, akt, pos).
  final Set<String> hiddenInLabel;

  GrammarAxis({
    required this.id,
    required this.name,
    required this.values,
    this.hiddenInLabel = const {},
  }) {
    assert(values.isNotEmpty, 'axis $id has no values');
    assert(
      hiddenInLabel.every((code) => values.any((v) => v.$1 == code)),
      'axis $id hides a code it does not declare',
    );
  }

  Iterable<String> get codes => values.map((v) => v.$1);

  /// Declaration index of [code], or -1.
  int indexOf(String code) => values.indexWhere((v) => v.$1 == code);

  String display(String code) {
    final index = indexOf(code);
    if (index < 0) throw ArgumentError('axis $id has no code "$code"');
    return values[index].$2;
  }
}

/// S17: the label text of one value inside a matching feature bundle.
final class LabelOverride {
  /// Feature axis id → the codes this entry applies to.
  final Map<String, Set<String>> when;
  final String axis;

  /// Code → label text.
  final Map<String, String> values;

  LabelOverride({required this.when, required this.axis, required this.values});

  bool matches(Map<String, String> features) =>
      when.entries.every((e) => e.value.contains(features[e.key]));
}

/// The axes and label layout of one data file.
final class Axes {
  final List<GrammarAxis> axes;

  /// Axes named before the colon and after it.
  final List<String> head, tail;

  /// The axis whose values [describeLabels] joins with "/".
  final String mergeAxis;
  final List<LabelOverride> labelOverrides;

  final Map<String, GrammarAxis> _byId;
  final Map<String, GrammarAxis> _byCode;

  Axes({
    required this.axes,
    required this.head,
    required this.tail,
    required this.mergeAxis,
    this.labelOverrides = const [],
  }) : _byId = {for (final axis in axes) axis.id: axis},
       _byCode = {
         for (final axis in axes)
           for (final code in axis.codes) code: axis,
       } {
    assert(_byId.length == axes.length, 'duplicate axis id');
    // S1: a code identifies its axis, so a key needs no axis names.
    final declaringAxis = <String, String>{};
    for (final axis in axes) {
      for (final code in axis.codes) {
        final first = declaringAxis[code];
        if (first != null) {
          throw ArgumentError(
            'value code "$code" is declared by axis $first and axis ${axis.id}',
          );
        }
        declaringAxis[code] = axis.id;
      }
    }
    assert(
      {...head, ...tail}.length == head.length + tail.length &&
          {...head, ...tail}.length == axes.length &&
          [...head, ...tail].every(_byId.containsKey),
      'label head and tail must list every axis exactly once',
    );
    assert(_byId.containsKey(mergeAxis), 'merge_axis $mergeAxis is no axis');
  }

  GrammarAxis byId(String id) {
    final axis = _byId[id];
    if (axis == null) throw ArgumentError('no axis "$id"');
    return axis;
  }

  /// The axis that declares [code], or null.
  GrammarAxis? axisOfCode(String code) => _byCode[code];

  /// Splits a canonical key into axis id → code. Throws on an unknown code or
  /// on codes out of axis order (such a key is not canonical, S1).
  Map<String, String> parseKey(FormKey key) {
    final features = <String, String>{};
    var axisIndex = -1;
    for (final code in key.split('.')) {
      final axis = _byCode[code];
      if (axis == null) {
        throw ArgumentError('key "$key": no axis declares the code "$code"');
      }
      final index = axes.indexOf(axis);
      if (index <= axisIndex) {
        throw ArgumentError(
          'key "$key": code "$code" (axis ${axis.id}) breaks axis order',
        );
      }
      axisIndex = index;
      features[axis.id] = code;
    }
    return features;
  }

  FormKey formatKey(Map<String, String> features) {
    final codes = <String>[];
    for (final axis in axes) {
      final code = features[axis.id];
      if (code == null) continue;
      if (axis.indexOf(code) < 0) {
        throw ArgumentError('axis ${axis.id} has no code "$code"');
      }
      codes.add(code);
    }
    if (codes.length != features.length) {
      final unknown = features.keys.where((id) => !_byId.containsKey(id));
      throw ArgumentError('no axis ${unknown.join(", ")}');
    }
    return codes.join('.');
  }

  /// S7: axis order, then value order inside each axis; an absent axis sorts
  /// before any value.
  int compare(Map<String, String> a, Map<String, String> b) {
    for (final axis in axes) {
      final left = a[axis.id], right = b[axis.id];
      if (left == right) continue;
      if (left == null) return -1;
      if (right == null) return 1;
      final order = axis.indexOf(left).compareTo(axis.indexOf(right));
      if (order != 0) return order;
    }
    return 0;
  }

  /// The label text of [features]'s value on [axisId] after S17.
  String displayOf(String axisId, Map<String, String> features) {
    final code = features[axisId]!;
    for (final override in labelOverrides) {
      if (override.axis == axisId &&
          override.values.containsKey(code) &&
          override.matches(features)) {
        return override.values[code]!;
      }
    }
    return byId(axisId).display(code);
  }

  /// "Konjunktiv Plusquamperfekt Passiv: 1. Person Singular".
  /// [mergedText] replaces the [mergeAxis] value's text (see [describeLabels]).
  String render(Map<String, String> features, {String? mergedText}) {
    String? text(String axisId) {
      final code = features[axisId];
      if (code == null) return null;
      if (byId(axisId).hiddenInLabel.contains(code)) return null;
      if (axisId == mergeAxis && mergedText != null) return mergedText;
      return displayOf(axisId, features);
    }

    final headText = head.map(text).nonNulls.join(' ');
    final tailText = tail.map(text).nonNulls.join(' ');
    if (headText.isEmpty) return tailText;
    if (tailText.isEmpty) return headText;
    return '$headText: $tailText';
  }
}

/// The grammatical features of one form, with the text they read as.
final class FormLabel {
  /// Feature axis id → value code.
  final Map<String, String> features;
  final Axes axes;

  FormLabel({required this.features, required this.axes}) {
    assert(features.isNotEmpty, 'a label needs at least one feature');
    axes.formatKey(features); // throws on an unknown axis or code
  }

  FormLabel.fromKey(FormKey key, this.axes) : features = axes.parseKey(key);

  late final FormKey key = axes.formatKey(features);

  String get displayName => axes.render(features);

  /// The value text of [axisId] after S17, null if the axis is absent.
  String? display(String axisId) =>
      features.containsKey(axisId) ? axes.displayOf(axisId, features) : null;

  /// Labels of two data files are never compared: one axis set is in play at
  /// a time, so a second [Axes] instance is a programming error, not a
  /// mismatch.
  @override
  bool operator ==(Object other) {
    if (other is! FormLabel) return false;
    assert(
      identical(other.axes, axes),
      'comparing labels built on two Axes instances',
    );
    return other.key == key;
  }

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'FormLabel($key)';
}

/// Names several labels in one phrase, merging those that differ only in the
/// merge axis: [Dativ Plural, Ablativ Plural] → "Dativ/Ablativ Plural".
String describeLabels(List<FormLabel> labels) {
  assert(labels.isNotEmpty);
  final axes = labels.first.axes;
  final merged = <FormKey, (Map<String, String>, List<String>)>{};

  for (final label in labels) {
    final rest = {...label.features}..remove(axes.mergeAxis);
    final group = merged.putIfAbsent(
      axes.formatKey(rest),
      () => (label.features, <String>[]),
    );
    final code = label.features[axes.mergeAxis];
    if (code == null ||
        axes.byId(axes.mergeAxis).hiddenInLabel.contains(code)) {
      continue;
    }
    final text = axes.displayOf(axes.mergeAxis, label.features);
    if (!group.$2.contains(text)) group.$2.add(text);
  }

  return merged.values
      .map(
        (group) => axes.render(
          group.$1,
          mergedText: group.$2.isEmpty ? null : group.$2.join('/'),
        ),
      )
      .join(', ');
}
