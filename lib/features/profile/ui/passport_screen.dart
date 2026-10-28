import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../common/models/user_model.dart';
import '../../../common/utils/passport_mrz.dart';
import '../../../common/utils/passport_stamps.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/tripfam_mark.dart';
import '../../../common/widgets/widget_capture.dart';
import '../../../core/constants/colors.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/preferences_service.dart';
import '../../../l10n/l10n.dart';
import '../../../main_providers.dart';
import '../logic/passport_controller.dart';
import '../logic/profile_controller.dart';
import '../widgets/passport_stamp_view.dart';

const _stampsPerPage = 4;
const _paper = Color(0xFFF7F3E8);
const _gold = Color(0xFFE8C46A);
const _navyDark = Color(0xFF141C4D);
const _openDuration = Duration(milliseconds: 900);
const _turnDuration = Duration(milliseconds: 550);
const _ink = Color(0xFF8C8577);

/// The shared picture: Instagram story format.
const _shareSize = Size(1080, 1920);

/// A page at the size it has on a phone; the share card scales it up.
const _pageSize = Size(340, 483);

/// The passport: a booklet that opens, pages to leaf through, and a stamp
/// per city. Stamps the user has not seen yet are pressed onto the page.
class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({super.key});

  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen>
    with TickerProviderStateMixin {
  late final _open = AnimationController(vsync: this, duration: _openDuration);

  /// Position in the booklet: 1.5 is halfway through turning page 2.
  late final _flip = AnimationController.unbounded(vsync: this);

  /// Stamps new since the last visit; null until loaded.
  Set<String>? _fresh;
  final _played = <String>{};
  bool _loadingSeen = false;
  bool _sharing = false;

  @override
  void dispose() {
    _open.dispose();
    _flip.dispose();
    super.dispose();
  }

  Future<void> _loadSeen(String uid, List<PassportStamp> stamps) async {
    _loadingSeen = true;
    final seen = await PreferencesService.getSeenStamps(uid);
    final all = stamps.map((s) => s.cityId).toSet();
    await PreferencesService.setSeenStamps(uid, {...seen, ...all});
    if (!mounted) return;
    setState(() => _fresh = all.difference(seen));
    // Leaf to the first page with a new stamp once the cover is open.
    final first = stamps.indexWhere((s) => !seen.contains(s.cityId));
    if (first < 0) return;
    void leaf() => _turnTo((first ~/ _stampsPerPage + 1).toDouble());
    if (_open.isCompleted) return leaf();
    void onStatus(AnimationStatus s) {
      if (s != AnimationStatus.completed) return;
      _open.removeStatusListener(onStatus);
      if (mounted) leaf();
    }

    _open.addStatusListener(onStatus);
  }

  void _turnTo(double page) {
    // A soft click as a page settles on another one.
    if (page != _flip.value.roundToDouble()) HapticFeedback.selectionClick();
    _flip.animateTo(page, duration: _turnDuration, curve: Curves.easeOutCubic);
  }

  void _openCover() {
    if (!_open.isDismissed) return;
    HapticFeedback.lightImpact();
    _open.forward();
  }

  void _onDragEnd(DragEndDetails d, int pages) {
    final v = d.primaryVelocity ?? 0;
    // The cover opens with a swipe to the left and closes again with a
    // swipe to the right on the first page.
    if (!_open.isCompleted) {
      if (v < 0) _openCover();
      return;
    }
    if (_flip.value == 0 && v > 300) {
      _open.reverse();
      return;
    }
    final target = v < -300
        ? _flip.value.floorToDouble() + 1
        : v > 300
            ? _flip.value.ceilToDouble() - 1
            : _flip.value.roundToDouble();
    _turnTo(target.clamp(0, pages - 1).toDouble());
  }

  /// Shares the open page (or the cover, while closed) as a story-sized
  /// picture with the TripFam brand and the travel numbers.
  Future<void> _share(List<PassportStamp> stamps, UserModel? user) async {
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final pages = stamps.length ~/ _stampsPerPage + 2;
    final at = _open.isCompleted ? _flip.value.round().clamp(0, pages - 1) : -1;
    final Widget page = at < 0
        ? _Cover(name: user?.displayName, stamps: stamps.length)
        : at == 0
            ? _DataPage(user: user, stamps: stamps)
            : _PassportPage(
                index: at,
                stamps: stamps
                    .skip((at - 1) * _stampsPerPage)
                    .take(_stampsPerPage)
                    .toList(),
                showNext: false,
                empty: stamps.isEmpty,
                isFresh: (_) => false,
                onPlayed: (_) {},
                delayBase: 0,
              );
    final countries = stamps
        .map((s) => s.countryCode)
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
    setState(() => _sharing = true);
    try {
      final photo = user?.photoUrl;
      // The capture must not catch an empty photo box.
      if (at == 0 && photo != null) {
        await precacheImage(CachedNetworkImageProvider(photo), context);
      }
      if (!mounted) return;
      final png = await captureWidget(
        context,
        _PassportShareCard(
          page: page,
          title: l10n.passportShareTitle,
          stats: l10n.passportShareStats(countries, stamps.length),
          tagline: l10n.passportShareTagline,
        ),
        _shareSize,
      );
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(png,
              mimeType: 'image/png', name: 'tripfam-passport.png'),
        ],
        sharePositionOrigin: origin,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              userMessage(e, fallback: l10n.passportShareError, l10n: l10n)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stamps = ref.watch(passportStampsProvider);
    final account = ref.watch(currentAccountProvider).value;
    final list = stamps.value;
    if (account != null && list != null && _fresh == null && !_loadingSeen) {
      _loadSeen(account.uid, list);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passportTitle),
        actions: [
          if (list != null)
            IconButton(
              tooltip: l10n.passportShare,
              onPressed: _sharing
                  ? null
                  : () =>
                      _share(list, ref.read(profileControllerProvider).value),
              icon: _sharing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share_rounded),
            ),
        ],
      ),
      body: stamps.hasError
          ? ErrorView(
              message: userMessage(stamps.error!,
                  fallback: l10n.errorGeneric, l10n: l10n),
              onRetry: () => ref.invalidate(myTripsProvider),
            )
          : list == null
              ? const Center(child: CircularProgressIndicator())
              : _book(
                  context, list, ref.watch(profileControllerProvider).value),
    );
  }

  Widget _book(
      BuildContext context, List<PassportStamp> stamps, UserModel? user) {
    final name = user?.displayName;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // The data page, then stamp pages with always room for the next stamp.
    final pages = stamps.length ~/ _stampsPerPage + 2;

    return LayoutBuilder(builder: (context, box) {
      final width = math.min(box.maxWidth - 48, 380.0);
      final height = math.min(width * 1.42, box.maxHeight - 96);

      Widget page(int i) => i == 0
          ? _DataPage(user: user, stamps: stamps)
          : _PassportPage(
              index: i,
              stamps: stamps
                  .skip((i - 1) * _stampsPerPage)
                  .take(_stampsPerPage)
                  .toList(),
              showNext: i == pages - 1,
              empty: stamps.isEmpty,
              isFresh: (s) =>
                  (_fresh?.contains(s.cityId) ?? false) &&
                  !_played.contains(s.cityId),
              onPlayed: (s) => _played.add(s.cityId),
              // Before the cover is open, wait for it and the turn from the
              // data page to this one.
              delayBase: _open.isCompleted
                  ? 450
                  : (_openDuration + _turnDuration).inMilliseconds + 300,
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: double.infinity),
          const Spacer(),
          GestureDetector(
            onTap: _openCover,
            onHorizontalDragUpdate: (d) {
              if (!_open.isCompleted) return;
              _flip.value = (_flip.value - d.primaryDelta! / width)
                  .clamp(0, pages - 1)
                  .toDouble();
            },
            onHorizontalDragEnd: (d) => _onDragEnd(d, pages),
            child: _Tilt(
              width: width,
              height: height,
              child: AnimatedBuilder(
                animation: Listenable.merge([_flip, _open]),
                builder: (context, _) {
                  final at = _flip.value.clamp(0, pages - 1).toDouble();
                  final i = at.floor();
                  final turn = at - i;
                  final open = Curves.easeInOutCubic.transform(_open.value);
                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      // Back cover and page edges, for the book's thickness.
                      for (final k in const [3, 2, 1])
                        Transform.translate(
                          offset: Offset(k * 1.6, k * 1.6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: k == 3
                                  ? _navyDark
                                  : Color.lerp(_paper, Colors.black, 0.07 * k),
                              borderRadius: _pageRadius,
                            ),
                          ),
                        ),
                      // Pages exist only once the cover lifts, so new
                      // stamps are pressed on when they can be seen.
                      if (open > 0) ...[
                        if (i + 1 < pages)
                          _Shaded(
                              amount: (1 - turn) * 0.18, child: page(i + 1)),
                        _Turning(
                            amount: turn, key: ValueKey(i), child: page(i)),
                      ],
                      if (open < 1)
                        _Turning(
                          amount: open,
                          child: _Cover(name: name, stamps: stamps.length),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: Listenable.merge([_flip, _open]),
            builder: (context, _) => Text(
              _open.isDismissed
                  ? l10n.passportTapToOpen
                  : l10n.passportPage(_flip.value.round() + 1, pages),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const Spacer(flex: 2),
        ],
      );
    });
  }
}

/// Turns [child] over its left edge (the spine), lifting its free edge
/// towards the viewer: 0 flat, 1 standing upright at the spine.
class _Turning extends StatelessWidget {
  const _Turning({super.key, required this.amount, required this.child});

  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (amount >= 1) return const SizedBox.shrink();
    // Mild perspective: the free edge comes towards the viewer, and with a
    // strong one it would swell across the screen near the end. The page
    // fades over the last part of the turn for the same reason.
    return Opacity(
      opacity: (1 - (amount - 0.6) / 0.4).clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0006)
          ..rotateY(amount * math.pi / 2),
        child: _Shaded(
          amount: amount * 0.3,
          child: Stack(fit: StackFit.expand, children: [
            child,
            // Light catching the page as it lifts.
            if (amount > 0)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _pageRadius,
                    gradient: LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white
                          .withValues(alpha: math.sin(amount * math.pi) * 0.25),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Holds the booklet in 3D: it sways gently on its own and leans towards
/// the finger while touched; the shadow below moves the other way.
class _Tilt extends StatefulWidget {
  const _Tilt({required this.width, required this.height, required this.child});

  final double width;
  final double height;
  final Widget child;

  @override
  State<_Tilt> createState() => _TiltState();
}

class _TiltState extends State<_Tilt> with SingleTickerProviderStateMixin {
  late final _idle =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))
        ..repeat();
  Offset? _touch;
  Offset _lean = Offset.zero;

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _track(Offset local) => _touch = Offset(
        (local.dx / widget.width * 2 - 1).clamp(-1, 1),
        (local.dy / widget.height * 2 - 1).clamp(-1, 1),
      );

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Listener(
      onPointerDown: (e) => _track(e.localPosition),
      onPointerMove: (e) => _track(e.localPosition),
      onPointerUp: (_) => _touch = null,
      onPointerCancel: (_) => _touch = null,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _idle,
          child: widget.child,
          builder: (context, child) {
            final t = _idle.value * 2 * math.pi;
            final target = _touch ??
                (still
                    ? Offset.zero
                    : Offset(math.sin(t) * 0.4, math.cos(t) * 0.3));
            // Ease towards the target so the lean never jumps.
            _lean = Offset.lerp(_lean, target, 0.12)!;
            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(-_lean.dx * 12, 18 - _lean.dy * 8),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: _pageRadius,
                      boxShadow: [
                        BoxShadow(
                            blurRadius: 30,
                            spreadRadius: -4,
                            color: Color(0x55000000)),
                      ],
                    ),
                  ),
                ),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateX(-_lean.dy * 0.12)
                    ..rotateY(_lean.dx * 0.14),
                  child: child,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Darkens a page lying in the shadow of the one being turned.
class _Shaded extends StatelessWidget {
  const _Shaded({required this.amount, required this.child});

  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return child;
    return Stack(fit: StackFit.expand, children: [
      child,
      IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _pageRadius,
            color: Colors.black.withValues(alpha: amount),
          ),
        ),
      ),
    ]);
  }
}

