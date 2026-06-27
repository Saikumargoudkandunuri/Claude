import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/customer_providers.dart';
import '../theme/customer_theme.dart';

/// Displays a grid of project photos for the customer portal.
///
/// Photos are ordered newest first. Tapping a photo opens it in a
/// full-screen interactive viewer. Shows appropriate empty, loading,
/// and error states.
class CustomerPhotosScreen extends ConsumerWidget {
  const CustomerPhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(customerPhotosProvider);

    return Scaffold(
      backgroundColor: CTheme.bgSoft,
      appBar: AppBar(
        title: const Text(
          'Site Photos',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: CTheme.textDark,
          ),
        ),
        backgroundColor: CTheme.bgWhite,
        foregroundColor: CTheme.textDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: photosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: CTheme.primary),
        ),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(customerPhotosProvider),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            color: CTheme.primary,
            onRefresh: () async => ref.invalidate(customerPhotosProvider),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GridView.builder(
                  padding: const EdgeInsets.all(CTheme.p12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index] as Map<String, dynamic>;
                    return _PhotoCard(
                      photo: photo,
                      onTap: () => _openFullScreen(context, photo),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openFullScreen(BuildContext context, Map<String, dynamic> photo) {
    final name = photo['original_name']?.toString() ?? 'Photo';
    final url = photo['url']?.toString() ?? '';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPhotoView(
          photoName: name,
          photoUrl: url,
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.onTap});

  final Map<String, dynamic> photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final createdAt = photo['created_at']?.toString();
    final url = photo['url']?.toString();

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = DateFormat('dd MMM yyyy').format(date);
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: CTheme.r16,
          boxShadow: CTheme.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: CTheme.r16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              url != null && url.isNotEmpty
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _photoLoadingPlaceholder();
                      },
                    )
                  : _photoPlaceholder(),
              // Bottom gradient overlay with date
              if (formattedDate.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                      CTheme.p12,
                      CTheme.p24,
                      CTheme.p12,
                      CTheme.p8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black54,
                        ],
                      ),
                    ),
                    child: Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 11,
                        color: CTheme.bgWhite,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: CTheme.bgSoft,
      child: const Center(
        child: Icon(Icons.photo_outlined, size: 40, color: CTheme.textLight),
      ),
    );
  }

  Widget _photoLoadingPlaceholder() {
    return Container(
      color: CTheme.bgSoft,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: CTheme.primary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: CTheme.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: CTheme.p12),
          const Text(
            'No photos yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CTheme.textMid,
            ),
          ),
          const SizedBox(height: CTheme.p8),
          const Text(
            'Project photos will appear here once uploaded',
            style: TextStyle(fontSize: 13, color: CTheme.textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CTheme.p24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: CTheme.p12),
            const Text(
              'Failed to load photos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CTheme.textDark,
              ),
            ),
            const SizedBox(height: CTheme.p8),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: CTheme.textMid),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CTheme.p16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CTheme.primary,
                foregroundColor: CTheme.bgWhite,
                shape: RoundedRectangleBorder(borderRadius: CTheme.r12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenPhotoView extends StatelessWidget {
  const _FullScreenPhotoView({
    required this.photoName,
    required this.photoUrl,
  });

  final String photoName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: CTheme.bgWhite,
        title: Text(
          photoName,
          style: const TextStyle(fontSize: 13),
        ),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: photoUrl.isNotEmpty
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.white54),
                      SizedBox(height: 8),
                      Text(
                        'Could not load image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(
                      color: CTheme.bgWhite,
                    );
                  },
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_outlined, size: 64, color: Colors.white38),
                    SizedBox(height: 8),
                    Text(
                      'No preview available',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
