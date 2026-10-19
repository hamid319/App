import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

/// Round avatar with the member's initial in their identity colour.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.id,
    required this.name,
    this.size = 32,
    this.borderColor,
  });

  final String id;
  final String name;
  final double size;

  /// Ring around the avatar, used when avatars overlap.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AvatarColors.forId(id),
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: size * 0.08),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
