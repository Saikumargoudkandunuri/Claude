'use strict';

/**
 * Seeds the first Admin account (idempotent).
 * Run after migrations: `npm run seed`.
 */
const { pool, query } = require('./pool');
const { hashPassword } = require('../utils/password');
const config = require('../config');

async function run() {
  const { name, email, phone, password } = config.seedAdmin;

  const existing = await query('SELECT id, role FROM users WHERE email = $1', [email]);
  if (existing.rows.length > 0) {
    // eslint-disable-next-line no-console
    console.log(`Admin already exists: ${email}`);
    return;
  }

  const passwordHash = await hashPassword(password);
  const { rows } = await query(
    `INSERT INTO users (full_name, email, phone, password_hash, role, status, approved_at)
     VALUES ($1,$2,$3,$4,'admin','approved', now())
     RETURNING id, email`,
    [name, email, phone, passwordHash]
  );

  // eslint-disable-next-line no-console
  console.log(`Seeded admin: ${rows[0].email} (id=${rows[0].id})`);
  // eslint-disable-next-line no-console
  console.log(`Login password: ${password} (change after first login)`);
}

if (require.main === module) {
  run()
    .then(() => pool.end())
    .catch((err) => {
      // eslint-disable-next-line no-console
      console.error(err);
      pool.end().finally(() => process.exit(1));
    });
}

module.exports = { run };
