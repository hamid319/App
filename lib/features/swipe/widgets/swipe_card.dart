import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../common/models/place_model.dart';
import 'swipe_buttons.dart';

class TinderSwipeCardStack extends StatefulWidget {
  final PlaceModel place;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onDetail;

  const TinderSwipeCardStack({
    super.key,
    required this.place,
    required this.onLike,
    required this.onSkip,
    required this.onDetail,
  });

  @override
  State<TinderSwipeCardStack> createState() => _TinderSwipeCardStackState();
}

class _TinderSwipeCardStackState extends State<TinderSwipeCardStack>
    with TickerProviderStateMixin {
  late AnimationController _swipeController;
  late AnimationController _buttonController;

  double _dragX = 0;
  double _dragY = 0;
  bool _isAnimating = false;

  static const double _swipeThreshold = 0.3;
  static const double _maxRotation = 0.3;

  Animation<Offset>? _flyOffAnimation;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TinderSwipeCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id) {
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isAnimating = false;
      });
      _swipeController.reset();
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating) return;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * _swipeThreshold;

    if (_dragX.abs() > threshold) {
      _animateCardOff(_dragX > 0);
    } else {
      _snapBack();
    }
  }

  void _animateCardOff(bool toRight) {
    _isAnimating = true;
    final screenWidth = MediaQuery.of(context).size.width;

    final endX = toRight ? screenWidth * 1.5 : -screenWidth * 1.5;
    final endY = _dragY + (toRight ? 100 : -100);

    _flyOffAnimation = Tween<Offset>(
      begin: Offset(_dragX, _dragY),
      end: Offset(endX, endY),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));

    _swipeController.addListener(_onSwipeAnimationUpdate);

    _swipeController.forward().then((_) {
      _swipeController.removeListener(_onSwipeAnimationUpdate);

      if (toRight) {
        widget.onLike();
      } else {
        widget.onSkip();
      }

      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isAnimating = false;
      });
      _swipeController.reset();
    });
  }

  void _onSwipeAnimationUpdate() {
    if (_flyOffAnimation != null) {
      setState(() {
        _dragX = _flyOffAnimation!.value.dx;
        _dragY = _flyOffAnimation!.value.dy;
      });
    }
  }

  void _snapBack() {
    final startX = _dragX;
    final startY = _dragY;

    final animation = Tween<Offset>(
      begin: Offset(startX, startY),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.elasticOut,
    ));

    void listener() {
      setState(() {
        _dragX = animation.value.dx;
        _dragY = animation.value.dy;
      });
    }

    _swipeController.addListener(listener);
    _swipeController.forward().then((_) {
      _swipeController.removeListener(listener);
      _swipeController.reset();
    });
  }

  void _handleButtonLike() {
    if (_isAnimating) return;
    _animateCardOff(true);
  }

  void _handleButtonSkip() {
    if (_isAnimating) return;
    _animateCardOff(false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rotationAngle = (_dragX / screenWidth) * _maxRotation;
    final likeOpacity =
        (_dragX / (screenWidth * _swipeThreshold)).clamp(0.0, 1.0);
    final skipOpacity =
        (-_dragX / (screenWidth * _swipeThreshold)).clamp(0.0, 1.0);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Transform.scale(
                    scale: 0.95,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.place, size: 60, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onTap: widget.onDetail,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setTranslationRaw(_dragX, _dragY, 0)
                      ..rotateZ(rotationAngle),
                    child: Stack(
                      children: [
                        _buildPlaceCard(),
                        if (likeOpacity > 0)
                          Positioned(
                            top: 40,
                            left: 30,
                            child: Opacity(
                              opacity: likeOpacity,
                              child: Transform.rotate(
                                angle: -math.pi / 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'LIKE',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (skipOpacity > 0)
                          Positioned(
                            top: 40,
                            right: 30,
                            child: Opacity(
                              opacity: skipOpacity,
                              child: Transform.rotate(
                                angle: math.pi / 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'NOPE',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ActionButton(
                icon: Icons.close,
                color: Colors.red,
                onPressed: _handleButtonSkip,
                label: 'Skip',
              ),
              const SizedBox(width: 24),
              ActionButton(
                icon: Icons.favorite,
                color: Colors.green,
                onPressed: _handleButtonLike,
                label: 'Like',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard() {
    return SizedBox(
      width: MediaQuery.of(context).size.width - 32,
      height: double.infinity,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade400,
                      Colors.purple.shade400,
                    ],
                  ),
                ),
                child: widget.place.imageUrls.isNotEmpty
                    ? Image.network(
                        widget.place.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                    : _buildPlaceholder(),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.place.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.place.description ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.place.types.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.place.types
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: widget.onDetail,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.place,
          size: 80,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
