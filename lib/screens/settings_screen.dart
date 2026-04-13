import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import '../models/input_strategy.dart';
import '../providers/settings_provider.dart';
import '../providers/lesson_provider.dart';
import '../data/practice_data.dart';
import '../data/lesson_data.dart' show LessonData, normalizeDiacritics;

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

  /// All normalized words across every lesson — needed to handle "all selected"
  /// collapse when toggling a single word.
  List<String> _allNormalizedWords(LessonData lessons) {
    return lessons.lessonNames
        .expand<String>((name) => lessons.lessonWords[name] ?? [])
        .map<String>(normalizeDiacritics)
        .toList();
  }

  Widget _buildLessonSection(bool isMobile) {
    final lessonsAsync = ref.watch(lessonDataProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return lessonsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text(
        FlutterI18n.translate(
          context,
          'settings.error',
          translationParams: {'error': error.toString()},
        ),
        style: TextStyle(fontSize: isMobile ? 14.0 : 16.0),
      ),
      data: (LessonData lessons) {
        return settingsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (settings) {
            final allWords = _allNormalizedWords(lessons);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: isMobile ? 12.0 : 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          FlutterI18n.translate(context, 'settings.lessons'),
                          key: const Key('settings.section.lessons'),
                          style: TextStyle(
                            fontSize: isMobile ? 20.0 : 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(settingsProvider.notifier).selectAllWords();
                        },
                        child: Text(
                          FlutterI18n.translate(context, 'settings.enableAll'),
                          style: TextStyle(fontSize: isMobile ? 12.0 : 14.0),
                        ),
                      ),
                    ],
                  ),
                ),
                ...lessons.lessonNames.map((lessonName) {
                  final rawWords = lessons.lessonWords[lessonName] ?? [];
                  final fullySelected =
                      settings.isLessonFullySelected(lessonName, rawWords);
                  final partiallySelected =
                      settings.isLessonPartiallySelected(lessonName, rawWords);
                  // tristate: true=all, null=some, false=none
                  final checkboxValue =
                      fullySelected ? true : (partiallySelected ? null : false);

                  return Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      key: Key('lesson.$lessonName'),
                      tilePadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 4.0 : 0.0,
                      ),
                      leading: Checkbox(
                        tristate: true,
                        value: checkboxValue,
                        onChanged: (_) {
                          ref
                              .read(settingsProvider.notifier)
                              .toggleLessonWords(rawWords, allWords);
                        },
                        activeColor: const Color(0xFFD0D0D0),
                        checkColor: Colors.black,
                      ),
                      title: GestureDetector(
                        onTap: () {
                          ref
                              .read(settingsProvider.notifier)
                              .toggleLessonWords(rawWords, allWords);
                        },
                        child: Text(
                          lessonName,
                          style: TextStyle(
                            fontSize: isMobile ? 14.0 : 16.0,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      children: rawWords.map((rawWord) {
                        final normalized = normalizeDiacritics(rawWord);
                        final isSelected = settings.isWordSelected(normalized);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.only(
                            left: isMobile ? 52.0 : 48.0,
                            right: isMobile ? 4.0 : 0.0,
                          ),
                          title: Text(
                            rawWord,
                            style: TextStyle(
                              fontSize: isMobile ? 13.0 : 15.0,
                              color: Colors.black,
                            ),
                          ),
                          value: isSelected,
                          onChanged: (_) {
                            ref
                                .read(settingsProvider.notifier)
                                .toggleWord(normalized, allWords);
                          },
                          activeColor: const Color(0xFFD0D0D0),
                          checkColor: Colors.black,
                          dense: true,
                        );
                      }).toList(),
                    ),
                  );
                }),
                SizedBox(height: isMobile ? 16 : 24),
              ],
            );
          },
        );
      },
    );
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
            Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 8.0 : 12.0),
              child: Row(
                children: [
                  Text(
                    FlutterI18n.translate(context, 'settings.inputMode'),
                    style: TextStyle(
                      fontSize: isMobile ? 14.0 : 16.0,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: settings.getInputStrategyId(dataFileId),
                      items: InputStrategy.all
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                s.displayName,
                                style: TextStyle(
                                  fontSize: isMobile ? 13.0 : 14.0,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        ref
                            .read(settingsProvider.notifier)
                            .setInputStrategy(dataFileId, value);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 10 : 12,
                          vertical: isMobile ? 6 : 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Type filter section
            if (metadata.availableTypes.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(
                  top: isMobile ? 8.0 : 12.0,
                  bottom: isMobile ? 4.0 : 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      FlutterI18n.translate(context, 'settings.types'),
                      style: TextStyle(
                        fontSize: isMobile ? 16.0 : 18.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(settingsProvider.notifier).enableAllTypes(
                              dataFileId,
                              metadata.availableTypes,
                            );
                      },
                      child: Text(
                        FlutterI18n.translate(context, 'settings.enableAll'),
                        style: TextStyle(fontSize: isMobile ? 12.0 : 14.0),
                      ),
                    ),
                  ],
                ),
              ),
              ...metadata.availableTypes.map((typeName) {
                final enabledTypes =
                    settings.enabledTypes[dataFileId] ??
                    Set<String>.from(metadata.availableTypes);
                final isEnabled = enabledTypes.contains(typeName);

                return CheckboxListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 4.0 : 0.0,
                    vertical: isMobile ? 4.0 : 0.0,
                  ),
                  title: Text(
                    typeName,
                    style: TextStyle(
                      fontSize: isMobile ? 14.0 : 16.0,
                      color: Colors.black,
                    ),
                  ),
                  value: isEnabled,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .toggleType(dataFileId, typeName);
                  },
                  activeColor: const Color(0xFFD0D0D0),
                  checkColor: Colors.black,
                );
              }),
            ],
            Divider(height: isMobile ? 16 : 24),
            // Form filter section
            Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 4.0 : 8.0),
              child: Text(
                FlutterI18n.translate(context, 'settings.forms'),
                style: TextStyle(
                  fontSize: isMobile ? 16.0 : 18.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
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
                    _buildLessonSection(isMobile),
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
