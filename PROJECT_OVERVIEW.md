# Work Management — Full Application Documentation

> **For:** Future AI sessions (Claude / Kiro) and developers picking up this codebase.
> **Read this first** before making changes. It explains the whole app: what it does,
> how the backend and frontend are wired, what every dashboard shows, and the rules
> (RBAC, customer privacy, auth) that must NOT be broken.

---

## 1. What this app is

**Work Management** (internal codename **ICMS — Interior Company Management System**),
branded for **Metal & More Interiors**. It is a construction / interior-fit-out site
management app used by an interior company to run projects end-to-end: from design,
to on-site execution, daily reporting, drawings, payments, and team coordination.

- **Frontend:** Flutter (Android primary, Web as Windows fallback). Riverpod + GoRouter + Dio.
- **Backend:** Node.js + Express + PostgreSQL. JWT auth. Socket.IO for real-time chat.
- **Hosting:** Render (`https://icms-backend-s2va.onrender.com`). Branch deployed: `main`.
- **Repo:** `https://github.com/Saikumargoudkandunuri/Claude`

### Repo layout
```
c:\Users\Admin\Claude\
├── backend\          Node/Express API + PostgreSQL migrations
├── frontend\         Flutter app
├── .claude\          Claude agent/spec config (not app code)
└── PROJECT_OVERVIEW.md  (this file)
```

### The 4 roles
| Role | Purpose |
|------|---------|
| **admin** | Full control: projects, users, payments, assignments, workforce, reports. Only ONE admin allowed. |
| **supervisor** | Runs assigned sites: workers, work plans, supervisor reports, site progress. |
| **designer** | Design stage: uploads 3D designs / working drawings / quotations. Always shown as "Showroom". |
| **worker** | On-site field worker: sees only ASSIGNED projects, submits reports, chats, opens drawings. Heavily privacy-restricted. |

---

## 2. Backend

**Path:** `backend/src`

### 2.1 Entry / wiring
- `app.js` — builds the Express app, mounts all routers under the API prefix (`/api/v1`).
  - `/auth` is public (register/login/pin-login/refresh). Everything else requires
    `authenticate` + `requireApproved`.
  - Many routers mount at `/` because they declare absolute paths
    (e.g. `/projects/:id/reports`).
- `server.js` — creates the HTTP server, attaches **Socket.IO** (`initSocket`), and
  stores it via `app.set('io', io)` so controllers can emit real-time events.
