/// Authenticated user as returned by the API.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.workerStatus,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? role; // null until admin assigns
  final String status; // pending | approved | rejected | disabled
  final String? workerStatus;

  bool get isApproved => status == 'approved' && role != null;
  bool get isPending => status == 'pending';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String?,
        status: json['status'] as String? ?? 'pending',
        workerStatus: json['workerStatus'] as String?,
      );

  AuthUser copyWith({String? workerStatus}) => AuthUser(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        role: role,
        status: status,
        workerStatus: workerStatus ?? this.workerStatus,
      );
}
