import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final notifier = ref.read(settingsProvider.notifier);
                      notifier.enableAllForms(dataFileId, metadata.formOrder);
                    },
                    child: const Text(
                      'Alle aktivieren',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            ...metadata.formOrder.map((formKey) {
              final formLabel = metadata.formLabelsByKey[formKey]!;
              final isEnabled = enabledForms.contains(formKey);

              return CheckboxListTile(
                title: Text(
                  formLabel.displayName,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
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
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('Error: $error'),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Einstellungen',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormSection(
                      'Nomen (Deklination)',
                      'nouns',
                      nounsSnapshot.data!,
                    ),
                    _buildFormSection(
                      'Verben (Konjugation)',
                      'verbs',
                      verbsSnapshot.data!,
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
