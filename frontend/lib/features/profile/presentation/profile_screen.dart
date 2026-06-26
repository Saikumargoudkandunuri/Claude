import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/config/env.dart';
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
                // Profile avatar with camera overlay
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(
                                    '${Env.apiBaseUrl}/auth/avatar/${user.id}',
                                  )
                                : null,
                            child: user.avatarUrl != null
                                ? null
                                : Text(
                                    user.fullName.isNotEmpty
                                        ? user.fullName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _pickProfilePhoto(context, ref),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
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
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          Formatters.roleLabel(user.role),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Account info card
                Card(
                  child: Column(
                    children: [
                      _tile(Icons.mail_outline, 'Email', user.email),
                      const Divider(height: 1),
                      _tile(Icons.phone_outlined, 'Phone', user.phone),
                      if (user.role == 'worker') ...[
                        const Divider(height: 1),
                        _tile(
                          Icons.work_outline,
                          'Status',
                          Formatters.stageLabel(user.workerStatus),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Account actions
                const Text(
                  'Account Settings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                _actionTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Edit Name & Phone',
                  subtitle: 'Update your personal details',
                  onTap: () =>
                      _showEditProfile(context, ref, user.fullName, user.phone),
                ),
                _actionTile(
                  context,
                  icon: Icons.pin_outlined,
                  title: 'Change PIN',
                  subtitle: 'Update your 4-digit login PIN',
                  onTap: () => _showChangePin(context, ref),
                ),
                _actionTile(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () => _showChangePassword(context, ref),
                ),
                _actionTile(
                  context,
                  icon: Icons.help_outline,
                  title: 'Security Question',
                  subtitle: 'Used to reset your password if forgotten',
                  onTap: () => _showSecurityQuestion(context, ref),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Logout
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, color: AppColors.danger),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    label: const Text('Logout'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
    );
  }

  Widget _tile(IconData icon, String label, String? value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        value ?? '',
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }

  void _pickProfilePhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
      );
      if (picked != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading photo...')),
        );
        final bytes = await picked.readAsBytes();
        final dio = DioClient.instance.dio;
        final formData = FormData.fromMap({
          'avatar': MultipartFile.fromBytes(bytes, filename: picked.name),
        });
        await dio.put('/auth/me/avatar', data: formData);
        // Evict cached avatar image so the new one loads
        final user = ref.read(authControllerProvider).user;
        if (user != null) {
          await NetworkImage('${Env.apiBaseUrl}/auth/avatar/${user.id}')
              .evict();
        }
        await ref.read(authControllerProvider.notifier).refreshUser();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    }
  }

  void _showEditProfile(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String currentPhone,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setSheetState(() => busy = true);
                            try {
                              final api = ref.read(authApiProvider);
                              await api.updateProfile(
                                fullName: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                              );
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .refreshUser();
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated'),
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
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Change PIN',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800),),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Current PIN', counterText: '',),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'New PIN', counterText: '',),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Confirm New PIN', counterText: '',),
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
                                      content: Text('PIN must be 4 digits'),),);
                              return;
                            }
                            if (newCtrl.text != confirmCtrl.text) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text('PINs do not match'),),);
                              return;
                            }
                            setSheetState(() => busy = true);
                            try {
                              final dio = DioClient.instance.dio;
                              await dio.put('/auth/me/pin', data: {
                                'currentPin': currentCtrl.text,
                                'newPin': newCtrl.text,
                              },);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('PIN changed successfully'),),);
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setSheetState(() => busy = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                    content: Text(
                                        DioClient.toApiException(e).message,),),);
                              }
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,),)
                        : const Text('Change PIN'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Change Password',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800),),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Current password'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'New password (min 8 chars)',),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm new password'),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (newCtrl.text.length < 8) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Password must be at least 8 characters',),),
                              );
                              return;
                            }
                            if (newCtrl.text != confirmCtrl.text) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('Passwords do not match'),),
                              );
                              return;
                            }
                            setSheetState(() => busy = true);
                            try {
                              await ref.read(authApiProvider).changePassword(
                                  currentCtrl.text, newCtrl.text,);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Password changed. Please log in again.',),),
                                );
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .logout();
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setSheetState(() => busy = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          DioClient.toApiException(e).message,),),
                                );
                              }
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,),)
                        : const Text('Change Password'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSecurityQuestion(BuildContext context, WidgetRef ref) {
    final answerCtrl = TextEditingController();
    List<String> options = const [];
    String? selected;
    bool busy = false;
    bool loading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (loading) {
            loading = false;
            ref.read(authApiProvider).securityQuestionStatus().then((data) {
              final opts = (data['options'] as List?)?.cast<String>() ??
                  const <String>[];
              if (ctx.mounted) {
                setSheetState(() {
                  options = opts;
                  selected = (data['question'] as String?) ??
                      (opts.isNotEmpty ? opts.first : null);
                });
              }
            }).catchError((_) {
              if (ctx.mounted) setSheetState(() {});
            });
          }
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Security Question',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),),
                  const SizedBox(height: 4),
                  const Text('Used to reset your password if you forget it.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary,),),
                  const SizedBox(height: AppSpacing.lg),
                  if (options.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),)
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Question'),
                      items: options
                          .map((q) => DropdownMenuItem(
                                value: q,
                                child: Text(q,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,),
                              ),)
                          .toList(),
                      onChanged: (v) => setSheetState(() => selected = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: answerCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Your answer'),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (selected == null) return;
                                if (answerCtrl.text.trim().length < 2) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Answer must be at least 2 characters',),),
                                  );
                                  return;
                                }
                                setSheetState(() => busy = true);
                                try {
                                  await ref
                                      .read(authApiProvider)
                                      .setSecurityQuestion(
                                          selected!, answerCtrl.text.trim(),);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Security question saved'),),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setSheetState(() => busy = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              DioClient.toApiException(e)
                                                  .message,),),
                                    );
                                  }
                                }
                              },
                        child: busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white,),)
                            : const Text('Save Question'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
