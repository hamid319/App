import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/locale_controller.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/services/preferences_service.dart';
import '../../../l10n/l10n.dart';

/// A scene is a warm gradient with two tilted "photo" cards floating on it.
/// Placeholders until real destination photos are bundled.
class _Scene {
  const _Scene(this.colors, this.cardA, this.cardB, this.iconA, this.iconB);

  final List<Color> colors;
  final List<Color> cardA;
  final List<Color> cardB;
  final IconData iconA;
  final IconData iconB;
}

const _scenes = [
  _Scene(
    [Color(0xFFFFB98A), Color(0xFFFF6F6B), Color(0xFF5B4E9E)],
    [Color(0xFF7FD1C7), Color(0xFF2A7FA8)],
    [Color(0xFFFFD39A), Color(0xFFE2725B)],
    Icons.landscape_rounded,
    Icons.beach_access_rounded,
  ),
  _Scene(
    [Color(0xFFFFC371), Color(0xFFFF5F6D), Color(0xFFB0306A)],
    [Color(0xFFA1C4FD), Color(0xFF5A6FD6)],
    [Color(0xFFFFE29F), Color(0xFFFF9A6A)],
    Icons.museum_rounded,
    Icons.local_florist_rounded,
  ),
  _Scene(
    [Color(0xFF7FD1C7), Color(0xFF3B8EA5), Color(0xFF2B3A67)],
    [Color(0xFFFFB98A), Color(0xFFFF6F6B)],
    [Color(0xFFD4FC79), Color(0xFF51B17F)],
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
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
            // Sits on the photo so it is visible on every page.
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
                        child: FilledButton(
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
    return LayoutBuilder(builder: (context, box) {
      final sheetHeight = box.maxHeight * 0.48;
      return Stack(
        children: [
          Positioned.fill(
            bottom: sheetHeight - AppSizes.radiusLg,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: scene.colors,
                ),
              ),
            ),
          ),
          Positioned(
            left: 26,
            top: box.maxHeight * 0.17,
            child: _FloatingCard(
              colors: scene.cardA,
              icon: scene.iconA,
              angle: -0.1,
              width: 128,
            ),
          ),
          Positioned(
            right: 28,
            top: box.maxHeight * 0.12,
            child: _FloatingCard(
              colors: scene.cardB,
              icon: scene.iconB,
              angle: 0.12,
              width: 116,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: sheetHeight,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSizes.space24,
                AppSizes.space32,
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
                        TextSpan(
                          text: accent,
                          style: TextStyle(color: scheme.primary),
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

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.colors,
    required this.icon,
    required this.angle,
    required this.width,
  });

  final List<Color> colors;
  final IconData icon;
  final double angle;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: width * 1.28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 3),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              spreadRadius: -10,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Icon(icon, size: width * 0.38, color: Colors.white70),
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

/// DE | EN pill on dark glass, readable on every scene.
class _LanguageChip extends ConsumerWidget {
  const _LanguageChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = Localizations.localeOf(context).languageCode;
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.space8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
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
                    color: code == current ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: code == current
                          ? const Color(0xFF15171C)
                          : Colors.white,
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
