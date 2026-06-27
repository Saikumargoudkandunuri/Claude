import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_client.dart';

class WorkerPayScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  const WorkerPayScreen({
    super.key,
    required this.workerId,
    required this.workerName,
  });
  @override
  State<WorkerPayScreen> createState() => _WorkerPayScreenState();
}

class _WorkerPayScreenState extends State<WorkerPayScreen> {
  final Dio _dio = DioClient.instance.dio;
  String _monthYear = DateTime.now().toIso8601String().substring(0, 7);
  Map<String, dynamic>? _salaryCalc;
  List<dynamic> _payments = [];
  bool _loading = true;
  final _salaryCtrl = TextEditingController();
  bool _editingSalary = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _dio.get('/payroll/workers/${widget.workerId}/salary-preview',
            queryParameters: {'month': _monthYear}),
        _dio.get('/payroll/workers/${widget.workerId}/payments',
            queryParameters: {'month': _monthYear}),
      ]);
      if (mounted) {
        setState(() {
          _salaryCalc = results[0].data['data'];
          _payments = results[1].data['data'] ?? [];
          _salaryCtrl.text = _fmt(_salaryCalc?['monthly_rate']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSalary() async {
    final val = double.tryParse(_salaryCtrl.text.replaceAll(',', ''));
    if (val == null || val <= 0) return;
    try {
      await _dio.post('/payroll/salary/set', data: {
        'worker_id': widget.workerId,
        'monthly_salary': val,
      });
      setState(() => _editingSalary = false);
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Monthly salary updated'),
          backgroundColor: Color(0xFF00D1DC),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showPaySheet(String paymentType) async {
    final calc = _salaryCalc;
    final prefill = paymentType == 'salary' ? _fmt(calc?['balance_due']) : '';
    final amountCtrl = TextEditingController(text: prefill);
    final notesCtrl = TextEditingController();
    File? proofFile;
    bool submitting = false;

    final typeColor = paymentType == 'advance'
        ? Colors.orange
        : paymentType == 'bonus'
            ? Colors.green
            : const Color(0xFF00D1DC);
    final typeLabel = paymentType == 'advance'
        ? 'Advance'
        : paymentType == 'bonus'
            ? 'Bonus'
            : 'Salary Payment';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_rounded, color: typeColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$typeLabel — ${widget.workerName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹) *',
                  prefixText: '₹ ',
                  border: const OutlineInputBorder(),
                  hintText: paymentType == 'salary'
                      ? 'Balance: ₹${_fmt(calc?['balance_due'])}'
                      : '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  try {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null)
                      setS(() => proofFile = File(picked.path));
                  } catch (_) {}
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          proofFile != null ? typeColor : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color:
                        proofFile != null ? typeColor.withOpacity(0.05) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        proofFile != null
                            ? Icons.check_circle_rounded
                            : Icons.add_photo_alternate_rounded,
                        color: proofFile != null
                            ? typeColor
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        proofFile != null
                            ? 'Proof attached ✓'
                            : 'Attach payment proof (optional)',
                        style: TextStyle(
                          color: proofFile != null ? typeColor : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final amount = double.tryParse(
                            amountCtrl.text.trim().replaceAll(',', ''),
                          );
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid amount'),
                              ),
                            );
                            return;
                          }
                          setS(() => submitting = true);
                          try {
                            final formData = FormData.fromMap({
                              'payment_type': paymentType,
                              'amount': amount.toString(),
                              'month_year': _monthYear,
                              if (notesCtrl.text.trim().isNotEmpty)
                                'notes': notesCtrl.text.trim(),
                              if (proofFile != null)
                                'proof_image': await MultipartFile.fromFile(
                                  proofFile!.path,
                                  filename:
                                      'proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                ),
                            });
                            await _dio.post(
                              '/payroll/workers/${widget.workerId}/payments',
                              data: formData,
                              options:
                                  Options(contentType: 'multipart/form-data'),
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadAll();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ $typeLabel recorded'),
                                  backgroundColor: typeColor,
                                ),
                              );
                            }
                          } catch (e) {
                            setS(() => submitting = false);
                            if (mounted) {
                              String msg = 'Error';
                              if (e is DioException) {
                                final data = e.response?.data;
                                if (data is Map) {
                                  msg = data['message']?.toString() ?? 'Error';
                                }
                              }
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: typeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Record $typeLabel',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calc = _salaryCalc;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.workerName} — Pay',
            style: const TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xFF00D1DC),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _pickMonth,
            child: Text(_monthLabel(_monthYear),
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Monthly salary editable
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Monthly salary',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(
                                    () => _editingSalary = !_editingSalary),
                                child: Icon(
                                  _editingSalary
                                      ? Icons.close
                                      : Icons.edit_rounded,
                                  size: 16,
                                  color: const Color(0xFF00D1DC),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _editingSalary
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _salaryCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        autofocus: true,
                                        decoration: const InputDecoration(
                                          prefixText: '₹ ',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _saveSalary,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF00D1DC),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                      ),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Text(
                                      '₹${_fmt(calc?['monthly_rate'])}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00D1DC),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '/ ${calc?['working_days'] ?? 26} days',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Salary breakdown
                    if (calc != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D1DC).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00D1DC).withOpacity(0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_monthLabel(_monthYear),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.green.shade300),
                                  ),
                                  child: Text(
                                    'Balance: ₹${_fmt(calc['balance_due'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statBox('${calc['days_at_site']}', 'Site',
                                    const Color(0xFF00D1DC)),
                                _statBox('${calc['days_workshop']}', 'Workshop',
                                    const Color(0xFF185FA5)),
                                _statBox('${calc['days_leave']}', 'Leave',
                                    Colors.orange),
                                _statBox('${calc['days_absent']}', 'Absent',
                                    Colors.red),
                              ],
                            ),
                            const Divider(height: 20),
                            _calcRow(
                                'Daily rate', '₹${_fmt(calc['daily_rate'])}'),
                            _calcRow('Gross earned',
                                '₹${_fmt(calc['gross_earned'])}'),
                            _calcRow(
                                'Advances', '− ₹${_fmt(calc['advances_paid'])}',
                                color: Colors.red),
                            if ((calc['bonuses'] ?? 0) > 0)
                              _calcRow('Bonuses', '+ ₹${_fmt(calc['bonuses'])}',
                                  color: Colors.green),
                            const Divider(height: 12),
                            _calcRow(
                              'Net payable',
                              '₹${_fmt(calc['balance_due'])}',
                              bold: true,
                              color: const Color(0xFF00D1DC),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _actionBtn(
                              'Advance',
                              Colors.orange,
                              Icons.account_balance_wallet_rounded,
                              () => _showPaySheet('advance')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionBtn('Bonus', Colors.green,
                              Icons.star_rounded, () => _showPaySheet('bonus')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionBtn(
                              'Pay Salary',
                              const Color(0xFF00D1DC),
                              Icons.payments_rounded,
                              () => _showPaySheet('salary')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Payment history
                    const Text('Payment history',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 10),
                    if (_payments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('No payments this month',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      )
                    else
                      ..._payments.map((pmt) => _paymentTile(pmt)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _calcRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                color: color ?? Colors.black87,
              )),
        ],
      ),
    );
  }

  Widget _actionBtn(
      String label, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(dynamic pmt) {
    final type = pmt['payment_type'] as String;
    final color = type == 'advance'
        ? Colors.orange
        : type == 'bonus'
            ? Colors.green
            : const Color(0xFF00D1DC);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 44,
              color: color,
              margin: const EdgeInsets.only(right: 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 2),
                Text(
                  '${pmt['paid_by_name'] ?? ''} · ${_fmtDate(pmt['paid_at'])}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (pmt['notes'] != null && pmt['notes'].toString().isNotEmpty)
                  Text(pmt['notes'].toString(),
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text('₹${_fmt(pmt['amount'])}',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(int.parse(_monthYear.split('-')[0]),
          int.parse(_monthYear.split('-')[1])),
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _monthYear =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
      _loadAll();
    }
  }

  String _monthLabel(String ym) {
    final p = ym.split('-');
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${m[int.tryParse(p[1]) ?? 0]} ${p[0]}';
  }

  String _fmtDate(dynamic iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso.toString())?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final d = double.tryParse(v.toString()) ?? 0.0;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
  }
}
