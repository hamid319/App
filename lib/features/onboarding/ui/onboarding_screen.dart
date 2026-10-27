import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/locale_controller.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/tripfam_mark.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/services/preferences_service.dart';
import '../../../l10n/l10n.dart';

/// Three pages, one per promise of TripFam: plan together, get a day plan,
/// split costs. Each has a small drawn scene in the brand colours.
const _pageCount = 3;

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

  bool get _isLast => _currentPage == _pageCount - 1;

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
              itemCount: _pageCount,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) => _OnboardingPage(
                index: i,
                lead: pages[i].$1,
                accent: pages[i].$2,
                body: pages[i].$3,
              ),
            ),
            // Logo top left, language top right, on every page.
            const Positioned(
              top: 0,
              left: AppSizes.space24,
              right: AppSizes.screenEdge,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(top: AppSizes.space8),
                  child: Row(
                    children: [
                      TripFamMark(size: 40),
                      Spacer(),
                      _LanguageChip(),
                    ],
                  ),
                ),
              ),
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
                      _Dots(count: _pageCount, active: _currentPage),
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
    required this.index,
    required this.lead,
    required this.accent,
    required this.body,
  });

  final int index;
  final String lead;
  final String accent;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, box) {
      final textHeight = box.maxHeight * 0.46;
      return Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: box.maxHeight * 0.13,
            height: box.maxHeight * 0.38,
            child: Center(
              child: switch (index) {
                0 => const _PlanScene(),
                1 => const _MapScene(),
                _ => const _CostScene(),
              },
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
                        // Coral underline: navy is kept for the button.
                        TextSpan(
                          text: accent,
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: BrandColors.coral,
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

/// White rounded card with a soft shadow, slightly tilted.
class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.child,
    this.angle = 0,
    this.width = 220,
  });

  final Widget child;
  final double angle;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(AppSizes.space12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1F2A6B),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// A rounded grey bar standing in for a line of text.
class _Line extends StatelessWidget {
  const _Line({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Page 1: a wishlist idea with likes, and a poll with a clear winner.
class _PlanScene extends StatelessWidget {
  const _PlanScene();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget pollRow(double share, bool winner) => Padding(
          padding: const EdgeInsets.only(top: AppSizes.space8),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (share * 100).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: winner
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Expanded(flex: 100 - (share * 100).round(), child: const SizedBox()),
              ],
            ),
          ),
        );
    return SizedBox(
      width: 320,
      height: 240,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            child: _SceneCard(
              angle: -0.06,
              width: 210,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BrandColors.sky,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.museum_rounded,
                        color: BrandColors.navy),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Line(width: 90),
                        SizedBox(height: 6),
                        _Line(width: 60),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BrandColors.coral.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        size: 16, color: BrandColors.coral),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: _SceneCard(
              angle: 0.05,
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Line(width: 120),
                  pollRow(0.72, true),
                  pollRow(0.28, false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 2: numbered stops joined by a walking route on a small map.
class _MapScene extends StatelessWidget {
  const _MapScene();

  @override
  Widget build(BuildContext context) {
    return _SceneCard(
      width: 290,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _RoutePainter(
              land: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            child: const Stack(
              children: [
                Positioned(left: 26, top: 120, child: _StopDot(number: 1)),
                Positioned(left: 118, top: 62, child: _StopDot(number: 2)),
                Positioned(left: 214, top: 28, child: _StopDot(number: 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BrandColors.navy,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.land});

  final Color land;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    // River and a park, so it reads as a map.
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.82)
        ..quadraticBezierTo(size.width * 0.5, size.height * 0.68,
            size.width, size.height * 0.86)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = BrandColors.sky,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.5, 70, 40),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFCFE8C9),
    );
    final route = Path()
      ..moveTo(41, 135)
      ..cubicTo(70, 100, 100, 90, 133, 77)
      ..cubicTo(170, 62, 200, 52, 229, 43);
    canvas.drawPath(
      route,
      Paint()
        ..color = BrandColors.coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.land != land;
}

/// Page 3: one person paid, the others settle up.
class _CostScene extends StatelessWidget {
  const _CostScene();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget person(Color color) => Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.person_rounded, color: Colors.white),
        );
    Widget transfer(Color from) => Padding(
          padding: const EdgeInsets.only(top: AppSizes.space12),
          child: Row(
            children: [
              person(from),
              const SizedBox(width: AppSizes.space8),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSizes.space8),
              person(BrandColors.navy),
            ],
          ),
        );
    return _SceneCard(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.swipeColors.mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.euro_rounded, color: scheme.onSurface),
              ),
              const SizedBox(width: AppSizes.space12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Line(width: 110),
                    SizedBox(height: 6),
                    _Line(width: 70),
                  ],
                ),
              ),
            ],
          ),
          transfer(BrandColors.coral),
          transfer(const Color(0xFF0E9F7E)),
        ],
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
              color: i == active ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// DE | EN pill; the current language is filled with the tint.
class _LanguageChip extends ConsumerWidget {
  const _LanguageChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surface,
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: code == current ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: code == current
                          ? scheme.onPrimary
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
