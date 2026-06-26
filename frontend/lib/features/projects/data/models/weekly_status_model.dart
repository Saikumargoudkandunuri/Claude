class WeeklyStatusModel {
  final String id;
  final String projectId;
  final String status; // 'on_track' | 'normal' | 'slow'
  final String? notes;
  final String setByName;
  final String setByRole;
  final DateTime weekStart;
  final DateTime createdAt;

  const WeeklyStatusModel({
    required this.id,
    required this.projectId,
    required this.status,
    this.notes,
    required this.setByName,
    required this.setByRole,
    required this.weekStart,
    required this.createdAt,
  });

  factory WeeklyStatusModel.fromJson(Map<String, dynamic> json) {
    return WeeklyStatusModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      setByName: (json['set_by_name'] ?? '') as String,
      setByRole: (json['set_by_role'] ?? '') as String,
      weekStart: DateTime.parse(json['week_start'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'status': status,
        'notes': notes,
        'set_by_name': setByName,
        'set_by_role': setByRole,
        'week_start': weekStart.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
