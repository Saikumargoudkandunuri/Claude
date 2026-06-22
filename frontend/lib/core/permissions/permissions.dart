/// Client-side mirror of the backend RBAC matrix (backend/src/middleware/rbac.js).
/// Used to show/hide UI. The server remains the source of truth and re-checks
/// every request.
class Permissions {
  Permissions._();

  static const Map<String, List<String>> _rolePermissions = {
    'admin': [
      'users:read', 'users:approve', 'users:assign-role',
      'projects:create', 'projects:update', 'projects:delete', 'projects:read-all',
      'stages:design', 'stages:execution', 'stages:override',
      'assignments:workers', 'assignments:staff', 'workplans:write',
      'drawings:upload', 'drawings:delete', 'media:upload',
      'reports:worker', 'reports:supervisor',
      'payments:read', 'payments:write',
      'activity:read-all', 'activity:read-project',
    ],
    'supervisor': [
      'projects:read-all',
      'stages:execution',
      'assignments:workers', 'workplans:write',
      'media:upload',
      'reports:supervisor',
      'activity:read-project',
    ],
    'designer': [
      'projects:read-all',
      'stages:design',
      'drawings:upload', 'drawings:delete',
      'media:upload',
      'activity:read-project',
    ],
    'worker': [
      'media:upload',
      'reports:worker',
    ],
  };

  static const List<String> designStages = ['discussion', '3d_design', 'drawing'];

  static List<String> forRole(String? role) => _rolePermissions[role] ?? const [];

  static bool can(String? role, String permission) =>
      forRole(role).contains(permission);

  /// Can this role move a project into [stage]?
  static bool canControlStage(String? role, String stage) {
    if (role == 'admin') return true;
    if (role == 'designer') return designStages.contains(stage);
    if (role == 'supervisor') return !designStages.contains(stage);
    return false;
  }

  /// Categories a role may upload.
  static bool canUploadDrawings(String? role) =>
      role == 'admin' || role == 'designer';

  static bool canUploadMedia(String? role) =>
      role == 'admin' || role == 'supervisor' || role == 'worker' || role == 'designer';
}
