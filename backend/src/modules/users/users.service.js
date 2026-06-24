'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { createNotification } = require('../../utils/notify');
const { publicUser } = require('../auth/auth.service');

async function list({ status, role, q, page, limit }) {
  const where = [];
  const params = [];
  if (status) {
    params.push(status);
    where.push(`status = $${params.length}`);
  }
  if (role) {
    params.push(role);
    where.push(`role = $${params.length}`);
  }
  if (q) {
    params.push(`%${q}%`);
    where.push(`(full_name ILIKE $${params.length} OR email ILIKE $${params.length})`);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const offset = (page - 1) * limit;

  const totalRes = await query(`SELECT COUNT(*)::int AS total FROM users ${whereSql}`, params);
  const { rows } = await query(
    `SELECT * FROM users ${whereSql} ORDER BY created_at DESC
     LIMIT ${limit} OFFSET ${offset}`,
    params
  );
  return {
    data: rows.map(publicUser),
    meta: { page, limit, total: totalRes.rows[0].total },
  };
}

async function listPending() {
  const { rows } = await query(
    `SELECT * FROM users WHERE status = 'pending' ORDER BY created_at ASC`
  );
  return rows.map(publicUser);
}

async function getById(id) {
  const { rows } = await query('SELECT * FROM users WHERE id = $1', [id]);
  if (!rows[0]) throw ApiError.notFound('User not found');
  return rows[0];
}

async function approve(adminId, targetId, role) {
  const target = await getById(targetId);
  if (target.status === 'approved') throw ApiError.conflict('User already approved');

  // Prevent creating multiple admin users
  if (role === 'admin') {
    const { rows: existingAdmins } = await query(
      `SELECT id FROM users WHERE role = 'admin' AND status = 'approved'`
    );
    if (existingAdmins.length > 0) {
      throw ApiError.forbidden('An admin account already exists. Only one admin is allowed.');
    }
  }

  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `UPDATE users
          SET status = 'approved', role = $1, approved_by = $2, approved_at = now()
        WHERE id = $3
        RETURNING *`,
      [role, adminId, targetId]
    );
    await logActivity(
      {
        userId: adminId,
        action: 'user.approve',
        entityType: 'user',
        entityId: targetId,
        description: `Approved ${target.full_name} as ${role}`,
        metadata: { role },
      },
      client
    );
    await createNotification(
      {
        userId: targetId,
        type: 'user.approved',
        title: 'Account approved',
        body: `You have been approved as ${role}. Welcome!`,
        data: { route: 'icms://home' },
      },
      client
    );
    return publicUser(rows[0]);
  });
}

async function reject(adminId, targetId) {
  const target = await getById(targetId);
  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `UPDATE users SET status = 'rejected' WHERE id = $1 RETURNING *`,
      [targetId]
    );
    await logActivity(
      {
        userId: adminId,
        action: 'user.reject',
        entityType: 'user',
        entityId: targetId,
        description: `Rejected ${target.full_name}`,
      },
      client
    );
    await createNotification(
      {
        userId: targetId,
        type: 'user.rejected',
        title: 'Registration rejected',
        body: 'Your registration request was not approved.',
      },
      client
    );
    return publicUser(rows[0]);
  });
}

async function setRole(adminId, targetId, role) {
  await getById(targetId);
  const { rows } = await query('UPDATE users SET role = $1 WHERE id = $2 RETURNING *', [
    role,
    targetId,
  ]);
  await logActivity({
    userId: adminId,
    action: 'user.set-role',
    entityType: 'user',
    entityId: targetId,
    description: `Changed role to ${role}`,
    metadata: { role },
  });
  return publicUser(rows[0]);
}

async function disable(adminId, targetId) {
  await getById(targetId);
  const { rows } = await query(
    `UPDATE users SET status = 'disabled' WHERE id = $1 RETURNING *`,
    [targetId]
  );
  await logActivity({
    userId: adminId,
    action: 'user.disable',
    entityType: 'user',
    entityId: targetId,
    description: 'Disabled account',
  });
  return publicUser(rows[0]);
}

/** Minimal list for assignment pickers (no sensitive data beyond name/role). */
async function assignable(role) {
  const { rows } = await query(
    `SELECT id, full_name, role FROM users
      WHERE role = $1 AND status = 'approved'
      ORDER BY full_name ASC`,
    [role]
  );
  return rows.map((r) => ({ id: r.id, fullName: r.full_name, role: r.role }));
}

module.exports = {
  list,
  listPending,
  approve,
  reject,
  setRole,
  disable,
  assignable,
};
