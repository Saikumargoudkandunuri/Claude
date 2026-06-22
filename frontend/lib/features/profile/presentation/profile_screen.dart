import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: Text('Not signed in'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(user.fullName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(Formatters.roleLabel(user.role),
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Card(
                  child: Column(
                    children: [
                      _tile(Icons.mail_outline, 'Email', user.email),
                      const Divider(height: 1),
                      _tile(Icons.phone_outlined, 'Phone', user.phone),
                      const Divider(height: 1),
                      _tile(Icons.badge_outlined, 'Role',
                          Formatters.roleLabel(user.role)),
                      if (user.role == 'worker') ...[
                        const Divider(height: 1),
                        _tile(Icons.work_outline, 'Status',
                            Formatters.stageLabel(user.workerStatus)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout, color: AppColors.danger),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  label: const Text('Logout'),
                ),
              ],
            ),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600)),
    );
  }
}
