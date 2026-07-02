import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/customer_providers.dart';
import '../theme/portal_theme.dart';

/// Premium photo gallery — category tabs, a hero + 2-column masonry-style
/// grid, shimmer loading, staggered zoom reveal, and a full-screen Hero
/// viewer with pinch-zoom. Data fetching preserved.
class CustomerPhotosScreen extends ConsumerStatefulWidget {
  const CustomerPhotosScreen({super.key});

  @override
  ConsumerState<CustomerPhotosScreen> createState() =>
      _CustomerPhotosScreenState();
}

class _CustomerPhotosScreenState extends ConsumerState<CustomerPhotosScreen> {
  static const _categories = [
    'All',
    'Kitchen',
    'Bedroom',
    'Living Room',
    'Other',
  ];
  String _selected = 'All';

  String _categoryOf(Map photo) {
    final raw = (photo['category'] ??
            photo['room'] ??
            photo['original_name'] ??
            photo['caption'] ??
            '')
        .toString()
        .toLowerCase();
    if (raw.contains('kitchen')) return 'Kitchen';
    if (raw.contains('bedroom') || raw.contains('bed')) return 'Bedroom';
    if (raw.contains('living') || raw.contains('hall')) return 'Living Room';
    return 'Other';
  }

  List<dynamic> _filter(List<dynamic> photos) {
    if (_selected == 'All') return photos;
    return photos.where((p) => _categoryOf(p as Map) == _selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(customerPhotosProvider);

    return Scaffold(
      backgroundColor: PortalColors.neutral,
      appBar: AppBar(
        title: Text('Site Photos', style: PortalText.heading(size: 20)),
        backgroundColor: PortalColors.cardBg,
        foregroundColor: PortalColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final active = cat == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          active ? PortalColors.primary : PortalColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            active ? PortalColors.primary : PortalColors.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: PortalText.label(
                        size: 12,
                        color: active ? Colors.white : PortalColors.textSoft,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: photosAsync.when(
        loading: _buildShimmerGrid,
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(customerPhotosProvider),
        ),
        data: (photos) {
          if (photos.isEmpty) return const _EmptyState();
          final filtered = _filter(photos);
          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'No $_selected photos yet',
                style: PortalText.body(color: PortalColors.textSoft),
              ),
            );
          }
          return RefreshIndicator(
            color: PortalColors.primary,
            onRefresh: () async => ref.invalidate(customerPhotosProvider),
            child: _buildGrid(context, filtered),
          );
        },
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) =>
          const PortalShimmer(width: 200, height: 200, radius: 16),
    );
  }

  Widget _buildGrid(BuildContext context, List<dynamic> photos) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Hero (first / latest) photo full-width
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _PhotoTile(
              photo: photos.first as Map<String, dynamic>,
              order: 0,
              aspectRatio: 16 / 9,
              onTap: () =>
                  _openViewer(context, photos.first as Map<String, dynamic>),
            ),
          ),
        ),
        if (photos.length > 1)
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final photo = photos[i + 1] as Map<String, dynamic>;
                  return _PhotoTile(
                    photo: photo,
                    order: i + 1,
                    onTap: () => _openViewer(context, photo),
                  );
                },
                childCount: photos.length - 1,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _openViewer(BuildContext context, Map<String, dynamic> photo) {
    final url = photo['url']?.toString() ?? '';
    final name = photo['original_name']?.toString() ?? 'Photo';
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _FullScreenPhotoView(photoName: name, photoUrl: url),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.order,
    required this.onTap,
    this.aspectRatio,
  });

  final Map<String, dynamic> photo;
  final int order;
  final VoidCallback onTap;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final url = photo['url']?.toString() ?? '';
    final createdAt = photo['created_at']?.toString();
    String date = '';
    if (createdAt != null) {
      final d = DateTime.tryParse(createdAt);
      if (d != null) date = DateFormat('dd MMM yyyy').format(d.toLocal());
    }

    final tile = GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: url.isEmpty ? 'photo_$order' : url,
              child: url.isNotEmpty
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : _loading(),
                    )
                  : _placeholder(),
            ),
            if (date.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                  child: Text(
                    date,
                    style: PortalText.caption(size: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final wrapped = aspectRatio != null
        ? AspectRatio(aspectRatio: aspectRatio!, child: tile)
        : tile;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (order * 60).clamp(0, 600)),
      curve: Curves.easeOut,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
      child: wrapped,
    );
  }

  Widget _placeholder() => Container(
        color: PortalColors.shimmer1,
        child: const Center(
          child: Icon(
            Icons.photo_outlined,
            size: 40,
            color: PortalColors.textSoft,
          ),
        ),
      );

  Widget _loading() => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: PortalColors.primary,
        ),
      );
}

class _EmptyState extends StatefulWidget {
  const _EmptyState();

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -6 * _ctrl.value),
                child: child,
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 64,
                color: PortalColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text('No photos yet', style: PortalText.heading(size: 18)),
            const SizedBox(height: 8),
            Text(
              'Our team is carefully preparing your first site update.',
              style: PortalText.body(size: 13, color: PortalColors.textSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const PortalPulseDot(size: 8),
          ],
        ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              'Failed to load photos',
              style: PortalText.body(size: 15)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: PortalText.caption(size: 12),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: PortalColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
        foregroundColor: Colors.white,
        title: Text(photoName, style: const TextStyle(fontSize: 13)),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: photoUrl.isNotEmpty
              ? Hero(
                  tag: photoUrl,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Could not load image',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : const Icon(
                  Icons.photo_outlined,
                  size: 64,
                  color: Colors.white38,
                ),
        ),
      ),
    );
  }
}
