import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';

/// Provider that fetches all approved workers from the backend.
final allWorkersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users', queryParameters: {
    'role': 'worker',
    'status': 'approved',
    'limit': 200,
  });
  return (res.data['data'] as List).cast<Map<String, dynamic>>();
});

/// Screen showing all workers with their status and contact info.
class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allWorkersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workers')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(allWorkersProvider),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(allWorkersProvider),
          ),
          data: (workers) {
            if (workers.isEmpty) {
              return const EmptyState(
                message: 'No workers found',
                icon: Icons.engineering_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: workers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _WorkerCard(worker: workers[i]),
            );
          },
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.worker});
  final Map<String, dynamic> worker;

  @override
  Widget build(BuildContext context) {
    final name = worker['fullName']?.toString() ?? '';
    final phone = worker['phone']?.toString() ?? '';
    final email = worker['email']?.toString() ?? '';
    final workerStatus = worker['workerStatus']?.toString() ?? 'idle';
    final isAtSite = workerStatus == 'at_site';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isAtSite
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.textMuted.withValues(alpha: 0.15),
              child: Icon(
                Icons.engineering,
                color: isAtSite ? AppColors.success : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isAtSite
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.textMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAtSite ? 'At Site' : 'Idle',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isAtSite ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
