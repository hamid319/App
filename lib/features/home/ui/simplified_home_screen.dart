import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/models/place_model.dart';
import '../../swipe/logic/swipe_controller.dart';
import '../../swipe/data/places_repository.dart';

class SimplifiedHomeScreen extends ConsumerWidget {
  const SimplifiedHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Places'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.red),
            tooltip: 'Reset all places & favorites',
            onPressed: () => _confirmReset(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Consumer(
                builder: (context, ref, _) {
                  final favoritesCount = ref.read(swipeControllerProvider.notifier).favoritesList.length;
                  return GestureDetector(
                    onTap: () => _showFavoritesDialog(context, ref),
                    child: Badge(
                      label: Text('$favoritesCount'),
                      child: const Icon(Icons.favorite),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: const _SwipeContent(),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset'),
        content: const Text('Alle Places und Favoriten zurücksetzen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(swipeControllerProvider.notifier).resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alles zurückgesetzt!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showFavoritesDialog(BuildContext context, WidgetRef ref) {
    final favorites = ref.read(swipeControllerProvider.notifier).favoritesList;
    final repo = PlacesRepository();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Favorites'),
        content: SizedBox(
          width: double.maxFinite,
          child: favorites.isEmpty
              ? const Text('No favorites yet. Start swiping to add places!')
              : FutureBuilder<List<PlaceModel>>(
                  future: repo.loadNearbyPlaces(0, 0, useMock: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allPlaces = snapshot.data ?? [];
                    final favoritePlaces = allPlaces.where((p) => favorites.contains(p.id)).toList();
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: favoritePlaces.length,
                      itemBuilder: (context, index) {
                        final place = favoritePlaces[index];
                        return ListTile(
                          leading: const Icon(Icons.place),
                          title: Text(place.name),
                          subtitle: Text(place.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/place/${place.id}');
                          },
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SwipeContent extends ConsumerWidget {
  const _SwipeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(swipeControllerProvider);
    final ctrl = ref.read(swipeControllerProvider.notifier);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading places',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(swipeControllerProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (places) {
        final current = ctrl.currentPlace;
        if (current == null) {
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
                  'You have seen all places',
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
        return _SwipeCardStack(
          place: current,
          onLike: () {
            ctrl.like();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Added to favorites!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          },
          onSkip: () {
            ctrl.skip();
          },
          onDetail: () {
            context.push('/place/${current.id}');
          },
        );
      },
    );
  }
}

// Swipe card stack widget with drag gestures (same as original)
class _SwipeCardStack extends StatefulWidget {
  final PlaceModel place;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onDetail;

  const _SwipeCardStack({
    required this.place,
    required this.onLike,
    required this.onSkip,
    required this.onDetail,
  });

  @override
  State<_SwipeCardStack> createState() => _SwipeCardStackState();
}

class _SwipeCardStackState extends State<_SwipeCardStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;
  
  double _dragStartX = 0;
  double _dragStartY = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _resetAnimations();
  }

  @override
  void didUpdateWidget(covariant _SwipeCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id) {
      _controller.reset();
      _resetAnimations();
      _isAnimating = false;
    }
  }

  void _resetAnimations() {
    _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
    _rotationAnimation = const AlwaysStoppedAnimation(0.0);
    _opacityAnimation = const AlwaysStoppedAnimation(1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    if (_isAnimating) return;
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    final deltaX = details.globalPosition.dx - _dragStartX;
    final deltaY = details.globalPosition.dy - _dragStartY;
    final screenWidth = MediaQuery.of(context).size.width;
    
    final rotation = deltaX / screenWidth * 0.1;
    final opacity = 1.0 - (deltaX.abs() / screenWidth * 0.5).clamp(0.0, 0.5);
    
    setState(() {
      _slideAnimation = AlwaysStoppedAnimation(Offset(deltaX / screenWidth, deltaY / screenWidth));
      _rotationAnimation = AlwaysStoppedAnimation(rotation);
      _opacityAnimation = AlwaysStoppedAnimation(opacity);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimating) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final currentOffset = _slideAnimation.value.dx;
    
    const threshold = 0.3;
    final fastSwipe = velocity.abs() > 500;
    
    if (currentOffset > threshold || (velocity > 0 && fastSwipe)) {
      _swipeRight();
    } else if (currentOffset < -threshold || (velocity < 0 && fastSwipe)) {
      _swipeLeft();
    } else {
      _returnToCenter();
    }
  }

  void _animateOut(Offset targetOffset, double targetRotation, VoidCallback onComplete) {
    _isAnimating = true;
    _controller.reset();
    
    _slideAnimation = Tween<Offset>(
      begin: _slideAnimation.value,
      end: targetOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _rotationAnimation = Tween<double>(
      begin: _rotationAnimation.value,
      end: targetRotation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _opacityAnimation = Tween<double>(
      begin: _opacityAnimation.value,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    
    _controller.forward().then((_) {
      if (mounted) {
        _controller.reset();
        _resetAnimations();
        _isAnimating = false;
        onComplete();
      }
    });
  }

  void _swipeRight() {
    _animateOut(
      Offset(2.0, _slideAnimation.value.dy),
      0.2,
      widget.onLike,
    );
  }

  void _swipeLeft() {
    _animateOut(
      Offset(-2.0, _slideAnimation.value.dy),
      -0.2,
      widget.onSkip,
    );
  }

  void _returnToCenter() {
    _isAnimating = true;
    _controller.reset();
    
    _slideAnimation = Tween<Offset>(
      begin: _slideAnimation.value,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _rotationAnimation = Tween<double>(
      begin: _rotationAnimation.value,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: _opacityAnimation.value,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _controller.forward().then((_) {
      if (mounted) {
        _controller.reset();
        _isAnimating = false;
      }
    });
  }

  void _handleLike() {
    if (_isAnimating) return;
    _swipeRight();
  }

  void _handleSkip() {
    if (_isAnimating) return;
    _swipeLeft();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: widget.onDetail,
              onPanStart: _handleDragStart,
              onPanUpdate: _handleDragUpdate,
              onPanEnd: _handleDragEnd,
              child: SlideTransition(
                position: _slideAnimation,
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: FadeTransition(
                    opacity: _opacityAnimation,
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
                          child: widget.place.images.isNotEmpty
                              ? Image.network(
                                  widget.place.images.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPlaceholder(),
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
                                  Colors.black.withValues(alpha: 0.8),
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
                                  widget.place.description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 16,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.place.tags.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: widget.place.tags
                                        .map(
                                          (tag) => Chip(
                                            label: Text(
                                              tag,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor:
                                                Colors.white.withValues(alpha: 0.2),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
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
                          child: IconButton(
                            icon: const Icon(Icons.info_outline,
                                color: Colors.white),
                            onPressed: widget.onDetail,
                          ),
                        ),
                      ],
                    ),
                  ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      iconSize: 32,
                      onPressed: _handleSkip,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.green),
                      iconSize: 32,
                      onPressed: _handleLike,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Like',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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