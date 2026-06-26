import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_controller.dart';

const _navy = Color(0xFF1A237E);
const _blue = Color(0xFF1565C0);
const _error = Color(0xFFD32F2F);
const _success = Color(0xFF2E7D32);

const _roleColors = <String, Color>{
  'admin': Color(0xFFD32F2F),
  'supervisor': Color(0xFF1565C0),
  'designer': Color(0xFF7B1FA2),
  'worker': Color(0xFF2E7D32),
};

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    final roleColor = _roleColors[user.role] ?? _blue;
    final initials = user.fullName.isNotEmpty
        ? user.fullName
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Avatar section
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: roleColor.withOpacity(0.15),
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(
                              '${Env.apiBaseUrl}/auth/avatar/${user.id}',
                            )
                          : null,
                      child: user.avatarUrl != null
                          ? null
                          : Text(
                              initials,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: roleColor,
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _pickAvatar(context, ref),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (user.role ?? 'unknown').toUpperCase(),
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  user.phone,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Edit Name
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: const Icon(Icons.edit_outlined, color: _blue),
              title: const Text(
                'Edit Name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showEditName(context, ref, user.fullName),
            ),
          ),

          // Change PIN
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: const Icon(Icons.pin_outlined, color: _blue),
              title: const Text(
                'Change PIN',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePin(context, ref),
            ),
          ),

          // Account info card
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.badge_outlined, color: roleColor),
                  title: const Text('Role'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (user.role ?? 'unknown').toUpperCase(),
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: _blue),
                  title: const Text('Status'),
                  trailing: Text(
                    user.status.toUpperCase(),
                    style: TextStyle(
                      color: user.status == 'approved' ? _success : _error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Employee ID (admin only)
          if (user.role == 'admin') ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: ListTile(
                leading: const Icon(Icons.fingerprint, color: _navy),
                title: const Text('Employee ID'),
                subtitle: Text(
                  user.id,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: user.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ID copied to clipboard')),
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Logout
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: FilledButton.styleFrom(
                backgroundColor: _error,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  void _pickAvatar(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
      );
      if (picked == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading photo...')),
      );

      final bytes = await picked.readAsBytes();
      final dio = DioClient.instance.dio;
      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: picked.name),
      });
      await dio.put('/auth/me/avatar', data: formData);

      // Evict cached avatar
      final user = ref.read(authControllerProvider).user;
      if (user != null) {
        await NetworkImage('${Env.apiBaseUrl}/auth/avatar/${user.id}').evict();
      }
      await ref.read(authControllerProvider.notifier).refreshUser();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: _success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    }
  }

  void _showEditName(BuildContext context, WidgetRef ref, String currentName) {
    final nameCtrl = TextEditingController(text: currentName);
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Name',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.length < 2) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Name must be at least 2 characters'),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => busy = true);
                          try {
                            final dio = DioClient.instance.dio;
                            await dio.put('/auth/me', data: {'fullName': name});
                            await ref
                                .read(authControllerProvider.notifier)
                                .refreshUser();
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Name updated'),
                                  backgroundColor: _success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setSheetState(() => busy = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    DioClient.toApiException(e).message,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePin(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Change PIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: currentCtrl,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Current PIN',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: newCtrl,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'New PIN',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Confirm New PIN',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (newCtrl.text.length != 4) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('PIN must be 4 digits'),
                              ),
                            );
                            return;
                          }
                          if (newCtrl.text != confirmCtrl.text) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('PINs do not match'),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => busy = true);
                          try {
                            final dio = DioClient.instance.dio;
                            await dio.put('/auth/me/pin', data: {
                              'currentPin': currentCtrl.text,
                              'newPin': newCtrl.text,
                            });
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('PIN changed successfully'),
                                  backgroundColor: _success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setSheetState(() => busy = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    DioClient.toApiException(e).message,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Change PIN'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authControllerProvider.notifier).logout();
            },
            style: FilledButton.styleFrom(backgroundColor: _error),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
