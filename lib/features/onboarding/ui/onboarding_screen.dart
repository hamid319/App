import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/locale_controller.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/services/preferences_service.dart';
import '../../../l10n/l10n.dart';

/// A scene is two tilted paper "tickets" on the cream page. Placeholders
/// until real destination photos are bundled.
class _Scene {
  const _Scene(this.toneA, this.toneB, this.iconA, this.iconB);

  final ChipTone toneA;
  final ChipTone toneB;
  final IconData iconA;
  final IconData iconB;
}

const _scenes = [
  _Scene(
    ChipTone.sky,
    ChipTone.peach,
    Icons.landscape_rounded,
    Icons.beach_access_rounded,
  ),
  _Scene(
    ChipTone.peach,
    ChipTone.mint,
    Icons.museum_rounded,
    Icons.local_florist_rounded,
  ),
  _Scene(
    ChipTone.mint,
    ChipTone.gold,
    Icons.location_city_rounded,
    Icons.hiking_rounded,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _currentPage == _scenes.length - 1;

  Future<void> _next() async {
    if (!_isLast) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    await PreferencesService.setOnboardingShown();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      (l10n.onboarding1Lead, l10n.onboarding1Accent, l10n.onboarding1Body),
      (l10n.onboarding2Lead, l10n.onboarding2Accent, l10n.onboarding2Body),
      (l10n.onboarding3Lead, l10n.onboarding3Accent, l10n.onboarding3Body),
    ];

    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _scenes.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) => _OnboardingPage(
                scene: _scenes[i],
                lead: pages[i].$1,
                accent: pages[i].$2,
                body: pages[i].$3,
              ),
            ),
            // Top right on every page.
            const Positioned(
              top: 0,
              right: AppSizes.screenEdge,
              child: SafeArea(child: _LanguageChip()),
            ),
            Positioned(
              left: AppSizes.space24,
              right: AppSizes.space24,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.space16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Dots(count: _scenes.length, active: _currentPage),
                      const SizedBox(height: AppSizes.space24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _next,
                          child: Text(
                            _isLast
                                ? l10n.onboardingGetStarted
                                : l10n.onboardingNext,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.space4),
                      Center(
                        child: TextButton(
                          onPressed: _finish,
                          child: Text(l10n.onboardingGuest),
                        ),
                      ),
                    ],
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.scene,
    required this.lead,
    required this.accent,
    required this.body,
  });

  final _Scene scene;
  final String lead;
  final String accent;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final colors = context.swipeColors;
    return LayoutBuilder(builder: (context, box) {
      final textHeight = box.maxHeight * 0.46;
      return Stack(
        children: [
          Positioned(
            left: 26,
            top: box.maxHeight * 0.17,
            child: _FloatingCard(
              tone: scene.toneA,
              icon: scene.iconA,
              angle: -0.1,
              width: 128,
            ),
          ),
          Positioned(
            right: 28,
            top: box.maxHeight * 0.12,
            child: _FloatingCard(
              tone: scene.toneB,
              icon: scene.iconB,
              angle: 0.12,
              width: 116,
              stamp: context.l10n.likeStamp,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: textHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.space24,
                AppSizes.space24,
                AppSizes.space24,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$lead '),
                        // Gold underline: the orange is kept for the button.
                        TextSpan(
                          text: accent,
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: colors.gold,
                            decorationThickness: 3,
                          ),
                        ),
                      ],
                    ),
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: AppSizes.space12),
                  Text(
                    body,
                    style: text.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// A tilted pastel ticket with an ink rim and print shadow.
class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.tone,
    required this.icon,
    required this.angle,
    required this.width,
    this.stamp,
  });

  final ChipTone tone;
  final IconData icon;
  final double angle;
  final double width;
  final String? stamp;

  @override
  Widget build(BuildContext context) {
    final c = context.swipeColors;
    final scheme = Theme.of(context).colorScheme;
    final fill = switch (tone) {
      ChipTone.neutral => scheme.surfaceContainerHigh,
      ChipTone.mint => c.mint,
      ChipTone.peach => c.peach,
      ChipTone.sky => c.sky,
      ChipTone.gold => c.gold.withValues(alpha: 0.45),
    };
    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: width,
        height: width * 1.28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: TicketBorder(
                    color: c.edge,
                    notchFromBottom: width * 0.34,
                  ),
                  shadows: printShadow(c.edge),
                ),
                child: Material(
                  color: fill,
                  shape: TicketBorder(
                    color: c.edge,
                    notchFromBottom: width * 0.34,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: width * 0.34),
                    child: Center(
                      child: Icon(icon,
                          size: width * 0.38, color: scheme.onSurface),
                    ),
                  ),
                ),
              ),
            ),
            if (stamp != null)
              Positioned(
                left: -14,
                bottom: width * 0.06,
                child: Stamp(text: stamp!, color: c.like, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 5),
            width: i == active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? scheme.onSurface : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// DE | EN pill with an ink rim; the current language is filled with ink.
class _LanguageChip extends ConsumerWidget {
  const _LanguageChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.space8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.swipeColors.edge,
          width: AppSizes.edge,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final code in supportedLanguageCodes)
            Semantics(
              button: true,
              selected: code == current,
              child: GestureDetector(
                onTap: () => ref
                    .read(localeControllerProvider.notifier)
                    .setLanguage(code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: code == current
                        ? scheme.inverseSurface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: code == current
                          ? scheme.onInverseSurface
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
