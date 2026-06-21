'use strict';

const { ApiError } = require('../utils/http');

/**
 * Role -> permission keys. Mirrors docs/06-permissions-matrix.md and the
 * Flutter core/permissions/permissions.dart file.
 */
const ROLE_PERMISSIONS = {
  admin: [
    'users:read', 'users:approve', 'users:assign-role',
    'projects:create', 'projects:update', 'projects:delete', 'projects:read-all',
    'stages:design', 'stages:execution', 'stages:override',
    'assignments:workers', 'assignments:staff', 'workplans:write',
    'drawings:upload', 'drawings:delete', 'media:upload',
    'reports:worker', 'reports:supervisor',
    'payments:read', 'payments:write',
    'activity:read-all', 'activity:read-project',
  ],
  supervisor: [
    'projects:read-all',
    'stages:execution',
    'assignments:workers', 'workplans:write',
    'media:upload',
    'reports:supervisor',
    'activity:read-project',
  ],
  designer: [
    'projects:read-all',
    'stages:design',
    'drawings:upload', 'drawings:delete',
    'activity:read-project',
  ],
  worker: [
    'media:upload',
    'reports:worker',
  ],
};

function permissionsForRole(role) {
  return ROLE_PERMISSIONS[role] || [];
}

function hasPermission(role, permission) {
  return permissionsForRole(role).includes(permission);
}

/** Require the user's role to be one of the supplied roles. */
function requireRole(...roles) {
  return (req, _res, next) => {
    if (!req.user) return next(ApiError.unauthorized());
    if (!roles.includes(req.user.role)) {
      return next(ApiError.forbidden('Insufficient role'));
    }
    next();
  };
}

/** Require a specific capability key. */
function requirePermission(permission) {
  return (req, _res, next) => {
    if (!req.user) return next(ApiError.unauthorized());
    if (!hasPermission(req.user.role, permission)) {
      return next(ApiError.forbidden(`Missing permission: ${permission}`));
    }
    next();
  };
}

module.exports = {
  ROLE_PERMISSIONS,
  permissionsForRole,
  hasPermission,
  requireRole,
  requirePermission,
};
