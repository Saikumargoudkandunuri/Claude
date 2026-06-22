import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/permissions/permissions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../drawings/application/drawings_controller.dart';
import '../../../drawings/domain/drawing_file.dart';

/// Lists drawings grouped by category. Admin/Designer can upload & replace.
class DrawingsTab extends ConsumerWidget {
  const DrawingsTab({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectFilesProvider(projectId));
    final role = ref.watch(authControllerProvider).user?.role;
    final canUpload = Permissions.canUploadDrawings(role);
    final isWorker = role == 'worker';

    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(projectFilesProvider(projectId)),
      ),
      data: (files) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final entry in kDrawingCategories.entries)
              _CategorySection(
                projectId: projectId,
                category: entry.key,
                title: entry.value,
                files: files.where((f) => f.category == entry.key).toList(),
                canUpload: canUpload,
              ),
            // Site Measurements section
            _CategorySection(
              projectId: projectId,
              category: kMeasurementCategory.key,
              title: kMeasurementCategory.value,
              files: files.where((f) => f.category == kMeasurementCategory.key).toList(),
              canUpload: canUpload,
            ),
            // Quotation is visible to admin/supervisor/designer, hidden from workers.
            if (!isWorker)
              _CategorySection(
                projectId: projectId,
                category: kQuotationCategory,
                title: 'Quotation',
                files:
                    files.where((f) => f.category == kQuotationCategory).toList(),
                canUpload: canUpload,
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

class _CategorySection extends ConsumerStatefulWidget {
  const _CategorySection({
    required this.projectId,
    required this.category,
    required this.title,
    required this.files,
    required this.canUpload,
  });

  final String projectId;
  final String category;
  final String title;
  final List<DrawingFile> files;
  final bool canUpload;

  @override
  ConsumerState<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<_CategorySection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(drawingsRepositoryProvider).upload(
            projectId: widget.projectId,
            category: widget.category,
            bytes: f.bytes!,
            filename: f.name,
          );
      ref.invalidate(projectFilesProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.title} updated')),
        );
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

  Future<void> _delete(DrawingFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete drawing?'),
        content: Text('Remove ${file.originalName}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(drawingsRepositoryProvider).delete(file.id);
    ref.invalidate(projectFilesProvider(widget.projectId));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.canUpload)
                _uploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: _pickAndUpload,
                        icon: Icon(
                          widget.files.isEmpty ? Icons.upload : Icons.autorenew,
                          size: 18,
                        ),
                        label:
                            Text(widget.files.isEmpty ? 'Upload' : 'Replace'),
                      ),
            ],
          ),
          if (widget.files.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'No file uploaded',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            for (final file in widget.files)
              Card(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                child: ListTile(
                  leading: Icon(
                    file.isPdf
                        ? Icons.picture_as_pdf
                        : file.isImage
                            ? Icons.image_outlined
                            : Icons.insert_drive_file_outlined,
                    color: AppColors.primary,
                  ),
                  title:
                      Text(file.originalName, overflow: TextOverflow.ellipsis),
                  subtitle: Text(file.caption ?? widget.title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (file.isPdf)
                        IconButton(
                          icon: const Icon(Icons.open_in_full),
                          tooltip: 'Open',
                          onPressed: () => context.push(
                            '/viewer',
                            extra: {
                              'url': file.downloadUrl,
                              'name': file.originalName,
                            },
                          ),
                        ),
                      if (widget.canUpload)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                          ),
                          onPressed: () => _delete(file),
                        ),
                    ],
                  ),
                ),
              ),
          const Divider(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
