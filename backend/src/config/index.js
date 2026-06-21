'use strict';

const path = require('path');
const dotenv = require('dotenv');

dotenv.config();

function required(name, fallback) {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === null || value === '') {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(`Missing required environment variable: ${name}`);
    }
  }
  return value;
}

const config = {
  env: process.env.NODE_ENV || 'development',
  isProd: (process.env.NODE_ENV || 'development') === 'production',
  port: parseInt(process.env.PORT || '4000', 10),
  apiPrefix: process.env.API_PREFIX || '/api/v1',
  corsOrigins: (process.env.CORS_ORIGINS || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),

  db: {
    connectionString: process.env.DATABASE_URL || undefined,
    host: process.env.PGHOST || 'localhost',
    port: parseInt(process.env.PGPORT || '5432', 10),
    user: process.env.PGUSER || 'icms',
    password: process.env.PGPASSWORD || 'icms_password',
    database: process.env.PGDATABASE || 'icms',
    ssl: String(process.env.PGSSL || 'false').toLowerCase() === 'true'
      ? { rejectUnauthorized: false }
      : false,
  },

  jwt: {
    accessSecret: required('JWT_ACCESS_SECRET', 'dev_access_secret'),
    refreshSecret: required('JWT_REFRESH_SECRET', 'dev_refresh_secret'),
    accessTtl: process.env.ACCESS_TOKEN_TTL || '15m',
    refreshTtlDays: parseInt(process.env.REFRESH_TOKEN_TTL_DAYS || '30', 10),
  },

  bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS || '12', 10),

  storage: {
    driver: process.env.STORAGE_DRIVER || 'local',
    dir: path.resolve(process.env.STORAGE_DIR || './storage'),
    maxUploadMb: parseInt(process.env.MAX_UPLOAD_MB || '200', 10),
  },

  seedAdmin: {
    name: process.env.SEED_ADMIN_NAME || 'Owner Admin',
    email: process.env.SEED_ADMIN_EMAIL || 'admin@interior.local',
    phone: process.env.SEED_ADMIN_PHONE || '+910000000000',
    password: process.env.SEED_ADMIN_PASSWORD || 'Admin@12345',
  },

  fcm: {
    serverKey: process.env.FCM_SERVER_KEY || '',
  },
};

module.exports = config;