const _pageRadius = BorderRadius.horizontal(
  left: Radius.circular(4),
  right: Radius.circular(14),
);

class _Cover extends StatelessWidget {
  const _Cover({required this.name, required this.stamps});

  final String? name;
  final int stamps;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    TextStyle gold(double size, {double spacing = 0, FontWeight? weight}) =>
        TextStyle(
          color: _gold,
          fontSize: size,
          letterSpacing: spacing,
          fontWeight: weight,
        );
    // Gold foil: a metallic sweep instead of a flat colour.
    // Pressed into the cover: a dark edge below, a faint light edge above.
    Widget foil(Text t) => Stack(children: [
          Transform.translate(
            offset: const Offset(0, 1.2),
            child: Text(t.data!,
                style: t.style!.copyWith(color: const Color(0x99000000))),
          ),
          Transform.translate(
            offset: const Offset(0, -0.6),
            child: Text(t.data!,
                style: t.style!.copyWith(color: const Color(0x22FFFFFF))),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFB8913A), Color(0xFFF7E3A1), Color(0xFFC79E45)],
              stops: [0, 0.5, 1],
            ).createShader(r),
            child: t,
          ),
        ]);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BrandColors.navy,
        borderRadius: _pageRadius,
      ),
      child: Stack(fit: StackFit.expand, children: [
        // Embossed gold frame, like the border on a real passport.
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            border: Border.all(color: _gold.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
          child: Column(
            children: [
              foil(Text(l10n.passportCoverTitle,
                  style: gold(20, spacing: 6, weight: FontWeight.w700))),
              const SizedBox(height: 4),
              foil(Text(l10n.passportCoverSubtitle,
                  style: gold(11, spacing: 3))),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: const TripFamMark(size: 96),
              ),
              const SizedBox(height: 24),
              if (name != null && name!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(name!, style: gold(13)),
              ],
              const Spacer(),
              Text(l10n.passportStampCount(stamps).toUpperCase(),
                  style: gold(11, spacing: 2)),
              const SizedBox(height: 12),
              // The e-passport chip symbol.
              Container(
                width: 34,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: _gold, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        // The spine: a darker band with the crease of the binding.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(4)),
              gradient: LinearGradient(colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.05),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          bottom: 0,
          width: 1,
          child: ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
        ),
        // Thread stitching along the binding.
        Positioned(
          left: 18,
          top: 10,
          bottom: 10,
          width: 1.5,
          child: CustomPaint(
              painter: _Stitches(color: _gold.withValues(alpha: 0.45))),
        ),
        // Gloss of the plastic cover.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _pageRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.25, 0.42, 0.6],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PassportPage extends StatelessWidget {
  const _PassportPage({
    required this.index,
    required this.stamps,
    required this.showNext,
    required this.empty,
    required this.isFresh,
    required this.onPlayed,
    required this.delayBase,
  });

  final int index;
  final List<PassportStamp> stamps;
  final bool showNext;
  final bool empty;

  /// New and not pressed on yet this visit.
  final bool Function(PassportStamp) isFresh;
  final void Function(PassportStamp) onPlayed;
  final int delayBase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    var pressed = 0;
    Widget cell(int slot, double size) {
      if (slot < stamps.length) {
        final s = stamps[slot];
        final seed = s.seed;
        final jitter = Alignment(
          ((seed >> 18) % 41 - 20) / 50,
          ((seed >> 24) % 41 - 20) / 50,
        );
        final play = isFresh(s);
        return Align(
          alignment: jitter,
          child: StampPress(
            key: ValueKey(s.cityId),
            play: play,
            onPlay: () => onPlayed(s),
            delay: Duration(
                milliseconds: delayBase + 420 * (play ? pressed++ : 0)),
            child: PassportStampView(stamp: s, size: size),
          ),
        );
      }
      if (slot == stamps.length && showNext) {
        return Center(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ink.withValues(alpha: 0.4)),
            ),
            child: Text(
              l10n.passportNextStamp,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _ink, fontSize: 12),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _paper,
        borderRadius: _pageRadius,
      ),
      child: Stack(fit: StackFit.expand, children: [
        _paperPattern(index),
        // The fold at the spine: paper curves away into shadow.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 26,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(4)),
                gradient: LinearGradient(colors: [
                  Colors.black.withValues(alpha: 0.16),
                  Colors.black.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: LayoutBuilder(builder: (context, box) {
            final cellW = box.maxWidth / 2;
            final cellH = (box.maxHeight - 48) / 2;
            final size = math.min(cellW / 1.5, cellH * 0.8);
            return Column(
              children: [
                Row(
                  children: [
                    Text(l10n.passportPageTitle,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${index + 1}',
                        style: const TextStyle(color: _ink, fontSize: 11)),
                  ],
                ),
                const Divider(color: Color(0x338C8577), height: 16),
                for (final row in [0, 1])
                  Expanded(
                    child: Row(
                      children: [
                        for (final col in [0, 1])
                          Expanded(child: cell(row * 2 + col, size)),
                      ],
                    ),
                  ),
                if (empty)
                  Text(
                    l10n.passportEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _ink, fontSize: 13),
                  ),
              ],
            );
          }),
        ),
      ]),
    );
  }
}

/// Security pattern of a page; behind the stamps, never repainted.
Widget _paperPattern(int seed) => Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(painter: _Guilloche(color: _ink, seed: seed)),
        ),
      ),
    );

