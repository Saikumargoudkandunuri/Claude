'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../../db/pool');
const config = require('../../config');
const { ApiError } = require('../../utils/http');

/**
 * Lookup a customer by mobile number in the customers table.
 * Returns { found, customerName, pinSet } or throws 404.
 */
async function checkMobile(mobile) {
  const { rows } = await query(
    `SELECT c.id, c.name, c.pin_set
       FROM customers c
      WHERE c.mobile = $1
      LIMIT 1`,
    [mobile]
  );

  if (!rows.length) {
    throw ApiError.notFound('Mobile number not found');
  }

  const row = rows[0];
  return {
    found: true,
    customerName: row.name,
    pinSet: row.pin_set,
  };
}

/**
 * First-time PIN creation for a customer.
 * Verifies pin_set is false (else 409), hashes PIN, updates customers table.
 */
async function setPin(mobile, pin) {
  const { rows } = await query(
    `SELECT id, pin_set
       FROM customers
      WHERE mobile = $1
      LIMIT 1`,
    [mobile]
  );

  if (!rows.length) {
    throw ApiError.notFound('Mobile number not found');
  }

  const customer = rows[0];

  if (customer.pin_set) {
    throw ApiError.conflict('PIN already set');
  }

  const hash = await bcrypt.hash(pin, config.bcryptRounds);

  await query(
    `UPDATE customers
        SET pin_hash = $1, pin_set = true, updated_at = now()
      WHERE id = $2`,
    [hash, customer.id]
  );
}

/**
 * Authenticate customer with mobile + PIN.
 * Returns { token, customerName, customerId, projectId }.
 * JWT payload includes customerId for multi-project support.
 */
async function login(mobile, pin) {
  const { rows } = await query(
    `SELECT c.id AS customer_id, c.name, c.pin_hash, c.pin_set,
            p.id AS project_id
       FROM customers c
       LEFT JOIN projects p ON p.customer_id = c.id
      WHERE c.mobile = $1
      LIMIT 1`,
    [mobile]
  );

  if (!rows.length || !rows[0].pin_set) {
    throw ApiError.unauthorized('Invalid credentials');
  }

  const row = rows[0];

  const valid = await bcrypt.compare(pin, row.pin_hash);
  if (!valid) {
    throw ApiError.unauthorized('Invalid credentials');
  }

  // Issue customer JWT with customerId
  const token = jwt.sign(
    {
      role: 'customer',
      customerId: row.customer_id,
      projectId: row.project_id,
      customerName: row.name,
      mobile,
    },
    config.customerJwt.secret,
    { expiresIn: config.customerJwt.expiry }
  );

  // Update last login timestamp
  await query(
    `UPDATE customers SET last_login = now(), updated_at = now() WHERE id = $1`,
    [row.customer_id]
  );

  return {
    token,
    customerName: row.name,
    customerId: row.customer_id,
    projectId: row.project_id,
  };
}

/**
 * Get project overview with explicit field whitelist.
 * Does NOT use serializeProject — returns only customer-safe fields.
 */
async function getOverview(projectId) {
  const { rows } = await query(
    `SELECT p.project_name, c.name AS customer_name, p.current_stage,
            p.start_date, p.expected_completion_date, p.project_type, p.address
       FROM projects p
       LEFT JOIN customers c ON c.id = p.customer_id
      WHERE p.id = $1`,
    [projectId]
  );

  if (!rows.length) {
    throw ApiError.notFound('Project not found');
  }

  return rows[0];
}

/**
 * Get project stage timeline from project_stage_history.
 * Returns stages ordered by changed_at ASC.
 */
async function getTimeline(projectId) {
  const { rows } = await query(
    `SELECT id, stage, changed_at, changed_by
       FROM project_stage_history
      WHERE project_id = $1
      ORDER BY changed_at ASC`,
    [projectId]
  );

  return rows;
}

/**
 * Get site photos for the project.
 * Returns id, original_name, created_at ordered by most recent first.
 */
async function getPhotos(projectId) {
  const { rows } = await query(
    `SELECT id, original_name, created_at
       FROM files
      WHERE project_id = $1 AND category = 'photo'
      ORDER BY created_at DESC`,
    [projectId]
  );

  return rows;
}

/**
 * Get approved drawings for the project.
 * Returns only drawings with approval_status = 'approved'.
 */
