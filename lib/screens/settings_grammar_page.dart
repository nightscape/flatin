import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/practice_data.dart';
import '../models/course_filter.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import 'course_scope.dart';
import 'settings_widgets.dart';

/// The types, features and forms of one data file ('nouns' or 'verbs'). What
/// the course has not taught yet is greyed and a tap practises it anyway.
class SettingsGrammarPage extends ConsumerStatefulWidget {
  const SettingsGrammarPage({super.key, required this.dataFileId});

  final String dataFileId;

  @override
  ConsumerState<SettingsGrammarPage> createState() =>
      _SettingsGrammarPageState();
}

class _SettingsGrammarPageState extends ConsumerState<SettingsGrammarPage> {
  late final Future<FormMetadata> _metadata = ref
      .read(dataLanguageProvider.future)
      .then(
        (language) => getFormMetadata(
          'lib/data/latin_${widget.dataFileId}.yaml',
          language: language,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      titleKey: Key('settings.${widget.dataFileId}.title'),
      title: FlutterI18n.translate(context, 'settings.${widget.dataFileId}'),
      body: FutureBuilder<FormMetadata>(
        future: _metadata,
        builder: (context, snapshot) {
          if (snapshot.hasError) return loadErrorText(context, snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return CourseScope(
            builder: (context, filter, _) =>
                _content(context, filter, snapshot.data!),
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    CourseFilter filter,
    FormMetadata metadata,
  ) {
    final id = widget.dataFileId;
    final settings = filter.settings;
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (metadata.availableTypes.isNotEmpty) ...[
          SectionTitle(FlutterI18n.translate(context, 'settings.types')),
          for (final typeName in metadata.availableTypes)
            _typeTile(context, filter, metadata, typeName),
        ],
        const Divider(),
        SectionTitle(FlutterI18n.translate(context, 'settings.features')),
        for (final axis in metadata.axes.axes) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              axis.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          for (final value in axis.values)
            CheckboxListTile(
              key: Key('feature.$id.${axis.id}.${value.$1}'),
              dense: true,
              title: Text(value.$2),
              value: settings.isFeatureEnabled(id, axis.id, value.$1),
              onChanged: (_) => notifier.toggleFeature(id, axis.id, value.$1),
              activeColor: settingsCheckboxColor,
              checkColor: Colors.black,
            ),
        ],
        const Divider(),
        SectionTitle(FlutterI18n.translate(context, 'settings.forms')),
        for (final formKey in metadata.formOrder)
          _formTile(context, filter, metadata, formKey),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _typeTile(
    BuildContext context,
    CourseFilter filter,
    FormMetadata metadata,
    String typeName,
  ) {
    final id = widget.dataFileId;
    final gap = filter.typeGap(id, typeName);
    return CheckboxListTile(
      key: Key('type.$id.$typeName'),
      title: Text(
        metadata.displayByType[typeName]!,
        style: TextStyle(color: rowTextColor(context, greyed: gap != null)),
      ),
      subtitle: gap == null ? null : Text(gapText(context, gap)),
      value: filter.typePracticed(id, typeName),
      onChanged: (_) => ref
          .read(settingsProvider.notifier)
          .toggleType(id, typeName, inRange: filter.typeInRange(id, typeName)),
      activeColor: settingsCheckboxColor,
      checkColor: Colors.black,
    );
  }

  Widget _formTile(
    BuildContext context,
    CourseFilter filter,
    FormMetadata metadata,
    String formKey,
  ) {
    final id = widget.dataFileId;
    final label = metadata.formLabelsByKey[formKey]!;
    final offFeatures = filter.settings.offFeaturesOf(id, label);
    final gap = filter.formGap(id, label);
    final greyed = offFeatures.isNotEmpty || gap != null;

    return CheckboxListTile(
      key: Key('form.$id.$formKey'),
      title: Text(
        label.displayName,
        style: TextStyle(color: rowTextColor(context, greyed: greyed)),
      ),
      subtitle: !greyed
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (axisId, code) in offFeatures)
                  Text(
                    FlutterI18n.translate(
                      context,
                      'settings.featureOff',
                      translationParams: {
                        'value': metadata.axes.byId(axisId).display(code),
                      },
                    ),
                  ),
                if (gap != null) Text(gapText(context, gap)),
              ],
            ),
      value: filter.formSelected(id, label),
      onChanged: offFeatures.isEmpty
          ? (_) => ref
                .read(settingsProvider.notifier)
                .toggleForm(id, formKey, inRange: filter.formInRange(id, label))
          : null,
      activeColor: settingsCheckboxColor,
      checkColor: Colors.black,
    );
  }
}
