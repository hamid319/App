import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/models/place_model.dart';
import '../logic/swipe_controller.dart';
import 'dart:math' as math;

/// Main Swipe Screen - displays the card stack and handles state
class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(swipeControllerProvider);
    final ctrl = ref.read(swipeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Places'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Badge(
                label: Text('${ctrl.favoritesList.length}'),
                child: const Icon(Icons.favorite),
              ),
            ),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(swipeControllerProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (places) {
          final current = ctrl.currentPlace;
          if (current == null) {
            // No more places to show
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  const SizedBox(height: 24),
                  Text(
                    'No more places!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have viewed all places',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(swipeControllerProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload'),
                  ),
                ],
              ),
            );
          }
          
          // Build the swipeable card stack
          return TinderSwipeCardStack(
            place: current,
            onLike: () {
              ctrl.like();
              _showSnackBar(context, 'Added to favorites!', Colors.green);
            },
            onSkip: () {
              ctrl.skip();
              _showSnackBar(context, 'Skipped', Colors.orange);
            },
            onDetail: () {
              context.push('/place/${current.id}');
            },
          );
        },
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// =============================================================================
// TINDER SWIPE CARD STACK - The main swipeable component
// =============================================================================

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
  
  // ============ ANIMATION CONTROLLERS ============
  
  /// Controls the card's position during drag and fly-off animation
  late AnimationController _swipeController;
  
  /// Controls the button press animation
  late AnimationController _buttonController;
  
  // ============ POSITION & ROTATION STATE ============
  
  /// Current horizontal offset of the card (updated during drag)
  double _dragX = 0;
  
  /// Current vertical offset of the card (updated during drag)
  double _dragY = 0;
  
  /// Tracks if we're currently animating a swipe-off
  bool _isAnimating = false;
  
  // ============ SWIPE THRESHOLDS ============
  
  /// How far the card must be dragged to trigger a swipe (as fraction of screen width)
  static const double _swipeThreshold = 0.3;
  
  /// Maximum rotation angle in radians when card is at edge
  static const double _maxRotation = 0.3;
  
  // ============ ANIMATIONS ============
  
  /// Animation for flying the card off screen
  Animation<Offset>? _flyOffAnimation;

  @override
  void initState() {
    super.initState();
    
    // Swipe animation controller - controls the fly-off effect
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Button animation controller - for button press feedback
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
  
  /// Reset card position when a new place is shown
  @override
  void didUpdateWidget(TinderSwipeCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id) {
      // New card - reset position
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isAnimating = false;
      });
      _swipeController.reset();
    }
  }

  // ============ GESTURE HANDLERS ============
  
  /// Called when user starts dragging the card
  void _onPanStart(DragStartDetails details) {
    if (_isAnimating) return;
  }
  
  /// Called continuously as user drags the card
  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    
    setState(() {
      // Update card position based on finger movement
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;
    });
  }
  
  /// Called when user releases the card
  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * _swipeThreshold;
    
    // Check if card was dragged past the threshold
    if (_dragX.abs() > threshold) {
      // Swipe detected - fly card off screen
      _animateCardOff(_dragX > 0);
    } else {
      // Threshold not met - snap back to center
      _snapBack();
    }
  }
  
  // ============ ANIMATION METHODS ============
  
  /// Animate the card flying off the screen
  void _animateCardOff(bool toRight) {
    _isAnimating = true;
    
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate the end position (off-screen)
    // Card flies in the direction it was swiped, with some vertical motion
    final endX = toRight ? screenWidth * 1.5 : -screenWidth * 1.5;
    final endY = _dragY + (toRight ? 100 : -100);
    
    // Create the fly-off animation
    _flyOffAnimation = Tween<Offset>(
      begin: Offset(_dragX, _dragY),
      end: Offset(endX, endY),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));
    
    // Listen for animation updates to rebuild
    _swipeController.addListener(_onSwipeAnimationUpdate);
    
    // When animation completes, trigger the callback
    _swipeController.forward().then((_) {
      _swipeController.removeListener(_onSwipeAnimationUpdate);
      
      // Call the appropriate callback
      if (toRight) {
        widget.onLike();
      } else {
        widget.onSkip();
      }
      
      // Reset state for next card
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isAnimating = false;
      });
      _swipeController.reset();
    });
  }
  
  /// Callback for animation updates
  void _onSwipeAnimationUpdate() {
    if (_flyOffAnimation != null) {
      setState(() {
        _dragX = _flyOffAnimation!.value.dx;
        _dragY = _flyOffAnimation!.value.dy;
      });
    }
  }
  
  /// Animate card back to center position
  void _snapBack() {
    final startX = _dragX;
    final startY = _dragY;
    
    // Create snap-back animation
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
  
  /// Handle button-triggered like (right swipe)
  void _handleButtonLike() {
    if (_isAnimating) return;
    _animateCardOff(true);
  }
  
  /// Handle button-triggered skip (left swipe)
  void _handleButtonSkip() {
    if (_isAnimating) return;
    _animateCardOff(false);
  }
  
  // ============ BUILD METHOD ============

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate rotation based on horizontal drag
    // Card rotates slightly in the direction of the swipe
    final rotationAngle = (_dragX / screenWidth) * _maxRotation;
    
    // Calculate opacity for like/skip indicators
    final likeOpacity = (_dragX / (screenWidth * _swipeThreshold)).clamp(0.0, 1.0);
    final skipOpacity = (-_dragX / (screenWidth * _swipeThreshold)).clamp(0.0, 1.0);
    
    return Column(
      children: [
        // ============ CARD STACK AREA ============
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background placeholder card (creates depth effect)
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
                
                // ============ TOP SWIPEABLE CARD ============
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
                        // The actual card
                        _buildPlaceCard(),
                        
                        // ============ LIKE INDICATOR (Green) ============
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
                        
                        // ============ SKIP INDICATOR (Red) ============
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
        
        // ============ ACTION BUTTONS ============
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Skip Button (X)
              _ActionButton(
                icon: Icons.close,
                color: Colors.red,
                onPressed: _handleButtonSkip,
                label: 'Skip',
              ),
              const SizedBox(width: 24),
              // Like Button (Heart)
              _ActionButton(
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
  
  /// Builds the main place card with image and content
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
              // Background image or gradient
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
                child: widget.place.images.isNotEmpty
                    ? Image.network(
                        widget.place.images.first,
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
              
              // Gradient overlay for text readability
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
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Place name
                      Text(
                        widget.place.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Place description
                      Text(
                        widget.place.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Tags
                      if (widget.place.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.place.tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
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
              
              // Info button
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
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

// =============================================================================
// ACTION BUTTON WIDGET
// =============================================================================

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String label;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.label,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _handleTap,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: TextStyle(
              color: widget.color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
