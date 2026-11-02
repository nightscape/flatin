import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exam.dart';
import '../models/exam_units.dart';
import '../providers/exam_provider.dart';
import '../providers/settings_provider.dart';
import 'exam_screen.dart';

/// The bytes of a file the learner picks, or null when they pick none.
Future<Uint8List?> pickExamFile() async => (await openFile())?.readAsBytes();

/// Why an import stored nothing.
sealed class ImportRefusal {}

final class PackRejected extends ImportRefusal {
  final ExamError error;
  PackRejected(this.error);
}

/// The file is not UTF-8 text, so the checker never sees it.
final class NotUtf8Text extends ImportRefusal {}

/// The imported exams, the import, and the settings of the exam screen.
class ExamListScreen extends ConsumerStatefulWidget {
  /// Test seam for the file picker.
  final Future<Uint8List?> Function() pickBytes;
  const ExamListScreen({super.key, this.pickBytes = pickExamFile});

  @override
  ConsumerState<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends ConsumerState<ExamListScreen> {
  ImportRefusal? _refused;

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  Future<void> _import() async {
    final bytes = await widget.pickBytes();
    if (bytes == null) return;
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      setState(() => _refused = NotUtf8Text());
      return;
    }
    try {
      await ref.read(examPacksProvider.notifier).import(source);
      setState(() => _refused = null);
    } on ExamRejected catch (e) {
      setState(() => _refused = PackRejected(e.errors.first));
    }
  }

  @override
  Widget build(BuildContext context) {
    final packs = switch (ref.watch(examPacksProvider)) {
      AsyncData(:final value) => value,
      AsyncError(:final error) => throw error,
      _ => null,
    };
    final settings = ref.watch(settingsProvider).value;
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(_t('exam.list.title'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (settings != null) ...[
            Text(_t('exam.list.unit')),
            const SizedBox(height: 4),
            SegmentedButton<Uebersetzungseinheit>(
              key: const Key('exam.settings.unit'),
              segments: [
                for (final u in Uebersetzungseinheit.values)
                  ButtonSegment(
                    value: u,
                    label: Text(_t('exam.unit.${u.name}')),
                  ),
              ],
              selected: {settings.uebersetzungseinheit},
              onSelectionChanged: (s) =>
                  notifier.setUebersetzungseinheit(s.single),
            ),
            SwitchListTile(
              key: const Key('exam.settings.points'),
              title: Text(_t('exam.list.points')),
              value: settings.punkteAnzeige,
              onChanged: notifier.setPunkteAnzeige,
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            key: const Key('exam.import'),
            icon: const Icon(Icons.file_open),
            label: Text(_t('exam.list.import')),
            onPressed: _import,
          ),
          if (_refused case final refusal?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(switch (refusal) {
                PackRejected(:final error) => _t('exam.list.refused', {
                  'path': error.path,
                  'rule': error.rule.id,
                  'detail': error.detail,
                }),
                NotUtf8Text() => _t('exam.list.not_text'),
              }, key: const Key('exam.import.refused')),
            ),
          const SizedBox(height: 8),
          if (packs == null)
            const Center(child: CircularProgressIndicator())
          else if (packs.isEmpty)
            Text(_t('exam.list.empty'), key: const Key('exam.list.empty'))
          else
            for (final exam in packs)
              ListTile(
                key: Key('exam.list.${exam.id}'),
                title: Text(exam.titel),
                subtitle: Text(exam.thema),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ExamScreen(exam: exam)),
                ),
                trailing: IconButton(
                  key: Key('exam.delete.${exam.id}'),
                  tooltip: _t('exam.list.delete'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      ref.read(examPacksProvider.notifier).delete(exam.id),
                ),
              ),
        ],
      ),
    );
  }
}
