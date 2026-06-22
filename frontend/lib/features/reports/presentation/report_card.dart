import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';

/// Reusable daily-report card (used in project Reports tab and All Reports).
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, this.showProject = false});

  final Map<String, dynamic> report;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final type = report['type'] as String? ?? 'worker';
    final progress = report['progressPercent'];
    final media = (report['media'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == 'supervisor' ? Icons.supervisor_account : Icons.engineering,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${report['authorName'] ?? 'User'} · ${Formatters.roleLabel(type)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(Formatters.date(report['reportDate']),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
            if (showProject && report['projectName'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(report['projectName'].toString(),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ((progress as num).toDouble()) / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceAlt,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('$progress%',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _field('Work Done', report['workDone']),
            _field('Pending', report['pendingWork']),
            _field('Issues Faced', report['problems']),
            _field('Materials Used', report['materialsUsed']),
            _field('Materials Needed', report['materialsNeeded']),
            _field('Site Progress', report['siteProgress']),
            _field('Tomorrow', report['tomorrowNotes']),
            if (media.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text('Attachments',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in media)
                    Chip(
                      avatar: Icon(_mediaIcon(m['category'] as String?),
                          size: 16, color: AppColors.primary),
                      label: Text(
                        m['originalName']?.toString() ?? 'file',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _mediaIcon(String? category) {
    switch (category) {
      case 'video':
        return Icons.videocam_outlined;
      case 'voice_note':
        return Icons.mic_none;
      default:
        return Icons.image_outlined;
    }
  }

  Widget _field(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            TextSpan(text: value.toString()),
          ],
        ),
      ),
    );
  }
}
