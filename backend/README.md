# ICMS Backend (Node.js + PostgreSQL)

REST API for the Interior Company Management System. Modular monolith built with Express and raw `pg` (no ORM). JWT auth, RBAC, file storage, activity logging and notifications.

## Requirements
- Node.js 18+ (tested on 20/22)
- PostgreSQL 14+

## Setup

```bash
cp .env.example .env       # configure DB + JWT secrets + storage
npm install
npm run migrate            # apply SQL migrations in src/db/migrations
npm run seed               # create the first admin (idempotent)
npm run dev                # or: npm start
```

API is served at `http://localhost:4000/api/v1` (configurable via `PORT` / `API_PREFIX`).

Health checks: `GET /health` and `GET /health/db`.

## Environment Variables
See `.env.example`. Key ones:

| Var | Purpose |
|-----|---------|
| `DATABASE_URL` or `PG*` | PostgreSQL connection |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | token signing |
| `ACCESS_TOKEN_TTL` (15m), `REFRESH_TOKEN_TTL_DAYS` (30) | token lifetimes |
| `STORAGE_DRIVER` (local/s3), `STORAGE_DIR`, `MAX_UPLOAD_MB` | file storage |
| `SEED_ADMIN_*` | first admin created by `npm run seed` |
| `FCM_SERVER_KEY` | optional push notifications |

## Project Structure
```
src/
├── server.js / app.js        # boot + express wiring
├── config/                   # env parsing
├── db/                       # pool, migrate runner, seed, SQL migrations
├── middleware/               # auth, rbac, validate, error, rateLimit
├── utils/                    # http, jwt, password, activity, notify
├── services/fileStorage.js   # local-disk storage (S3-swappable)
└── modules/                  # auth, users, projects, drawings, reports,
                              # payments, workplans, notifications, activity, dashboard
```
Each module = `routes → controller → service` with Zod schemas. Details in
[../docs/04-backend-architecture.md](../docs/04-backend-architecture.md) and the
API contract in [../docs/05-api-design.md](../docs/05-api-design.md).

## Auth Flow
1. `POST /auth/register` → account `pending`, admins notified.
2. Admin `POST /users/:id/approve` with a role → account `approved`.
3. `POST /auth/login` → `{ accessToken, refreshToken, user }`.
4. `POST /auth/refresh` rotates tokens; `POST /auth/logout` revokes.

## Permissions
Role → capability mapping lives in `src/middleware/rbac.js` and is mirrored in the
Flutter client. Full matrix: [../docs/06-permissions-matrix.md](../docs/06-permissions-matrix.md).

## Drawings: latest-only rule
For `working_drawing`, `measurement_drawing`, `site_drawing`, `pdf_drawing`,
`3d_design` and `quotation`, uploading a new file **replaces** the previous one
(old DB row + physical file are deleted in a transaction). Photos/videos/voice
notes accumulate. Enforced in `src/modules/drawings/files.service.js`.

## Tests
```bash
npm test    # Jest (e.g. RBAC matrix in test/rbac.test.js)
```

## Deployment (Hostinger VPS)

1. **Provision** Ubuntu VPS. Install Node 20+, PostgreSQL 15+, Nginx, Certbot, PM2 (`npm i -g pm2`).
2. **Database**:
   ```sql
   CREATE DATABASE icms;
   CREATE USER icms WITH PASSWORD 'strong_password';
   GRANT ALL PRIVILEGES ON DATABASE icms TO icms;
   ```
3. **Deploy code** and configure `.env` (set strong JWT secrets, `STORAGE_DIR=/var/icms/storage`, real DB creds, `NODE_ENV=production`, `CORS_ORIGINS=https://yourdomain.com`).
   ```bash
   npm ci
   npm run migrate
   npm run seed
   sudo mkdir -p /var/icms/storage && sudo chown -R $USER /var/icms/storage
   ```
4. **Run with PM2**:
   ```bash
   pm2 start src/server.js --name icms-api
   pm2 save && pm2 startup
   ```
5. **Nginx reverse proxy** (`/api` → `localhost:4000`) and serve the Flutter web build as static files:
   ```nginx
   server {
     server_name yourdomain.com;
     location /api/ { proxy_pass http://127.0.0.1:4000; proxy_set_header Host $host; }
     location /     { root /var/www/icms-web; try_files $uri /index.html; }
   }
   ```
6. **TLS**: `sudo certbot --nginx -d yourdomain.com`.
7. **Backups** (cron): nightly `pg_dump` + `rsync` of `/var/icms/storage`.

> To scale storage later, set `STORAGE_DRIVER=s3` and implement the S3 driver in `services/fileStorage.js` — no changes needed in callers.
