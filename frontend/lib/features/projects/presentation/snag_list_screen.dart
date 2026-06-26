import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class SnagListScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String userRole;
  const SnagListScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.userRole,
  });

  @override
  State<SnagListScreen> createState() => _SnagListScreenState();
}

class _SnagListScreenState extends State<SnagListScreen>
    with SingleTickerProviderStateMixin {
  final Dio _dio = DioClient.instance.dio;
  late TabController _tabs;
  List<dynamic> _items = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get('/projects/${widget.projectId}/snags');
      if (mounted)
        setState(() {
          _items = (res.data['data'] as List?) ?? [];
          _summary = (res.data['summary'] as Map<String, dynamic>?) ?? {};
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _filtered(String status) =>
      _items.where((i) => (i as Map)['status'] == status).toList();

  Color _priorityColor(String? p) {
    switch (p) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate =
        widget.userRole == 'admin' || widget.userRole == 'supervisor';

    return Scaffold(
      appBar: AppBar(
        title: Text('Snag List — ${widget.projectName}',
            style: const TextStyle(fontSize: 14)),
        backgroundColor: const Color(0xFF00D1DC),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Open (${_summary['open_count'] ?? 0})'),
            Tab(text: 'Resolved (${_summary['resolved_count'] ?? 0})'),
            Tab(text: 'Closed (${_summary['closed_count'] ?? 0})'),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              backgroundColor: const Color(0xFF00D1DC),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Snag'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildList(_filtered('open'), 'open'),
                _buildList(_filtered('resolved'), 'resolved'),
                _buildList(_filtered('closed'), 'closed'),
              ],
            ),
    );
  }

  Widget _buildList(List items, String status) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text('No $status items', style: const TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = items[i] as Map<String, dynamic>;
          final priority = item['priority'] as String? ?? 'medium';
          final pColor = _priorityColor(priority);
          final isWorker = widget.userRole == 'worker';
          final canResolve = isWorker && item['status'] == 'open';
          final canClose = !isWorker && item['status'] == 'resolved';

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 4,
                    height: 40,
                    color: pColor,
                    margin: const EdgeInsets.only(right: 10)),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title']?.toString() ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        if (item['assigned_to_name'] != null)
                          Text('Assigned: ${item['assigned_to_name']}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(priority.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: pColor,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              if (item['description'] != null) ...[
                const SizedBox(height: 8),
                Text(item['description'].toString(),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
              if (item['resolution_note'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('Resolution: ${item['resolution_note']}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.green)),
                ),
              ],
              if (canResolve || canClose) ...[
                const SizedBox(height: 10),
                Row(children: [
                  if (canResolve)
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _resolveItem(item['id'].toString()),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00D1DC),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Mark Resolved',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  if (canClose)
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _closeItem(item['id'].toString()),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Close Item',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                ]),
              ],
            ]),
          );
        },
      ),
    );
  }

  Future<void> _resolveItem(String itemId) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resolve Snag Item'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Describe how it was fixed...',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, noteCtrl.text),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00D1DC)),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (note == null) return;
    try {
      await _dio
          .put('/snags/$itemId/resolve', data: {'resolutionNote': note.trim()});
      _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Marked as resolved'),
            backgroundColor: Color(0xFF00D1DC)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _closeItem(String itemId) async {
    try {
      await _dio.put('/snags/$itemId/close');
      _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Item closed'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showCreateDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New Snag Item'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Issue title *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: priority,
              decoration: const InputDecoration(
                  labelText: 'Priority', border: OutlineInputBorder()),
              items: ['low', 'medium', 'high']
                  .map((p) =>
                      DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                  .toList(),
              onChanged: (v) => setS(() => priority = v!),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _dio.post('/projects/${widget.projectId}/snags', data: {
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'priority': priority,
                  });
                  _load();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('✅ Snag item added'),
                        backgroundColor: Color(0xFF00D1DC)));
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red));
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1DC)),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
