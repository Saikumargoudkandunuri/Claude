import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/dio_client.dart';
import '../../../shared/design/app_gradients.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/gradient_card.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../application/drawings_controller.dart';

/// BUG-01: Multi-image/file upload for drawings (2D, Working, 3D).
class UploadDrawingsScreen extends ConsumerStatefulWidget {
  const UploadDrawingsScreen({
    super.key,
    required this.projectId,
    required this.category,
  });

  final String projectId;
  final String category; // '2d_drawing', 'working_drawing', '3d_design'

  @override
  ConsumerState<UploadDrawingsScreen> createState() =>
      _UploadDrawingsScreenState();
}

class _UploadDrawingsScreenState extends ConsumerState<UploadDrawingsScreen> {
  final List<XFile> _selected = [];
  bool _uploading = false;

  String get _categoryLabel => switch (widget.category) {
        '2d_drawing' => '2D Drawings',
        'working_drawing' => 'Working Drawings',
        '3d_design' => '3D Designs',
        _ => 'Files',
      };

  Future<void> _pickImages() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty) setState(() => _selected.addAll(picked));
    } catch (_) {}
  }

  Future<void> _pickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (res != null) {
        setState(() => _selected.addAll(
            res.files.where((f) => f.path != null).map((f) => XFile(f.path!)),),);
      }
    } catch (_) {}
  }

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      for (final file in _selected) {
        final bytes = await file.readAsBytes();
        await ref.read(drawingsRepositoryProvider).upload(
              projectId: widget.projectId,
              category: widget.category,
              bytes: bytes,
              filename: file.name,
            );
      }
      ref.invalidate(projectFilesProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${_selected.length} file(s) uploaded'),),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGradients.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppGradients.surfaceCard,
        title: GradientText(
          'Upload $_categoryLabel',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Selected files preview
          if (_selected.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: _selected.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  if (i == _selected.length) {
                    return GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                              width: 1.5,),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Color(0xFF6C63FF), size: 24),
                            SizedBox(height: 4),
                            Text('Add',
                                style: TextStyle(
                                    color: Color(0xFF6C63FF), fontSize: 11,),),
                          ],
                        ),
                      ),
                    );
                  }
                  final file = _selected[i];
                  final isImg = _isImage(file.name);
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppGradients.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: isImg
                            ? Image.file(File(file.path),
                                fit: BoxFit.cover, width: 80, height: 110,)
                            : const Center(
                                child: Icon(Icons.picture_as_pdf,
                                    color: Color(0xFFEF4444), size: 32,),),
                      ),
                      if (!_uploading)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selected.removeAt(i)),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white,),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

          // Empty state — pick files
          if (_selected.isEmpty)
            Expanded(
              child: GestureDetector(
                onTap: _pickImages,
                child: GradientCard(
                  margin: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload,
                          color: Color(0xFF6C63FF), size: 48,),
                      const SizedBox(height: 12),
                      const GradientText('Tap to select files',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700,),),
                      const SizedBox(height: 4),
                      const Text('Images & PDFs • Up to 20 files',
                          style: TextStyle(
                              color: AppGradients.textSecondary, fontSize: 12,),),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.description, size: 16),
                        label: const Text('Or pick PDF files'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6C63FF),
                          side: const BorderSide(color: Color(0xFF6C63FF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Upload button
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                expand: true,
                busy: _uploading,
                label:
                    'Upload ${_selected.length} file${_selected.length != 1 ? 's' : ''}',
                onPressed: _uploading ? null : _upload,
              ),
            ),
        ],
      ),
    );
  }

  bool _isImage(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);
  }
}
