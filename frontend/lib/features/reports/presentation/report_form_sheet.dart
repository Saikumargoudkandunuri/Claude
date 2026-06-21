import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/reports_controller.dart';

/// End-of-day report form for workers and supervisors.
Future<void> showReportForm(
  BuildContext context,
  WidgetRef ref,
  String projectId,
  String role,
) {
  final isSupervisor = role == 'supervisor';
  final workDone = TextEditingController();
  final pending = TextEditingController();
  final problems = TextEditingController();
  final materials = TextEditingController();
  final tomorrow = TextEditingController();
  final siteProgress = TextEditingController();
  bool submitting = false;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: StatefulBuilder(
        builder: (ctx, setState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isSupervisor ? 'Supervisor Daily Report' : 'End-of-Day Report',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.lg),
              _field('Today\'s work done', workDone),
              if (isSupervisor) _field('Site progress', siteProgress),
              _field('Pending work', pending),
              _field('Problems', problems),
              _field('Materials needed', materials),
              _field('Tomorrow notes', tomorrow),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setState(() => submitting = true);
                        try {
                          await ref.read(reportsRepositoryProvider).submit(projectId, {
                            'type': isSupervisor ? 'supervisor' : 'worker',
                            'workDone': workDone.text,
                            'pendingWork': pending.text,
                            'problems': problems.text,
                            'materialsNeeded': materials.text,
                            'tomorrowNotes': tomorrow.text,
                            if (isSupervisor) 'siteProgress': siteProgress.text,
                          });
                          ref.invalidate(projectReportsProvider(projectId));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report submitted')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content:
                                      Text(DioClient.toApiException(e).message)),
                            );
                          }
                        } finally {
                          setState(() => submitting = false);
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _field(String label, TextEditingController c) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      controller: c,
      maxLines: 2,
      decoration: InputDecoration(labelText: label),
    ),
  );
}
