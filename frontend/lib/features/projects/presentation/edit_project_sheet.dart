import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/projects_controller.dart';
import '../domain/project.dart';

/// Bottom sheet to edit project details (admin only).
class EditProjectSheet extends ConsumerStatefulWidget {
  const EditProjectSheet({
    super.key,
    required this.project,
    required this.onUpdated,
  });
  final Project project;
  final VoidCallback onUpdated;

  @override
  ConsumerState<EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends ConsumerState<EditProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _altPhoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _siteLocationCtrl;
  late final TextEditingController _projectNameCtrl;
  late final TextEditingController _projectTypeCtrl;
  late final TextEditingController _workDescCtrl;
  late final TextEditingController _quotationCtrl;
  late final TextEditingController _remarksCtrl;
  late final TextEditingController _latitudeCtrl;
  late final TextEditingController _longitudeCtrl;
  late final TextEditingController _radiusCtrl;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _customerNameCtrl = TextEditingController(text: p.customerName);
    _phoneCtrl = TextEditingController(text: p.phone);
    _altPhoneCtrl = TextEditingController(text: p.altPhone ?? '');
    _addressCtrl = TextEditingController(text: p.address ?? '');
    _siteLocationCtrl = TextEditingController(text: p.siteLocation ?? '');
    _projectNameCtrl = TextEditingController(text: p.projectName);
    _projectTypeCtrl = TextEditingController(text: p.projectType ?? '');
    _workDescCtrl = TextEditingController(text: p.workDescription ?? '');
    _quotationCtrl = TextEditingController(
      text: p.quotationAmount != null ? p.quotationAmount.toString() : '',
    );
    _remarksCtrl = TextEditingController(text: p.remarks ?? '');
    _latitudeCtrl = TextEditingController(
      text: p.siteLatitude != null ? p.siteLatitude.toString() : '',
    );
    _longitudeCtrl = TextEditingController(
      text: p.siteLongitude != null ? p.siteLongitude.toString() : '',
    );
    _radiusCtrl = TextEditingController(
      text: (p.siteRadiusMeters ?? 300).toString(),
    );
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _siteLocationCtrl.dispose();
    _projectNameCtrl.dispose();
    _projectTypeCtrl.dispose();
    _workDescCtrl.dispose();
    _quotationCtrl.dispose();
    _remarksCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final body = <String, dynamic>{};
      final p = widget.project;

      if (_customerNameCtrl.text.trim() != p.customerName) {
        body['customerName'] = _customerNameCtrl.text.trim();
      }
      if (_phoneCtrl.text.trim() != p.phone) {
        body['phone'] = _phoneCtrl.text.trim();
      }
      if (_altPhoneCtrl.text.trim() != (p.altPhone ?? '')) {
        body['altPhone'] = _altPhoneCtrl.text.trim();
      }
      if (_addressCtrl.text.trim() != (p.address ?? '')) {
        body['address'] = _addressCtrl.text.trim();
      }
      if (_siteLocationCtrl.text.trim() != (p.siteLocation ?? '')) {
        body['siteLocation'] = _siteLocationCtrl.text.trim();
      }
      if (_projectNameCtrl.text.trim() != p.projectName) {
        body['projectName'] = _projectNameCtrl.text.trim();
      }
      if (_projectTypeCtrl.text.trim() != (p.projectType ?? '')) {
        body['projectType'] = _projectTypeCtrl.text.trim();
      }
      if (_workDescCtrl.text.trim() != (p.workDescription ?? '')) {
        body['workDescription'] = _workDescCtrl.text.trim();
      }
      final quotation = double.tryParse(_quotationCtrl.text.trim()) ?? 0;
      if (quotation != (p.quotationAmount ?? 0)) {
        body['quotationAmount'] = quotation;
      }
      if (_remarksCtrl.text.trim() != (p.remarks ?? '')) {
        body['remarks'] = _remarksCtrl.text.trim();
      }

      // GPS coordinates
      final lat = double.tryParse(_latitudeCtrl.text.trim());
      final lng = double.tryParse(_longitudeCtrl.text.trim());
      final radius = int.tryParse(_radiusCtrl.text.trim());
      if (lat != null && lat != (p.siteLatitude ?? 0)) {
        body['siteLatitude'] = lat;
      }
      if (lng != null && lng != (p.siteLongitude ?? 0)) {
        body['siteLongitude'] = lng;
      }
      if (radius != null && radius != (p.siteRadiusMeters ?? 300)) {
        body['siteRadiusMeters'] = radius;
      }

      if (body.isEmpty) {
        Navigator.pop(context);
        return;
      }

      final repo = ref.read(projectsRepositoryProvider);
      await repo.update(p.id, body);
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit Project',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _field('Customer Name', _customerNameCtrl, required: true),
              _field('Phone', _phoneCtrl, keyboard: TextInputType.phone),
              _field('Alt Phone', _altPhoneCtrl, keyboard: TextInputType.phone),
              _field('Address', _addressCtrl, maxLines: 2),
              _field('Site Location', _siteLocationCtrl),
              const Divider(height: 32),
              _field('Project Name', _projectNameCtrl, required: true),
              _field('Project Type', _projectTypeCtrl),
              _field('Work Description', _workDescCtrl, maxLines: 3),
              _field(
                'Quotation Amount',
                _quotationCtrl,
                keyboard: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
              _field('Remarks', _remarksCtrl, maxLines: 3),
              const Divider(height: 32),
              const Text(
                'GPS Location (for attendance geofencing)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Latitude',
                      _latitudeCtrl,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      formatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\d.\-]'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Longitude',
                      _longitudeCtrl,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      formatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\d.\-]'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _field(
                'Radius (meters)',
                _radiusCtrl,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        inputFormatters: formatters,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
