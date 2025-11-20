import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import '../widgets/app_drawer.dart';
import '../data/practice_data.dart';
import '../models/practice_item.dart';
import '../providers/fsrs_provider.dart';
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
            // Nouns button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: FutureBuilder<List<PracticeItem>>(
                future: loadPracticeItems('lib/data/latin_nouns.yaml'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text(
                      FlutterI18n.translate(
                        context,
                        'home.error',
                        translationParams: {'error': snapshot.error.toString()},
                      ),
                      style: TextStyle(fontSize: isMobile ? 14.0 : 16.0),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text(
                      FlutterI18n.translate(context, 'home.noData'),
                      style: TextStyle(fontSize: isMobile ? 14.0 : 16.0),
                    );
                  }
                  return Consumer(
                    builder: (context, ref, child) {
                      final nextDueItemAsync = ref.watch(
                        nextDueItemProvider('nouns'),
                      );
                      return nextDueItemAsync.when(
                        data: (nextItem) {
                          final dueItemsAsync = ref.watch(
                            dueItemsByTypeProvider,
                          );
                          final dueCount =
                              dueItemsAsync.value?['nouns']?.length ?? 0;
                          final itemToShow = nextItem ?? snapshot.data!.first;
                          return SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton(
                              key: const Key('home.nouns.button'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PracticeScreen(item: itemToShow),
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    FlutterI18n.translate(
                                      context,
                                      'home.nouns',
                                    ),
                                    style: TextStyle(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (dueCount > 0)
                                    Text(
                                      '$dueCount ${FlutterI18n.translate(context, 'home.due')}',
                                      style: TextStyle(
                                        fontSize: isMobile ? 10.0 : 12.0,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            key: const Key('home_nouns_button'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PracticeScreen(
                                    item: snapshot.data!.first,
                                  ),
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
                              FlutterI18n.translate(context, 'home.nouns'),
                              style: TextStyle(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        error: (_, __) => SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            key: const Key('home_nouns_button'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PracticeScreen(
                                    item: snapshot.data!.first,
                                  ),
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
                              FlutterI18n.translate(context, 'home.nouns'),
                              style: TextStyle(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Verbs button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: FutureBuilder<List<PracticeItem>>(
                future: loadPracticeItems('lib/data/latin_verbs.yaml'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text(
                      FlutterI18n.translate(
                        context,
                        'home.error',
                        translationParams: {'error': snapshot.error.toString()},
                      ),
                      style: TextStyle(fontSize: isMobile ? 14.0 : 16.0),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text(
                      FlutterI18n.translate(context, 'home.noData'),
                      style: TextStyle(fontSize: isMobile ? 14.0 : 16.0),
                    );
                  }
                  return Consumer(
                    builder: (context, ref, child) {
                      final nextDueItemAsync = ref.watch(
                        nextDueItemProvider('verbs'),
                      );
                      return nextDueItemAsync.when(
                        data: (nextItem) {
                          final dueItemsAsync = ref.watch(
                            dueItemsByTypeProvider,
                          );
                          final dueCount =
                              dueItemsAsync.value?['verbs']?.length ?? 0;
                          final itemToShow = nextItem ?? snapshot.data!.first;
                          return SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton(
                              key: const Key('home.verbs.button'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PracticeScreen(item: itemToShow),
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    FlutterI18n.translate(
                                      context,
                                      'home.verbs',
                                    ),
                                    style: TextStyle(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (dueCount > 0)
                                    Text(
                                      '$dueCount ${FlutterI18n.translate(context, 'home.due')}',
                                      style: TextStyle(
                                        fontSize: isMobile ? 10.0 : 12.0,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            key: const Key('home.verbs.button'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PracticeScreen(
                                    item: snapshot.data!.first,
                                  ),
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
                              FlutterI18n.translate(context, 'home.verbs'),
                              style: TextStyle(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        error: (_, __) => SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            key: const Key('home.verbs.button'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PracticeScreen(
                                    item: snapshot.data!.first,
                                  ),
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
                              FlutterI18n.translate(context, 'home.verbs'),
                              style: TextStyle(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Word Classification button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
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
