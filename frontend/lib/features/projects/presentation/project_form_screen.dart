import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/projects_controller.dart';

/// Create project form (admin). Edit reuses the same screen when [projectId] set.
class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.projectId});
  final String? projectId;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    'projectNumber': TextEditingController(),
    'customerName': TextEditingController(),
    'phone': TextEditingController(),
    'altPhone': TextEditingController(),
    'address': TextEditingController(),
    'siteLocation': TextEditingController(),
    'projectName': TextEditingController(),
    'projectType': TextEditingController(),
    'workDescription': TextEditingController(),
    'quotationAmount': TextEditingController(),
    'remarks': TextEditingController(),
  };

  List<Map<String, dynamic>> _supervisors = [];
  List<Map<String, dynamic>> _designers = [];
  String? _supervisorId;
  String? _designerId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAssignables();
  }

  Future<void> _loadAssignables() async {
    final repo = ref.read(projectsRepositoryProvider);
    try {
      final s = await repo.assignable('supervisor');
      final d = await repo.assignable('designer');
      if (mounted) {
        setState(() {
          _supervisors = s;
          _designers = d;
        });
      }
    } catch (_) {/* ignore */}
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      for (final e in _fields.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      if (_supervisorId != null) 'supervisorId': _supervisorId,
      if (_designerId != null) 'designerId': _designerId,
    };
    if (body['quotationAmount'] != null) {
      body['quotationAmount'] = num.tryParse(body['quotationAmount']) ?? 0;
    }
    try {
      final project = await ref.read(projectsRepositoryProvider).create(body);
      ref.invalidate(projectsListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Project created')));
      context.go('/admin/projects/${project.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DioClient.toApiException(e).message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _group('Customer'),
            _tf('customerName', 'Customer Name', required: true),
            _tf(
              'phone',
              'Phone',
              required: true,
              keyboard: TextInputType.phone,
            ),
            _tf('altPhone', 'Alternative Phone', keyboard: TextInputType.phone),
            _tf('address', 'Address'),
            _tf('siteLocation', 'Site Location'),
            _group('Project'),
            _tf('projectType', 'Project Type', required: true),
            _tf('workDescription', 'Work Description', maxLines: 3),
            _group('Commercials'),
            _tf(
              'quotationAmount',
              'Quotation Amount',
              keyboard: TextInputType.number,
            ),
            _group('Assignment'),
            _dropdown(
              'Assign Supervisor',
              _supervisors,
              _supervisorId,
              (v) => setState(() => _supervisorId = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _dropdown(
              'Assign Designer',
              _designers,
              _designerId,
              (v) => setState(() => _designerId = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _tf('remarks', 'Remarks', maxLines: 2),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Project'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String title) => Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      );

  Widget _tf(
    String key,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppTextField(
        label: label,
        controller: _fields[key],
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: required ? (v) => Validators.required(v, label) : null,
      ),
    );
  }

  Widget _dropdown(
    String label,
    List<Map<String, dynamic>> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('Not assigned')),
        for (final o in options)
          DropdownMenuItem(
            value: o['id'] as String,
            child: Text(o['fullName'] as String? ?? ''),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