async function getDrawings(projectId) {
  const { rows } = await query(
    `SELECT id, original_name, version_number, approved_at, created_at
       FROM files
      WHERE project_id = $1
        AND category = 'drawing'
        AND approval_status = 'approved'
      ORDER BY created_at DESC`,
    [projectId]
  );

  return rows;
}

/**
 * Get payment summary for the project.
 * Returns quotation_amount, total_received, and outstanding_balance.
 */
async function getPayments(projectId) {
  const { rows } = await query(
    `SELECT quotation_amount, total_received
       FROM payments
      WHERE project_id = $1`,
    [projectId]
  );

  if (!rows.length) {
    return {
      quotation_amount: 0,
      total_received: 0,
      outstanding_balance: 0,
    };
  }

  const row = rows[0];
  const quotation = parseFloat(row.quotation_amount) || 0;
  const received = parseFloat(row.total_received) || 0;

  return {
    quotation_amount: quotation,
    total_received: received,
    outstanding_balance: quotation - received,
  };
}

/**
 * Get all notifications for the project, ordered by most recent.
 */
async function getNotifications(projectId) {
  const { rows } = await query(
    `SELECT id, title, body, is_read, created_at
       FROM customer_notifications
      WHERE project_id = $1
      ORDER BY created_at DESC`,
    [projectId]
  );

  return rows;
}

/**
 * Mark a specific notification as read.
 * Scoped to project_id for security.
 */
async function markNotificationRead(notificationId, projectId) {
  const { rowCount } = await query(
    `UPDATE customer_notifications
        SET is_read = true
      WHERE id = $1 AND project_id = $2`,
    [notificationId, projectId]
  );

  if (!rowCount) {
    throw ApiError.notFound('Notification not found');
  }
}

/**
 * Get messages for the project (admin announcements).
 * Excludes posted_by field — customer should not see who posted.
 */
async function getMessages(projectId) {
  const { rows } = await query(
    `SELECT id, title, body, created_at
       FROM customer_messages
      WHERE project_id = $1
      ORDER BY created_at DESC`,
    [projectId]
  );

  return rows;
}

/**
 * Post an announcement/message to a customer's project.
 * Called by admin via staff routes.
 */
async function postAnnouncement(projectId, title, body, adminUserId) {
  // Resolve customer_id from the project
  const { rows: projRows } = await query(
    `SELECT customer_id FROM projects WHERE id = $1`,
    [projectId]
  );

  const customerId = projRows.length ? projRows[0].customer_id : null;

  const { rows } = await query(
    `INSERT INTO customer_messages (project_id, customer_id, title, body, posted_by)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, title, body, created_at`,
    [projectId, customerId, title, body, adminUserId]
  );

  return rows[0];
}

/**
 * Reset a customer's PIN (admin action).
 * Clears pin_hash and sets pin_set to false on the customers table.
 * Accepts customerId directly (admin provides customer UUID).
 */
async function resetPin(customerId) {
  const { rowCount } = await query(
    `UPDATE customers
        SET pin_hash = NULL, pin_set = false, updated_at = now()
      WHERE id = $1`,
    [customerId]
  );

  if (!rowCount) {
    throw ApiError.notFound('Customer not found');
  }
}

/**
 * Create a new customer record (admin action).
 * Optionally links the customer to a project.
 */
async function createCustomer(fullName, mobile, projectId) {
  // Check if mobile already exists
  const { rows: existing } = await query(
    `SELECT id FROM customers WHERE mobile = $1`,
    [mobile]
  );

  if (existing.length) {
    throw ApiError.conflict('A customer with this mobile already exists');
  }

  const { rows } = await query(
    `INSERT INTO customers (name, mobile)
     VALUES ($1, $2)
     RETURNING id, name AS full_name, mobile, pin_set, created_at`,
    [fullName, mobile]
  );

  const customer = rows[0];

  // Link to project if provided
  if (projectId) {
    await query(
      `UPDATE projects SET customer_id = $1 WHERE id = $2`,
      [customer.id, projectId]
    );
  }

  return customer;
}

module.exports = {
  checkMobile,
  setPin,
  login,
  getOverview,
  getTimeline,
  getPhotos,
  getDrawings,
  getPayments,
  getNotifications,
  markNotificationRead,
  getMessages,
  postAnnouncement,
  resetPin,
  createCustomer,
};
