import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/project.dart';

class DetailsTab extends StatelessWidget {
  const DetailsTab({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _section('Customer', [
          _row('Customer', project.customerName),
          _row('Phone', project.phone),
          if (project.altPhone != null) _row('Alt Phone', project.altPhone!),
          if (project.address != null) _row('Address', project.address!),
          if (project.siteLocation != null) _row('Site', project.siteLocation!),
        ]),
        _section('Project', [
          _row('Number', project.projectNumber),
          if (project.projectType != null) _row('Type', project.projectType!),
          if (project.workDescription != null)
            _row('Description', project.workDescription!),
          _row('Stage', Formatters.stageLabel(project.currentStage)),
          if (project.startDate != null)
            _row('Start', Formatters.date(project.startDate)),
          if (project.expectedCompletionDate != null)
            _row('Expected', Formatters.date(project.expectedCompletionDate)),
        ]),
        if (project.quotationAmount != null)
          _section('Commercials', [
            _row('Quotation', Formatters.currency(project.quotationAmount)),
          ]),
        if (project.contacts != null) _contacts(project.contacts!),
        if (project.remarks != null && project.remarks!.isNotEmpty)
          _section('Remarks', [Text(project.remarks!)]),
      ],
    );
  }

  Widget _contacts(ProjectContacts c) {
    return _section('Contacts', [
      if (c.adminName != null) _row('Admin', '${c.adminName} · ${c.adminPhone ?? ''}'),
      if (c.supervisorName != null)
        _row('Supervisor', '${c.supervisorName} · ${c.supervisorPhone ?? ''}'),
    ]);
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