/// Guilloche: the fine interlaced lines printed on passports and bank
/// notes. A rosette in the middle and wave bands at top and bottom.
class _Guilloche extends CustomPainter {
  const _Guilloche({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: 0.09);

    // Rosette (a hypotrochoid), turned a little differently on each page.
    final c = size.center(Offset.zero);
    final scale = size.shortestSide * 0.34;
    const big = 1.0, small = 0.2875, arm = 0.62;
    final turn = seed * 0.37;
    final rosette = Path();
    for (var i = 0; i <= 1400; i++) {
      final t = i / 1400 * 2 * math.pi * 23;
      final x = (big - small) * math.cos(t) +
          arm * math.cos((big - small) / small * t);
      final y = (big - small) * math.sin(t) -
          arm * math.sin((big - small) / small * t);
      final q = Offset(x, y) * scale / (big - small + arm);
      final p = c +
          Offset(q.dx * math.cos(turn) - q.dy * math.sin(turn),
              q.dx * math.sin(turn) + q.dy * math.cos(turn));
      i == 0 ? rosette.moveTo(p.dx, p.dy) : rosette.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(rosette, pen);

    // Interlaced waves along the top and bottom edges.
    for (final band in [size.height * 0.1, size.height * 0.9]) {
      for (var k = 0; k < 6; k++) {
        final wave = Path();
        for (var x = 0.0; x <= size.width; x += 2) {
          final y = band +
              math.sin(x / size.width * math.pi * 6 + k * 0.9 + seed) * 9 +
              math.sin(x / size.width * math.pi * 17 + k) * 2;
          x == 0 ? wave.moveTo(x, y) : wave.lineTo(x, y);
        }
        canvas.drawPath(wave, pen);
      }
    }
  }

  @override
  bool shouldRepaint(_Guilloche old) => old.seed != seed || old.color != color;
}

/// Dashes of thread down a binding.
class _Stitches extends CustomPainter {
  const _Stitches({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += 9) {
      canvas.drawLine(
          Offset(x, y), Offset(x, math.min(y + 5, size.height)), pen);
    }
  }

