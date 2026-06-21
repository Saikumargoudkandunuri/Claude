# 04 — Backend Architecture (Node.js + PostgreSQL)

A **modular monolith** built with Express. Each business area is a self-contained module with routes → controller → service → repository layers. Implemented in `backend/`.

## 4.1 Folder Structure

```
backend/
├── package.json
├── .env.example
├── README.md
└── src/
    ├── server.js                 # boot http server
    ├── app.js                    # express app: middleware + mount routers
    ├── config/
    │   └── index.js              # env parsing & validation
    ├── db/
    │   ├── pool.js               # pg Pool + query helper + tx helper
    │   ├── migrate.js            # runs SQL migrations in order
    │   ├── seed.js               # seeds first admin + demo data
    │   ├── migrations/
    │   │   ├── 001_extensions_and_enums.sql
    │   │   ├── 002_users_and_auth.sql
    │   │   ├── 003_projects.sql
    │   │   ├── 004_files.sql
    │   │   ├── 005_reports_and_plans.sql
    │   │   ├── 006_payments.sql
    │   │   ├── 007_notifications.sql
    │   │   ├── 008_activity_logs.sql
    │   │   └── 009_triggers_and_indexes.sql
    │   └── seeds/seed_data.sql
    ├── middleware/
    │   ├── auth.js               # verify JWT → req.user
    │   ├── rbac.js               # requireRole / requirePermission
    │   ├── validate.js           # zod schema validation
    │   ├── error.js              # central error handler
    │   ├── notFound.js
    │   └── rateLimit.js
    ├── utils/
    │   ├── jwt.js                # sign/verify access & refresh
    │   ├── password.js           # bcrypt hash/compare
    │   ├── http.js               # asyncHandler, ApiError, ok()
    │   ├── activity.js           # logActivity()
    │   └── notify.js             # createNotification() + push
    ├── services/
    │   └── fileStorage.js        # storage abstraction (local disk / S3)
    └── modules/
        ├── auth/        {auth.routes.js, auth.controller.js, auth.service.js, auth.schema.js}
        ├── users/       {users.routes.js, users.controller.js, users.service.js, users.schema.js}
        ├── projects/    {projects.routes.js, projects.controller.js, projects.service.js, projects.schema.js}
        ├── stages/      {stages.routes.js, stages.controller.js, stages.service.js}
        ├── drawings/    {files.routes.js, files.controller.js, files.service.js}
        ├── reports/     {reports.routes.js, reports.controller.js, reports.service.js, reports.schema.js}
        ├── payments/    {payments.routes.js, payments.controller.js, payments.service.js, payments.schema.js}
        ├── workplans/   {workplans.routes.js, workplans.controller.js, workplans.service.js, workplans.schema.js}
        ├── notifications/{notifications.routes.js, notifications.controller.js, notifications.service.js}
        ├── activity/    {activity.routes.js, activity.controller.js, activity.service.js}
        └── dashboard/   {dashboard.routes.js, dashboard.controller.js, dashboard.service.js}
```

## 4.2 Layer Responsibilities

| Layer | Responsibility |
|-------|----------------|
| **routes** | declare paths, attach `auth`, `rbac`, `validate`, point to controller |
| **controller** | parse req, call service, format response (`ok(res, data)`) |
| **service** | business logic, transactions, calls repositories/other services, logs activity, fires notifications |
| **db (pool)** | parameterized SQL via `pg`; transactions via `withTransaction` |

No ORM — raw parameterized SQL via `pg` keeps it lightweight and Hostinger-friendly, with full control over the dashboard aggregate queries.

## 4.3 Request Pipeline

```
HTTP → helmet → cors → json/multipart parser → rateLimit
     → router → authenticate(JWT) → authorize(RBAC) → validate(zod)
     → controller → service → pg
     → response  (errors → central error handler → JSON {error})
```

## 4.4 Authentication & Tokens

- **Login** issues `accessToken` (JWT, 15 min) + `refreshToken` (random, stored hashed in `refresh_tokens`, 30 days).
- **`/auth/refresh`** rotates refresh token (revoke old, issue new).
- **`/auth/logout`** revokes the presented refresh token.
- Passwords hashed with **bcrypt** (cost 12).
- Access token payload: `{ sub: userId, role, status }`.

## 4.5 Authorization (RBAC)

- `requireRole('admin', ...)` — coarse gate.
- `requirePermission('payments:write')` — capability gate, derived from the permissions matrix (doc 06).
- Resource-level checks in services (e.g. a worker can only read projects they're assigned to; a worker can only edit their own report).

## 4.6 File Storage Service

`services/fileStorage.js` exposes:
```
save(buffer/stream, {projectId, category, originalName}) → { storageKey, sizeBytes, mimeType }
remove(storageKey)
streamFor(storageKey) → readable stream  (for download/preview)
publicPathFor(storageKey) → relative URL served by /files/:id/download
```
Default driver: **local disk** under `STORAGE_DIR` (e.g. `/var/icms/storage/<projectId>/<category>/<uuid>-<name>`), Hostinger-compatible. Driver is swappable to S3/Spaces by env (`STORAGE_DRIVER=s3`).

Latest-only enforcement lives in `drawings/files.service.js`: on upload of a single-instance category, it deletes the prior row + file inside a transaction before inserting the new one.

## 4.7 Activity Logging & Notifications

- `utils/activity.logActivity(client, {userId, projectId, action, entityType, entityId, description, metadata})` — called inside the same transaction as the mutation.
- `utils/notify.createNotification({userId, type, title, body, projectId, data})` — inserts a notification row and (if `push_token` present) sends FCM. Fan-out helpers notify all admins, a project's supervisor, or a set of workers.

## 4.8 Error Handling

- `ApiError(status, code, message)` thrown by services.
- Central handler returns `{ error: { code, message, details? } }` with proper HTTP status.
- Validation errors from zod → 422 with field details.
- Unhandled errors → 500, logged, generic message to client.

## 4.9 Security Hardening

helmet, CORS allowlist, express-rate-limit on `/auth/*`, body size limits, parameterized SQL (no injection), JWT expiry + rotation, bcrypt, file type/size validation on upload, no PII of workers/designers leaked to worker responses (serializers strip fields by role).

## 4.10 Observability

- `pino` structured logging with request IDs.
- `/health` (liveness) and `/health/db` (DB check) endpoints.
- All mutations create activity logs (functional audit trail).
