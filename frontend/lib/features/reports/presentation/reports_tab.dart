import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'whatsapp_report_screen.dart';

/// Reports tab inside a project detail — WhatsApp-style chat (BUG-04/05).
/// The stage button is NOT here; it lives on the Overview/header FAB.
class ReportsTab extends ConsumerWidget {
  const ReportsTab({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WhatsAppReportScreen(projectId: projectId);
  }
}
