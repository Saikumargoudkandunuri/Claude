import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _SectionLabel('Notifications'),
          Card(
            child: SwitchListTile(
              value: _pushEnabled,
              activeThumbColor: AppColors.primary,
              title: const Text('Push notifications'),
              subtitle: const Text('Task assignments, reports, payments, stages'),
              onChanged: (v) => setState(() => _pushEnabled = v),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('Account'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Signed in as'),
                  subtitle: Text(user?.email ?? '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text('Logout',
                      style: TextStyle(color: AppColors.danger),),
                  onTap: () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('About'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Interior Manager'),
                  subtitle: Text('Version 1.0.0'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.cloud_outlined),
                  title: Text('Server'),
                  subtitle: Text(Env.apiBaseUrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,),),
    );
  }
}
