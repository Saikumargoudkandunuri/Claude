import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/customer_providers.dart';

/// Displays a grid of project photos for the customer portal.
///
/// Photos are ordered newest first. Tapping a photo opens it in a
/// full-screen interactive viewer. Shows appropriate empty, loading,
/// and error states.
class CustomerPhotosScreen extends ConsumerWidget {
  const CustomerPhotosScreen({super.key});

  static const _brandTeal = Color(0xFF00D1DC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(customerPhotosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Photos', style: TextStyle(fontSize: 16)),
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(customerPhotosProvider),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            color: _brandTeal,
            onRefresh: () async => ref.invalidate(customerPhotosProvider),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
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
    final id = photo['id']?.toString() ?? '';
    // If the photo has a url field, use it; otherwise construct from id
    final url = photo['url']?.toString() ?? '';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPhotoView(
          photoName: name,
          photoUrl: url,
          photoId: id,
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
    final name = photo['original_name']?.toString() ?? 'Untitled';
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
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: url != null && url.isNotEmpty
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (formattedDate.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(Icons.photo_outlined, size: 40, color: Colors.grey.shade400),
    );
  }

  Widget _photoLoadingPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
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
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          const Text(
            'No photos yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Project photos will appear here once uploaded',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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

  static const _brandTeal = Color(0xFF00D1DC);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            const Text(
              'Failed to load photos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandTeal,
                foregroundColor: Colors.white,
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
    required this.photoId,
  });

  final String photoName;
  final String photoUrl;
  final String photoId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
                    return const CircularProgressIndicator(color: Colors.white);
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