  @override
  bool shouldRepaint(_Stitches old) => old.color != color;
}

/// The data page: who holds the passport, laid out like a real one, with
/// the machine-readable lines at the foot.
class _DataPage extends StatelessWidget {
  const _DataPage({required this.user, required this.stamps});

  final UserModel? user;
  final List<PassportStamp> stamps;

  static const _label = TextStyle(color: _ink, fontSize: 9, letterSpacing: 1.2);
  static const _value = TextStyle(
      color: Color(0xFF2B2A33), fontSize: 14, fontWeight: FontWeight.w600);

  Widget _field(String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: _label),
            const SizedBox(height: 1),
            Text(text,
                style: _value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final user = this.user;
    final given = user?.displayName?.trim() ?? '';
    final name = given.isNotEmpty ? given : l10n.userFallbackName;
    final since = user?.createdAt ?? DateTime.now();
    final countries = stamps
        .map((s) => s.countryCode)
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
    final (mrz1, mrz2) =
        passportMrz(name: name, uid: user?.uid ?? '', issued: since);
    final header = _label.copyWith(fontSize: 11, fontWeight: FontWeight.w700);

    const photoW = 92.0, photoH = 116.0;
    final avatar = Center(
        child:
            MemberAvatar(id: user?.uid ?? '', name: name, size: photoW * 0.8));
    final photo = user?.photoUrl != null
        ? CachedNetworkImage(
            imageUrl: user!.photoUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => avatar,
          )
        : avatar;

    return DecoratedBox(
      decoration: const BoxDecoration(color: _paper, borderRadius: _pageRadius),
      child: Stack(fit: StackFit.expand, children: [
        _paperPattern(0),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text(l10n.passportCoverTitle, style: header),
                const Spacer(),
                Text('TFM', style: header),
              ]),
              const Divider(color: Color(0x338C8577), height: 16),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: photoW,
                    height: photoH,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9E4D6),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x338C8577)),
                    ),
                    child: photo,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(l10n.passportDataName, name),
                        _field(l10n.passportDataSince,
                            DateFormat.yMMMd(locale).format(since)),
                        _field(l10n.passportDataNumber, mrz2.substring(0, 9)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _field(l10n.passportDataCountries, '$countries')),
                Expanded(
                    child: _field(l10n.passportDataCities, '${stamps.length}')),
              ]),
              const Spacer(),
              // Machine-readable zone, in the monospace type of real ones.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                color: const Color(0x0F000000),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$mrz1\n$mrz2',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontFamilyFallback: ['Menlo', 'monospace'],
                      fontSize: 13,
                      height: 1.35,
                      letterSpacing: 1,
                      color: Color(0xFF2B2A33),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// The picture shared from the passport: the page on navy, tilted like a
