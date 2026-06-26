import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class StageTimelineWidget extends StatefulWidget {
  final String projectId;
  const StageTimelineWidget({super.key, required this.projectId});

  @override
  State<StageTimelineWidget> createState() => _StageTimelineWidgetState();
}

class _StageTimelineWidgetState extends State<StageTimelineWidget> {
  final Dio _dio = DioClient.instance.dio;
  List<dynamic> _timeline = [];
  bool _loading = true;

  static const Map<String, String> _labels = {
    'discussion': 'Discussion',
    '3d_design': '3D Design',
    'drawing': 'Drawing',
    'material_purchase': 'Materials',
    'cutting': 'Cutting',
    'making': 'Making',
    'lamination': 'Lamination',
    'painting': 'Painting',
    'packing': 'Packing',
    'transport': 'Transport',
    'installation': 'Installation',
    'checking': 'Checking',
    'completed': 'Completed',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res =
          await _dio.get('/projects/${widget.projectId}/stage-timeline');
      if (mounted) {
        setState(() {
          _timeline = (res.data['data']?['timeline'] as List?) ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_timeline.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            'Project Stages',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _timeline.length,
            itemBuilder: (context, i) {
              final stage = _timeline[i] as Map<String, dynamic>;
              final status = stage['status'] as String? ?? 'pending';
              final label = _labels[stage['stage']] ??
                  stage['display_name'] ??
                  stage['stage'];
              final isFirst = i == 0;
              final isLast = i == _timeline.length - 1;

              Color dotColor;
              Color lineColor;
              IconData dotIcon;

              switch (status) {
                case 'completed':
                  dotColor = const Color(0xFF00D1DC);
                  lineColor = const Color(0xFF00D1DC);
                  dotIcon = Icons.check_rounded;
                  break;
                case 'current':
                  dotColor = const Color(0xFF00D1DC);
                  lineColor = Colors.grey.shade300;
                  dotIcon = Icons.radio_button_checked_rounded;
                  break;
                default:
                  dotColor = Colors.grey.shade300;
                  lineColor = Colors.grey.shade300;
                  dotIcon = Icons.radio_button_unchecked_rounded;
              }

              return Row(
                children: [
                  if (!isFirst)
                    Container(
                      width: 20,
                      height: 2,
                      color: _lineColorBefore(i),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: status == 'pending'
                              ? Colors.grey.shade100
                              : dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: dotColor, width: 2),
                        ),
                        child: Icon(
                          dotIcon,
                          size: 14,
                          color: status == 'pending'
                              ? Colors.grey.shade400
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 60,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: status == 'current'
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: status == 'pending'
                                ? Colors.grey
                                : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!isLast)
                    Container(width: 20, height: 2, color: lineColor),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Color _lineColorBefore(int index) {
    if (index <= 0) return Colors.grey.shade300;
    final prevStatus =
        (_timeline[index - 1] as Map<String, dynamic>)['status'] as String?;
    return (prevStatus == 'completed')
        ? const Color(0xFF00D1DC)
        : Colors.grey.shade300;
  }
}
