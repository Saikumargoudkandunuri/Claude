import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import 'report_chat_view.dart';

/// Reports tab inside a project detail — uses the WhatsApp-style chat.
class ReportsTab extends ConsumerWidget {
  const ReportsTab({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).user?.role;
    final canCompose = role == 'worker' || role == 'supervisor' || role == 'admin';
    return ReportChatView(projectId: projectId, canCompose: canCompose);
  }
}
