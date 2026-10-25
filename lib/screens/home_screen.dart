import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import '../data/rewards.dart';
import '../widgets/app_drawer.dart';
import '../models/practice_item.dart';
import '../providers/fsrs_provider.dart';
import '../providers/reward_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/town_view.dart';
import 'grammar_start_screen.dart';
import 'word_classification_screen.dart';
import 'practice_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final titleFontSize = isMobile ? 20.0 : 24.0;
    final (showTown, showCoins) = switch (ref.watch(settingsProvider)) {
      AsyncData(:final value) => (
        value.isRewardEnabled('town'),
        value.isRewardEnabled('points'),
      ),
      AsyncError(:final error) => throw error,
      _ => (false, false),
    };

    return Scaffold(
      drawer: buildAppDrawer(context),
      appBar: AppBar(
        title: Text(
          key: const Key('app.title'),
          FlutterI18n.translate(context, 'app.title'),
          style: TextStyle(fontSize: titleFontSize),
        ),
        actions: [if (showCoins) const _Coins()],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: LayoutBuilder(
              builder: (context, box) {
                final menu = Column(
                  children: [
                    const _PracticeTypeButton(
                      dataFileId: 'nouns',
                      labelKey: 'home.nouns',
                      icon: Icons.account_balance,
                      buttonKey: Key('home.nouns.button'),
                    ),
                    const SizedBox(height: 14),
                    const _PracticeTypeButton(
                      dataFileId: 'verbs',
                      labelKey: 'home.verbs',
                      icon: Icons.directions_run,
                      buttonKey: Key('home.verbs.button'),
                    ),
                    const SizedBox(height: 14),
                    _MenuButton(
                      buttonKey: const Key('home.grammar.button'),
                      icon: Icons.menu_book,
                      label: FlutterI18n.translate(context, 'home.grammar'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const GrammarStartScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MenuButton(
                      buttonKey: const Key('home.wordClassification.button'),
                      icon: Icons.psychology,
                      label: FlutterI18n.translate(
                        context,
                        'home.wordClassification',
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const WordClassificationScreen(),
                        ),
                      ),
                    ),
                  ],
                );
                if (!showTown) return menu;
                final sceneHeight = box.maxWidth * townHeight / townWidth;
                return Stack(
                  children: [
                    const _TownPanel(),
                    Padding(
                      padding: EdgeInsets.only(
                        top: sceneHeight * _townBase + 8,
                      ),
                      child: menu,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The learner's points, shown as coins.
class _Coins extends ConsumerWidget {
  const _Coins();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = switch (ref.watch(rewardsProvider)) {
      AsyncData(:final value) => value.points,
      AsyncError(:final error) => throw error,
      _ => null,
    };
    if (points == null) return const SizedBox.shrink();
    return Tooltip(
      message: FlutterI18n.translate(context, 'settings.reward.points'),
      child: Container(
        key: const Key('home.coins'),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
        decoration: BoxDecoration(
          color: terracottaDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.toll, color: gold, size: 22),
            const SizedBox(width: 6),
            Text(
              '$points',
              style: const TextStyle(
                color: parchment,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The menu may cover the scene below the front-most building.
final _townBase = townSprites.map((s) => s.bottom).reduce(max);

/// The learner's town scene, captioned with the practice days or an invitation.
class _TownPanel extends ConsumerWidget {
  const _TownPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    final Widget content;
    if (rewards.hasError) {
      content = Center(
        child: Text(
          FlutterI18n.translate(
            context,
            'home.error',
            translationParams: {'error': '${rewards.error}'},
          ),
        ),
      );
    } else if (!rewards.hasValue) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      final ledger = rewards.requireValue;
      final caption = ledger.buildings.isEmpty
          ? FlutterI18n.translate(context, 'home.townEmpty')
          : ledger.practiceDays > 0
          ? FlutterI18n.translate(
              context,
              'round.start.days',
              translationParams: {'n': '${ledger.practiceDays}'},
            )
          : null;
      content = Stack(
        children: [
          TownView(ledger),
          if (caption != null)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: parchment.withAlpha(220),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    caption,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return ShaderMask(
      key: const Key('home.town'),
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.black, Colors.transparent],
        stops: [_townBase, _townBase + 0.1],
      ).createShader(rect),
      child: AspectRatio(aspectRatio: townWidth / townHeight, child: content),
    );
  }
}

/// Entry point for one exercise type: opens the next due item, or any
/// practicable one, and is disabled while the type has none.
class _PracticeTypeButton extends ConsumerWidget {
  const _PracticeTypeButton({
    required this.dataFileId,
    required this.labelKey,
    required this.icon,
    required this.buttonKey,
  });

  final String dataFileId;
  final String labelKey;
  final IconData icon;
  final Key buttonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return _MenuButton(
      buttonKey: buttonKey,
      icon: icon,
      label: FlutterI18n.translate(context, labelKey),
      badge: due.isEmpty
          ? null
          : '${due.length} ${FlutterI18n.translate(context, 'home.due')}',
      onPressed: itemToShow == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PracticeScreen(item: itemToShow),
              ),
            ),
    );
  }
}

/// A full-width game-menu button; muted while [onPressed] is null.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badge,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final foreground = enabled ? parchment : mutedText;
    return Container(
      height: isMobile ? 70 : 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: enabled
              ? const [terracotta, terracottaDark]
              : const [sand, sand],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enabled ? gold : outlineColor, width: 2.5),
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: enabled ? gold : mutedText),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: headingFont,
                  fontSize: isMobile ? 17 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
