import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _query = '';

  Future<void> _choose(Locale? locale) async {
    await ref.read(localeOverrideProvider.notifier).select(locale);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(localeOverrideProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5E5E5),
        elevation: 0,
        title: Text(FlutterI18n.translate(context, 'language.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('language.search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                hintText: FlutterI18n.translate(context, 'language.search'),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  key: const Key('language.system'),
                  title: Text(FlutterI18n.translate(context, 'language.system')),
                  selected: selected == null,
                  onTap: () => _choose(null),
                ),
                for (final offered in offeredLocales)
                  if (offered.matches(_query))
                    ListTile(
                      key: Key('language.${offered.code}'),
                      title: Text(offered.label),
                      selected: selected?.languageCode == offered.code,
                      onTap: () => _choose(offered.locale),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