/// passport lying on a table, with the brand and the travel numbers.
/// Fixed colours, whatever the app theme.
class _PassportShareCard extends StatelessWidget {
  const _PassportShareCard({
    required this.page,
    required this.title,
    required this.stats,
    required this.tagline,
  });

  final Widget page;
  final String title;
  final String stats;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    const pageWidth = 820.0;
    return Material(
      color: BrandColors.navy,
      child: DecoratedBox(
        // A soft light behind the page.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.05),
            radius: 0.8,
            colors: [Color(0xFF2F3C8A), BrandColors.navy],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 140),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const TripFamMark(size: 96),
                ),
                const SizedBox(width: 28),
                const Text('TripFam',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1)),
              ],
            ),
            const SizedBox(height: 28),
            Text(title.toUpperCase(),
                style: const TextStyle(
                    color: _gold,
                    fontSize: 36,
                    letterSpacing: 10,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Transform.rotate(
              angle: -0.045,
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: _pageRadius,
                  boxShadow: [
                    BoxShadow(
                        blurRadius: 60,
                        offset: Offset(0, 30),
                        color: Color(0x66000000)),
                  ],
                ),
                child: SizedBox(
                  width: pageWidth,
                  height: pageWidth / _pageSize.width * _pageSize.height,
                  child: FittedBox(
                    child: SizedBox.fromSize(size: _pageSize, child: page),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(stats,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(tagline,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 34)),
            const SizedBox(height: 140),
          ],
        ),
      ),
    );
  }
}
