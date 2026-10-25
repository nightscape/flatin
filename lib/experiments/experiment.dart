import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

/// Shows [variants] side by side as tabs, inside the real app shell (theme,
/// i18n, providers). An experiment is one file next to this one with its own
/// `main`, started with `flutter run -d macos -t lib/experiments/<file>.dart`;
/// the app never imports it, so deleting the file removes the experiment.
///
/// Variants must not write settings or progress: on macOS the experiment
/// shares SharedPreferences with the installed app.
void runExperiment(String title, Map<String, Widget> variants) {
  runApp(
    ProviderScope(
      retry: noRetry,
      child: LatinPracticeApp(
        home: _Variants(title: title, variants: variants),
      ),
    ),
  );
}

class _Variants extends StatelessWidget {
  const _Variants({required this.title, required this.variants});

  final String title;
  final Map<String, Widget> variants;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: variants.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final name in variants.keys) Tab(text: name)],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: variants.values.toList(),
        ),
      ),
    );
  }
}
