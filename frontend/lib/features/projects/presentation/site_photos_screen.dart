import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class SitePhotosScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  const SitePhotosScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<SitePhotosScreen> createState() => _SitePhotosScreenState();
}

class _SitePhotosScreenState extends State<SitePhotosScreen> {
  final Dio _dio = DioClient.instance.dio;
  List<dynamic> _photos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get('/projects/${widget.projectId}/photos');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final filePhotos = (data['file_photos'] as List?) ?? [];
      if (mounted)
        setState(() {
          _photos = filePhotos;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photos — ${widget.projectName}',
            style: const TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xFF00D1DC),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No site photos yet',
                            style: TextStyle(color: Colors.grey, fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text(
                            'Photos uploaded in daily reports will appear here',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center),
                      ]),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (context, i) {
                    final photo = _photos[i] as Map<String, dynamic>;
                    final url = photo['url'] as String? ?? '';
                    return GestureDetector(
                      onTap: () => _openPhoto(context, url, photo),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 1.5),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _openPhoto(
      BuildContext context, String url, Map<String, dynamic> photo) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(photo['uploader_name']?.toString() ?? 'Photo',
              style: const TextStyle(fontSize: 13)),
        ),
        body: InteractiveViewer(
          child: Center(
            child: Image.network(url,
                errorBuilder: (_, __, ___) => const Text('Could not load image',
                    style: TextStyle(color: Colors.white))),
          ),
        ),
      ),
    ));
  }
}
