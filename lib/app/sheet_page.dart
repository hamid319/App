import 'package:flutter/material.dart';

/// A GoRouter page shown as a tall bottom sheet over the current screen,
/// like a card pulled out of the wallet. Pages pushed from inside it open
/// on top as usual.
class SheetPage<T> extends Page<T> {
  const SheetPage({super.key, required this.child, this.enableDrag = true});

  final Widget child;

  /// Off for content with its own vertical gestures, e.g. a map.
  final bool enableDrag;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
        settings: this,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: enableDrag,
        // The page's coloured app bar draws its own handle.
        showDragHandle: false,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: child),
      );
}
