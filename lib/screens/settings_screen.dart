import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import '../providers/settings_provider.dart';
import '../data/practice_data.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<FormMetadata>? _nounsMetadata;
  Future<FormMetadata>? _verbsMetadata;

  @override
  void initState() {
    super.initState();
    _nounsMetadata = getFormMetadata('lib/data/latin_nouns.yaml');
    _verbsMetadata = getFormMetadata('lib/data/latin_verbs.yaml');
  }

  Widget _buildFormSection(
    String title,
    String dataFileId,
    FormMetadata metadata,
    bool isMobile,
  ) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      data: (settings) {
        final enabledForms =
            settings.enabledForms[dataFileId] ??
            Set<String>.from(metadata.formOrder);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12.0 : 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      key: Key('settings.section.$dataFileId'),
                      style: TextStyle(
                        fontSize: isMobile ? 20.0 : 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final notifier = ref.read(settingsProvider.notifier);
                      notifier.enableAllForms(dataFileId, metadata.formOrder);
                    },
                    child: Text(
                      FlutterI18n.translate(context, 'settings.enableAll'),
                      style: TextStyle(fontSize: isMobile ? 12.0 : 14.0),
                    ),
                  ),
                ],
              ),
            ),
            ...metadata.formOrder.map((formKey) {
              final formLabel = metadata.formLabelsByKey[formKey]!;
              final isEnabled = enabledForms.contains(formKey);

              return CheckboxListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 4.0 : 0.0,
                  vertical: isMobile ? 4.0 : 0.0,
                ),
                title: Text(
                  formLabel.displayName,
                  style: TextStyle(
                    fontSize: isMobile ? 14.0 : 16.0,
                    color: Colors.black,
                  ),
                ),
                value: isEnabled,
                onChanged: (value) {
                  final notifier = ref.read(settingsProvider.notifier);
                  notifier.toggleForm(dataFileId, formKey);
                },
                activeColor: const Color(0xFFD0D0D0),
                checkColor: Colors.black,
              );
            }),
            SizedBox(height: isMobile ? 16 : 24),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text(
        FlutterI18n.translate(
          context,
          'settings.error',
          translationParams: {'error': error.toString()},
        ),
        style: TextStyle(fontSize: isMobile ? 14.0 : 16.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final titleFontSize = isMobile ? 20.0 : 24.0;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5E5E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          key: const Key('settings.title'),
          FlutterI18n.translate(context, 'settings.title'),
          style: TextStyle(
            color: Colors.black,
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<FormMetadata>(
        future: _nounsMetadata,
        builder: (context, nounsSnapshot) {
          if (!nounsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<FormMetadata>(
            future: _verbsMetadata,
            builder: (context, verbsSnapshot) {
              if (!verbsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormSection(
                      FlutterI18n.translate(context, 'settings.nouns'),
                      'nouns',
                      nounsSnapshot.data!,
                      isMobile,
                    ),
                    _buildFormSection(
                      FlutterI18n.translate(context, 'settings.verbs'),
                      'verbs',
                      verbsSnapshot.data!,
                      isMobile,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