- `config/index.js` — env config. Key fields: `apiPrefix`, `corsOrigins`, `publicUrl`
  (used to build correct public file download URLs behind Render's proxy), JWT secrets.

### 2.2 Module pattern
Every feature in `src/modules/<name>/` follows the same shape:
- `*.routes.js` — Express routes + middleware (auth, rbac, validation).
- `*.controller.js` — request/response handling.
- `*.service.js` — business logic + SQL queries.
- `*.schema.js` — (some modules) Joi/zod validation schemas.

### 2.3 The 15 modules
| Module | Responsibility |
|--------|----------------|
| `auth` | Register, **PIN login**, refresh tokens, change PIN, reset PIN, profile avatar upload/serve. NO OTP. |
| `users` | List/approve/assign-role/disable/**delete** users. Enforces single-admin rule. |
| `projects` | CRUD projects, stages, `serializeProject` (applies customer-privacy filtering per role). |
| `drawings` (files) | Upload/list/download files & drawings. `fileBaseUrl()` builds public URLs from `PUBLIC_URL`/X-Forwarded headers. |
| `reports` | Daily reports — these **double as the project chat messages**. Emits `new_message` over Socket.IO. |
| `workplans` | Daily work plans + per-worker task status (started/completed). |
| `payments` | Quotation vs received. `recomputeTotalReceived()` keeps `payments.total_received` in sync after history add/update/delete. Admin-only. |
| `notifications` | In-app notifications. |
| `activity` | Activity logs / audit trail (feeds "recent updates" on dashboards & worker history). |
| `dashboard` | Aggregated dashboard data per role (`dashboard.service.js`) + `workforce.controller.js`. |
| `checklists` | Project checklists. |
| `expenses` | Project expenses. |
| `chat` | Chat room metadata / helpers. |
| `client` | Public client portal (no auth, clean URLs). |
| `assignments` | Assign workers/staff to projects, assignment messages. |

### 2.4 Auth (PIN-based, NO OTP)
OTP/Firebase Phone Auth/MSG91/Twilio were **removed completely. Do not reintroduce.**

- Login = **Mobile (+91 fixed prefix, 10 digits) + 4-digit PIN**.
- Endpoints:
  - `POST /auth/pin-login` — mobile + PIN → JWT.
  - `PUT  /auth/me/pin` — change own PIN (current PIN → new PIN → confirm).
  - `POST /auth/reset-pin-by-id` — forgot PIN via Employee ID (UUID).
  - `PUT  /users/:id/pin` — admin resets a user's PIN.
  - `PUT  /auth/me/avatar` — multipart avatar upload (multer).
  - `GET  /auth/avatar/:userId` — serves avatar image.
- PINs are **bcrypt-hashed** (`pin_hash` column). Phone format is enforced: no `+91+91`,
  no `0091`, country code not editable.

### 2.5 Real-time (Socket.IO) — `src/socket/index.js`
- Handshake auth: JWT token from `socket.handshake.auth.token`.
- On connect, the socket auto-joins rooms `project:<id>`:
  - Workers/anyone → projects they're actively assigned to.
  - **admin** → ALL non-archived projects.
  - **supervisor** → projects they supervise.
- Events: `typing`, `message_read` (updates `daily_reports.read_by` jsonb), `new_message`.
- `emitNewMessage(io, projectId, message)` is called by the reports controller after a
  report/message is created → pushes to everyone in that project room.

### 2.6 Database migrations
`backend/src/db/migrations/` run in order by `migrate.js` (Render build runs
`npm install && npm run migrate`). Highlights:
- `001`–`009` — base schema: extensions/enums, users+auth, projects, files, reports+plans,
  payments, notifications, activity logs, triggers+indexes.
- `010` ERP enhancements · `011` drawings+chat · `012` master rectification.
- `021` assignment messages · `022` report enhancements · `023` project creation v2 ·
  `024` payments v2 · `025` drawings multi · `026` profile OTP (legacy) ·
  `027` otp_codes (legacy) · `028` **pin_column (pin_hash)** · `029` **user_avatar (avatar_url)** ·
  `030` profile security.

> Migrations 026/027 are OTP leftovers — OTP is no longer used in code.

---

## 3. RBAC & Customer Privacy (CRITICAL — do not break)

### 3.1 Permission matrix — `backend/src/middleware/rbac.js`
`ROLE_PERMISSIONS` maps each role to capability keys. Enforced server-side via
`requireRole(...)` and `requirePermission(key)`. Mirrored on the Flutter side in
`core/permissions/permissions.dart`.

- **admin** — everything (users, projects CRUD, stages, assignments, drawings up/delete,
  reports, payments read/write, activity all).
- **supervisor** — read all projects, execution stage, assign workers, work plans, media
  upload, supervisor reports, project activity.
- **designer** — read all projects, design stage, drawings upload/delete, media upload.
- **worker** — `media:upload`, `reports:worker` ONLY.

### 3.2 Worker scoping
Workers can only access projects they are actively assigned to (via `project_assignments`,
`role='worker'`, `active=true`). Backend uses an accessible-project guard for every
worker request — **enforced in APIs, not just hidden in UI.**

### 3.3 Customer privacy for workers
`serializeProject` strips fields based on role. Workers may see:
- ✅ Customer **name**, customer **phone** (to call), project name, site name, full site
  address, Google Maps location, progress, assigned supervisor/team, today's tasks,
  assigned drawings, latest reports, announcements.

Workers must **NOT** see:
- ❌ Customer email, payment details/history, project cost, quotations, invoices,
  receipts, admin remarks/internal notes, financials, customer documents.

Workers cannot edit customer info. Payments are **completely removed** from the worker app.

---

## 4. Frontend (Flutter)

**Path:** `frontend/lib`

### 4.1 Core
- `core/config/env.dart` — `Env.apiBase` defaults to
  `https://icms-backend-s2va.onrender.com/api/v1`.
- `core/router/app_router.dart` — GoRouter. Auth-state redirects + one **ShellRoute per
  role** (bottom-nav scaffold). See routes table below.
- `core/network/dio_client.dart` — Dio instance, JWT interceptor, refresh handling.
- `core/services/socket_service.dart` — `socket_io_client`; connects on login/bootstrap,
  disconnects on logout; listens for `new_message`/`typing`/`message_read`.
- `core/services/offline_sync_service.dart` — Hive boxes (cache + outbound queue),
  connectivity listener, auto-sync with retry on reconnect.
- `core/services/push_notification_service.dart` — FCM push.
- `core/permissions/permissions.dart` — client mirror of the RBAC matrix.

### 4.2 Routing & role shells (`app_router.dart`)
Redirect logic: loading → `/splash`; no user → `/login`; `pending` → `/pending`;
`rejected`/`disabled` → back to `/login`; approved → role home.

| Role | Home | Bottom-nav tabs |
|------|------|-----------------|
| admin | `/admin` | Home · Projects · Workers · Alerts |
| supervisor | `/supervisor` | Home · Projects · Reports · Alerts |
| designer | `/designer` | Home · Projects · Alerts |
| worker | `/worker` | Home · **Chat** (`/worker/reports`) · Alerts |

Full-screen routes (outside shells, wrapped in `BackGuard`): `/viewer` (PDF/drawing),
`/profile`, `/settings`, project detail screens, project form.

### 4.3 Feature folders (`frontend/lib/features/`)
`auth`, `dashboard`, `projects`, `reports`, `users`, `profile`, `payments`, `drawings`,
`assignments`, `tasks`, `notifications`, `activity`. Each typically has
`presentation/` (screens/widgets), `application/` (controllers/providers),
`data/` (api clients/models).

### 4.4 Shared widgets
- `shared/widgets/voice_recorder_sheet.dart` — WhatsApp-style in-app voice recording
  (`flutter_sound` + `permission_handler`): mic permission → record → timer →
  cancel/pause/send → AAC file.
- `shared/widgets/voice_note_player.dart` — plays voice notes (`just_audio`, play/pause/seek).
- `shared/widgets/gradient_button.dart`, `role_scaffold.dart`, `back_guard.dart`.

---

## 5. The Dashboards (what each shows + its data source)

All dashboard data comes from `GET /dashboard` (role-detected server-side) in
`backend/src/modules/dashboard/dashboard.service.js`, plus `GET /dashboard/workforce`.

### 5.1 Admin Dashboard — `features/dashboard/presentation/admin_dashboard.dart`
**Backend:** `dashboard.service.admin()`
Shows:
- **Site stats:** total / active / completed projects.
- **Workforce:** workers planned today, active workers (`worker_status='at_site'`),
  today's assignments count.
- **Reports/approvals:** pending worker reports today, pending user approvals.
- **Payments:** amount received, outstanding amount, pending payments count.
- **Stage distribution** (graph) across project stages.
- **Recent projects** (8 newest active) — customer name **bold/prominent**.
- **Recent updates** — activity log feed.
Admin tabs also reach: Projects, Workers (Workforce Operations Center), Approvals,
Assignments, Tasks, All Reports, Payments overview, Notifications.

### 5.2 Supervisor Dashboard — `supervisor_dashboard.dart`
**Backend:** `dashboard.service.supervisor(userId)`
Shows:
- **My sites** count (projects where `supervisor_id = me`).
- **Today's work** — work plans for my sites today.
- **Report submitted today?** flag (supervisor report).
- **My workers** — workers on my projects with status, site, task.
- **Recent updates** scoped to my projects.

### 5.3 Designer Dashboard — `designer_dashboard.dart`
**Backend:** `dashboard.service.designer(userId)`
Shows:
- **Sites needing design** — projects in stages `discussion`/`3d_design`/`drawing`.
- **My recent uploads** — files I uploaded (3d_design, working/measurement/site/pdf
  drawing, quotation).
Designers always display **"Showroom"** status (never workshop/at_site).

### 5.4 Worker Dashboard — `worker_dashboard.dart`
**Backend:** `dashboard.service.worker(userId)`
A personal field-operations assistant. Shows:
- Greeting + date + **status chip**.
- **Report-due banner** (if no worker report submitted today).
- **Quick actions:** Voice (recorder), Photo (camera), Report (report screen), Drawings.
- **Today's site card** + **tomorrow's work**.
- **Tasks checklist** (work_plan_workers status).
- **Recent drawings** (clickable → PDF/image viewer) limited to assigned projects.
- **My sites** (assigned projects only).
- **Contacts** — ONLY admin + assigned supervisor (phone to call). No company-wide list.
- **Recent work** — own activity-log history.
- Empty state when no assignment exists (this is a data issue, not a bug — admin must
  assign the worker to a project).
- **No payments / no financials / no customer-private data** anywhere.

### 5.5 Workforce Operations Center — `features/users/presentation/workers_screen.dart`
**Backend:** `GET /dashboard/workforce` (`workforce.controller.js`)
Admin/supervisor view: summary cards, clickable staff directory, project workforce
distribution, recent reports. (Daily-report query uses `author_id`, not `submitted_by` —
this was a 500-bug fix; keep it.) → Staff detail via `staff_detail_screen.dart`
(Employee ID copyable, contact, assignments, report history; admin actions: Reset PIN,
Disable, Delete — cannot delete admins).

---

## 6. Chat / Reports system (how messaging works)

The **project's daily reports ARE the chat.** There is no separate messages table for
the project conversation — reports are shared across admin/supervisor/worker on a project
and rendered as a WhatsApp-style thread.

- **UI:** `features/reports/presentation/whatsapp_report_screen.dart`
  (WhatsApp Business **light** theme: `#ECE5DD` bg, own bubbles green `#D9FDD3`,
  others white). Supporting: `report_chat_view.dart`, `report_form_sheet.dart`,
  `reports_home_screen.dart` (room list with avatars), `all_reports_screen.dart`.
- **Real-time:** listens on Socket.IO for `new_message`, shows "is typing…", emits
  `typing` on text change, handles `message_read`.
- **Offline:** offline banner; text messages are queued (Hive) when offline and synced on
  reconnect; messages cached for offline reading.
- **Media:** photos, voice notes (record + playback), attachments. Voice/photos allowed
  for workers (`media:upload`).
- Worker bottom-nav "Reports" is labeled **"Chat"** (chat icon) at `/worker/reports`.

---

## 7. Files & drawings

- Upload/download via the `drawings`(files) module. `fileBaseUrl()` builds public URLs from
  `PUBLIC_URL` env → X-Forwarded headers → fallback (fixes the worker 404-on-attachment bug
  that came from `req.get('host')` returning internal addresses behind Render).
- Frontend opens drawings in-app: PDF via `/viewer` (`pdf_viewer_screen.dart`), images via
  an in-app image viewer.
- Workers can **open / zoom / pan / download-offline / view revisions / mark viewed**.
  Workers **cannot** upload / delete / replace / approve / manage revisions.

---

## 8. Build & deploy

### Backend (Render)
- Build command: `npm install && npm run migrate`
- Branch: **`main`** (was once wrongly set to a feat branch → caused "Route Not Found").
- Required env: `PUBLIC_URL=https://icms-backend-s2va.onrender.com`, JWT secrets, DB URL.

### Frontend
- **Android APK:** `flutter build apk --release` from `frontend/`.
  Output: `frontend\build\app\outputs\flutter-apk\app-release.apk`.
  ⚠️ The command may exit code 1 due to a terminal pipe/Select-String quirk **but the APK
  still builds** — verify with:
  `Test-Path "build\app\outputs\flutter-apk\app-release.apk"` or look for
  `Built ... app-release.apk` in the output.
- **iOS:** cannot build on Windows.
- **Windows native:** FAILS (firebase_core + flutter_sound have no working Windows impl).
  Use **`flutter build web`** as the Windows/desktop alternative.
- **App icon:** `frontend/assets/icon/app_icon.png` → regenerate with
  `dart run flutter_launcher_icons`.

### System / shell notes
- OS: Windows, **cmd** shell. Use `;` to chain (not `&&`); avoid `&` in PowerShell.

---

## 9. Hard rules (things that must NOT be broken)

1. **No OTP** anywhere. Auth is Mobile(+91) + 4-digit PIN only.
2. **Phone format:** fixed `+91` prefix (non-editable), 10 digits. Block `+91+91`, `0091`.
3. **Single admin:** `users.service.approve()` throws if a second admin is assigned.
4. **Don't break admin/supervisor/designer dashboards** when changing worker features —
   they share the same backend APIs.
5. **Customer privacy for workers** enforced in BACKEND (`serializeProject`), not just UI.
6. **Designers** always show "Showroom".
7. **Workers** never see payments/financials/quotations/customer-private data.
8. RBAC enforced server-side via `rbac.js` (`requireRole`/`requirePermission`).
9. Render must deploy branch `main` with the migrate build command + `PUBLIC_URL`.

---

## 10. Quick "where do I look?" index

| I want to… | Go to |
|-----------|-------|
| Change how dashboards aggregate data | `backend/src/modules/dashboard/dashboard.service.js` |
| Change role permissions | `backend/src/middleware/rbac.js` (+ frontend `core/permissions/permissions.dart`) |
| Change what fields workers can see on a project | `serializeProject` in `backend/src/modules/projects/` |
| Touch login / PIN / avatar | `backend/src/modules/auth/*` + `frontend/lib/features/auth/*` + `profile/*` |
| Touch real-time chat | `backend/src/socket/index.js`, reports controller, `whatsapp_report_screen.dart` |
| Touch routing / role shells | `frontend/lib/core/router/app_router.dart` |
| Touch file/drawing URLs | `backend/src/modules/drawings/files.controller.js` (`fileBaseUrl`) |
| Touch payments | `backend/src/modules/payments/payments.service.js` (`recomputeTotalReceived`) |
| Add a DB column/table | new file in `backend/src/db/migrations/` (next number) |
