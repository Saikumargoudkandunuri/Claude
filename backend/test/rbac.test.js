'use strict';

const { hasPermission, permissionsForRole } = require('../src/middleware/rbac');

describe('RBAC permission matrix', () => {
  test('admin has full payment control', () => {
    expect(hasPermission('admin', 'payments:write')).toBe(true);
    expect(hasPermission('admin', 'projects:create')).toBe(true);
    expect(hasPermission('admin', 'stages:override')).toBe(true);
  });

  test('supervisor cannot touch payments or upload drawings', () => {
    expect(hasPermission('supervisor', 'payments:write')).toBe(false);
    expect(hasPermission('supervisor', 'drawings:upload')).toBe(false);
    expect(hasPermission('supervisor', 'stages:execution')).toBe(true);
  });

  test('designer can upload drawings but not control execution stages', () => {
    expect(hasPermission('designer', 'drawings:upload')).toBe(true);
    expect(hasPermission('designer', 'stages:design')).toBe(true);
    expect(hasPermission('designer', 'stages:execution')).toBe(false);
    expect(hasPermission('designer', 'payments:read')).toBe(false);
  });

  test('worker has the most limited permissions', () => {
    const perms = permissionsForRole('worker');
    expect(perms).toContain('media:upload');
    expect(perms).toContain('reports:worker');
    expect(hasPermission('worker', 'projects:create')).toBe(false);
    expect(hasPermission('worker', 'payments:read')).toBe(false);
    expect(hasPermission('worker', 'drawings:upload')).toBe(false);
  });

  test('unknown role has no permissions', () => {
    expect(permissionsForRole('ghost')).toEqual([]);
  });
});
