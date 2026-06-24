import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';

/// Provider that fetches all approved workers using the assignable endpoint.
/// This endpoint is accessible to both admin and supervisor roles.
final allWorkersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/assignable', queryParameters: {
    'role': 'worker',
  });
  return (res.data['data'] as List).cast<Map<String, dynamic>>();
});

/// Screen showing all workers.
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

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.engineering, color: AppColors.primary),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: const Text('Worker'),
      ),
    );
  }
}
