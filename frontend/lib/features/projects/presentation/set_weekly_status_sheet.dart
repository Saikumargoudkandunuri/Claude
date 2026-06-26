import 'package:flutter/material.dart';
import '../data/weekly_status_api.dart';

class SetWeeklyStatusSheet extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String? currentStatus;
  final String? currentNotes;
  final VoidCallback onUpdated;

  const SetWeeklyStatusSheet({
    super.key,
    required this.projectId,
    required this.projectName,
    this.currentStatus,
    this.currentNotes,
    required this.onUpdated,
  });

  @override
  State<SetWeeklyStatusSheet> createState() => _SetWeeklyStatusSheetState();
}

class _SetWeeklyStatusSheetState extends State<SetWeeklyStatusSheet> {
  String? _selected;
  final _notesController = TextEditingController();
  bool _loading = false;
  final _api = WeeklyStatusApi();

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStatus;
    _notesController.text = widget.currentNotes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: Color(0xFF00D1DC)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Weekly Status — ${widget.projectName}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00D1DC)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 4),
          Text('Week of ${_weekLabel()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),

          // 3 Status Cards
          _StatusCard(
            status: 'on_track',
            label: 'On Track 🟢',
            description: 'Work is going as planned.',
            color: const Color(0xFF4CAF50),
            selected: _selected == 'on_track',
            onTap: () => setState(() => _selected = 'on_track'),
          ),
          const SizedBox(height: 8),
          _StatusCard(
            status: 'normal',
            label: 'As Usual 🟡',
            description: 'Work is happening, pace is average.',
            color: const Color(0xFFFFC107),
            selected: _selected == 'normal',
            onTap: () => setState(() => _selected = 'normal'),
          ),
          const SizedBox(height: 8),
          _StatusCard(
            status: 'slow',
            label: 'Slow / At Risk 🔴',
            description: 'Behind schedule. Needs attention.',
            color: const Color(0xFFF44336),
            selected: _selected == 'slow',
            onTap: () => setState(() => _selected = 'slow'),
          ),
          const SizedBox(height: 16),

          // Notes field
          TextField(
            controller: _notesController,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'What caused the delay? Any blockers?',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_selected == null || _loading) ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00D1DC),
                foregroundColor: Colors.white,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Weekly Status',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _weekLabel() {
    final now = DateTime.now();
    final day = now.weekday;
    final monday = now.subtract(Duration(days: day - 1));
    return '${monday.day}/${monday.month}/${monday.year}';
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await _api.setStatus(
        widget.projectId,
        _selected!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Weekly status saved'),
              backgroundColor: Color(0xFF00D1DC)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _StatusCard extends StatelessWidget {
  final String status, label, description;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusCard(
      {required this.status,
      required this.label,
      required this.description,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.grey.shade50,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? color : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? color : Colors.black87,
                    fontSize: 14,
                  )),
              Text(description,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? color.withOpacity(0.85) : Colors.grey,
                  )),
            ]),
          ),
        ]),
      ),
    );
  }
}
