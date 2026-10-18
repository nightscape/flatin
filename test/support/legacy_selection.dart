/// The selection the settings answered before the course filter existed.
/// The migration tests keep it as their oracle.
library;

import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';

/// A form was on when its own switch was on and every axis value it names
/// was on.
Set<FormKey> legacyEnabledForms(
  Settings settings,
  String dataFileId,
  List<FormLabel> labels,
) =>
    {
      for (final label in labels)
        if (settings.isFormSwitchedOn(dataFileId, label.key) &&
            settings.offFeaturesOf(dataFileId, label).isEmpty)
          label.key,
    };

/// An item was practised when neither its word nor its type was switched off.
bool legacyItemSelected(Settings settings, PracticeItem item) =>
    settings.isWordSelected(normalizeDiacritics(item.lemma)) &&
    settings.isTypeEnabled(item.dataFileId, item.type);
