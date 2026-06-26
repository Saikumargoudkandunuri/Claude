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
    // Ensure PIN is set for existing admin
    const pinHash = await hashPassword('1234');
    await query('UPDATE users SET pin_hash = $1 WHERE id = $2', [pinHash, existing.rows[0].id]);
    // eslint-disable-next-line no-console
    console.log(`Admin already exists: ${email} — PIN updated to 1234`);
    return;
  }

  const passwordHash = await hashPassword(password);
  const pinHash = await hashPassword('1234');
  const { rows } = await query(
    `INSERT INTO users (full_name, email, phone, password_hash, pin_hash, role, status, approved_at)
     VALUES ($1,$2,$3,$4,$5,'admin','approved', now())
     RETURNING id, email`,
    [name, email, phone, passwordHash, pinHash]
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
