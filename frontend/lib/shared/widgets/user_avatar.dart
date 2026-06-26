import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';

/// Consistent user avatar used everywhere in the app.
///
/// Loads the photo from the streaming endpoint `/auth/avatar/:userId` and
/// falls back to the user's initial when no photo is set or loading fails.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.hasAvatar = false,
    this.radius = 20,
  });

  /// The user's id (used to build the avatar URL).
  final String userId;

  /// Display name; its first letter is the fallback.
  final String name;

  /// Whether the user has an uploaded photo.
  final bool hasAvatar;

  /// Circle radius in logical pixels.
  final double radius;

  /// The streaming avatar URL for a given user.
  static String urlFor(String userId) =>
      '${Env.apiBaseUrl}/auth/avatar/$userId';

  /// Drop the cached image so a freshly uploaded photo loads on next build.
  static Future<void> evict(String userId) =>
      CachedNetworkImage.evictFromCache(urlFor(userId));

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final fallback = _Fallback(name: name, size: size);
    if (!hasAvatar || userId.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: urlFor(userId),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
