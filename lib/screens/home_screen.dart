import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import '../widgets/app_drawer.dart';
import '../models/practice_item.dart';
import '../providers/fsrs_provider.dart';
import 'grammar_exercise_page.dart';
import 'word_classification_screen.dart';
import 'practice_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 8.0 : 12.0;
    final titleFontSize = isMobile ? 20.0 : 24.0;
    final buttonFontSize = isMobile ? 18.0 : 20.0;
    final buttonHeight = isMobile ? 70.0 : 80.0;
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: verticalPadding,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      drawer: buildAppDrawer(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5E5E5),
        elevation: 0,
        title: Text(
          key: const Key('app.title'),
          FlutterI18n.translate(context, 'app.title'),
          style: TextStyle(
            color: Colors.black,
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: buttonPadding,
              child: const _PracticeTypeButton(
                dataFileId: 'nouns',
                labelKey: 'home.nouns',
                buttonKey: Key('home.nouns.button'),
              ),
            ),
            Padding(
              padding: buttonPadding,
              child: const _PracticeTypeButton(
                dataFileId: 'verbs',
                labelKey: 'home.verbs',
                buttonKey: Key('home.verbs.button'),
              ),
            ),
            Padding(
              padding: buttonPadding,
              child: const _GrammarExerciseButton(),
            ),
            Padding(
              padding: buttonPadding,
              child: SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: ElevatedButton(
                  key: const Key('home.wordClassification.button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const WordClassificationScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD0D0D0),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    FlutterI18n.translate(context, 'home.wordClassification'),
                    style: TextStyle(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entry point for one exercise type: opens the next due item, or any
/// practicable one, and is disabled while the type has none.
class _PracticeTypeButton extends ConsumerWidget {
  const _PracticeTypeButton({
    required this.dataFileId,
    required this.labelKey,
    required this.buttonKey,
  });

  final String dataFileId;
  final String labelKey;
  final Key buttonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final buttonFontSize = isMobile ? 18.0 : 20.0;
    final buttonHeight = isMobile ? 70.0 : 80.0;

    final practicableAsync = ref.watch(practicableItemsByTypeProvider);
    final dueAsync = ref.watch(dueItemsByTypeProvider);
    final error = practicableAsync.error ?? dueAsync.error;
    if (error != null) {
      return Text(
        FlutterI18n.translate(
          context,
          'home.error',
          translationParams: {'error': error.toString()},
        ),
        style: TextStyle(fontSize: isMobile ? 14.0 : 16.0),
      );
    }

    final practicable =
        practicableAsync.value?[dataFileId] ?? const <PracticeItem>[];
    final due = dueAsync.value?[dataFileId] ?? const <PracticeItem>[];
    final itemToShow = !dueAsync.hasValue
        ? null
        : due.isNotEmpty
        ? due.first
        : (practicable.isEmpty ? null : practicable.first);

    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        key: buttonKey,
        onPressed: itemToShow == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PracticeScreen(item: itemToShow),
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD0D0D0),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              FlutterI18n.translate(context, labelKey),
              style: TextStyle(
                fontSize: buttonFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (due.isNotEmpty)
              Text(
                '${due.length} ${FlutterI18n.translate(context, 'home.due')}',
                style: TextStyle(
                  fontSize: isMobile ? 10.0 : 12.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Entry point for the grammar exercises; disabled while no card is due.
class _GrammarExerciseButton extends ConsumerWidget {
  const _GrammarExerciseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final next = ref.watch(nextGrammarExerciseProvider);
    if (next.hasError) {
      return Text(
        FlutterI18n.translate(
          context,
          'home.error',
          translationParams: {'error': next.error.toString()},
        ),
        style: TextStyle(fontSize: isMobile ? 14.0 : 16.0),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 70.0 : 80.0,
      child: ElevatedButton(
        key: const Key('home.grammar.button'),
        onPressed: next.value == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const GrammarExercisePage(),
                ),
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD0D0D0),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          FlutterI18n.translate(context, 'exercise.home.grammar'),
          style: TextStyle(
            fontSize: isMobile ? 18.0 : 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
