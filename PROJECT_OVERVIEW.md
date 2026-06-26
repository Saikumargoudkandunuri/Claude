# ICMS — Full Application Documentation

> **For:** Future AI sessions (Claude / Kiro) and developers picking up this codebase.
> **Read this first** before making changes. It explains the whole app: what it does,
> how the backend and frontend are wired, what every dashboard shows, and the rules
> (RBAC, customer privacy, auth) that must NOT be broken.

---

## 1. What This App Is

**ICMS — Interior Company Management System**, branded for **Metal & More Interiors**.
A construction / interior-fit-out site management application used to run projects
end-to-end: design, execution, daily reporting, drawings, payments, workforce payroll,
attendance tracking, snag lists, and team coordination.

| Layer | Stack |
|-------|-------|
| **Frontend** | Flutter 3.19+ (Android primary, Web as desktop fallback). Riverpod · GoRouter · Dio · Hive (offline). |
| **Backend** | Node.js 18+ · Express · PostgreSQL. JWT auth. Socket.IO real-time. |
| **Hosting** | Render — `https://icms-backend-s2va.onrender.com`. Branch: `main`. |
| **Repo** | `https://github.com/Saikumargoudkandunuri/Claude` |

### Repo Layout

```
c:\Users\Admin\Claude\
├── backend/            Node/Express API + PostgreSQL migrations
├── frontend/           Flutter app (Android + Web)
├── .claude/            Claude agent/spec config (not app code)
├── .kiro/              Kiro steering + specs
└── PROJECT_OVERVIEW.md (this file)
```

### The 4 Roles

| Role | Purpose |
|------|---------|
| **admin** | Full control: projects, users, payments, assignments, workforce, payroll, reports. Only ONE admin allowed. |
| **supervisor** | Runs assigned sites: workers, work plans, supervisor reports, weekly status, site progress. |
| **designer** | Design stage: uploads 3D designs / working drawings / quotations. Always shown as "Showroom". |
| **worker** | On-site field worker: sees only ASSIGNED projects, submits reports, chats, checks in/out. Heavily privacy-restricted. |

---

## 2. Backend

**Path:** `backend/src`

### 2.1 Entry & Wiring

- `app.js` — builds the Express app, mounts all routers under `/api/v1`.
  - `/auth` is public (register, login, PIN-login, refresh). Everything else requires
    `authenticate` + `requireApproved`.
  - Many routers mount at `/` because they declare absolute paths internally.
- `server.js` — creates HTTP server, attaches **Socket.IO** (`initSocket`), stores via
  `app.set('io', io)` so controllers can emit real-time events.
- `config/index.js` — env config: `apiPrefix`, `corsOrigins`, `publicUrl` (for correct
  public file URLs behind Render's proxy), JWT secrets.

### 2.2 Module Pattern

Every feature in `src/modules/<name>/` follows:
- `*.routes.js` — Express routes + middleware (auth, rbac, validation).
- `*.controller.js` — request/response handling.
- `*.service.js` — business logic + SQL queries.
- `*.schema.js` — (some modules) Zod validation schemas.

### 2.3 All Modules (19)

| Module | Responsibility |
|--------|----------------|
| `auth` | Register, **PIN login**, refresh tokens, change/reset PIN, avatar upload/serve. NO OTP. |
| `users` | List/approve/assign-role/disable/delete users. Enforces single-admin rule. |
| `projects` | CRUD projects, stages, `serializeProject` (privacy filtering per role). |
| `drawings` (files) | Upload/list/download files & drawings. `fileBaseUrl()` builds public URLs. |
| `reports` | Daily reports — these **double as project chat messages**. Emits `new_message` via Socket.IO. |
| `workplans` | Daily work plans + per-worker task status (started/completed). |
| `payments` | Project quotation vs received payments. `recomputeTotalReceived()` keeps sync. Admin-only. |
| `notifications` | In-app + FCM push notifications. |
| `activity` | Activity logs / audit trail (recent updates on dashboards & worker history). |
| `dashboard` | Aggregated dashboard data per role + `workforce.controller.js`. |
| `checklists` | Project checklists. |
| `expenses` | Project expenses. |
| `chat` | Chat room metadata / helpers. |
| `client` | Public client portal (no auth, clean URLs). |
| `assignments` | Assign workers/staff to projects, assignment messages. |
| `attendance` | GPS check-in/check-out, geofence monitoring, location reporting, alerts. |
| `weekly_status` | Weekly project status tracking (on_track / normal / slow). Upsert per week. Push alerts on "slow". |
| `snag` | Snag/punch list: create → resolve → close items per project. Priority + assignment. |
| `payroll` | Worker salary profiles, daily attendance marking, monthly salary calculation, payments (salary/advance/bonus). |

### 2.4 Auth (PIN-based, NO OTP)

OTP/Firebase Phone Auth/MSG91/Twilio were **removed completely. Do not reintroduce.**

- Login = **Mobile (+91 fixed prefix, 10 digits) + 4-digit PIN**.
- Endpoints:
  - `POST /auth/pin-login` — mobile + PIN → JWT.
  - `PUT  /auth/me/pin` — change own PIN (current → new → confirm).
  - `POST /auth/reset-pin-by-id` — forgot PIN via Employee ID (UUID).
  - `PUT  /users/:id/pin` — admin resets a user's PIN.
  - `PUT  /auth/me/avatar` — multipart avatar upload (multer).
  - `GET  /auth/avatar/:userId` — serves avatar image.
- PINs are **bcrypt-hashed** (`pin_hash` column). Phone format enforced: no `+91+91`,
  no `0091`, country code not editable.

### 2.5 Real-time (Socket.IO) — `src/socket/index.js`

- Handshake auth: JWT token from `socket.handshake.auth.token`.
- On connect, socket auto-joins rooms `project:<id>`:
  - Workers → projects they're actively assigned to.
  - **admin** → ALL non-archived projects.
  - **supervisor** → projects they supervise.
- Events: `typing`, `message_read` (updates `daily_reports.read_by` jsonb), `new_message`.
- `emitNewMessage(io, projectId, message)` pushes to everyone in the project room.

### 2.6 Attendance & Geofencing

- `attendance` module: GPS check-in/out per project, haversine distance validation
  against project GPS coordinates, geofence radius enforcement.
- Periodic location reporting while checked in — triggers `geofence_alerts` if worker
  moves too far from site.
- `geofence_alerts` table: pending → approved/declined/resolved by admin.
- Monthly summary aggregation for attendance records.

### 2.7 Payroll System

- `payroll` module handles:
  - **Worker attendance** (separate from GPS attendance): at_site / workshop / leave / absent per day.
  - **Salary profiles**: monthly_salary + working_days_per_month on users table.
  - **Monthly salary calculation**: days present × daily rate, minus advances, plus bonuses = net payable.
  - **Payment records**: salary / advance / bonus with proof images.
- Admin marks attendance, sets salaries, processes payments.
- Workers can view their own salary/payment history.

### 2.8 Database Migrations

`backend/src/db/migrations/` run in order by `migrate.js` (Render build command:
`npm install && npm run migrate`).

| Range | Content |
|-------|---------|
| `001`–`009` | Base schema: extensions/enums, users+auth, projects, files, reports+plans, payments, notifications, activity logs, triggers+indexes. |
| `010`–`012` | ERP enhancements, drawings+chat, master rectification. |
| `021`–`025` | Assignment messages, report enhancements, project creation v2, payments v2, drawings multi. |
| `026`–`031` | Profile OTP (legacy/unused), otp_codes (legacy/unused), **pin_column**, **user_avatar**, profile security, project GPS. |
| `032`–`035` | Attendance records, photo timeline, drawing approval, project timeline. |
| `036`–`039` | Invoices, worker performance, WhatsApp log, localisation. |
| `040` | **Weekly project status** (`project_weekly_status` table). |
| `041` | Drawing approval flow, password_hash nullable. |
| `042` | **Geofence alerts**, **snag_items** table. |
| `043` | **Worker attendance + salary** (`worker_attendance`, salary columns on users). |
| `044` | **Worker payments** (`worker_payments` table). |

> Migrations 026/027 are OTP leftovers — OTP is no longer used in code.

---

## 3. RBAC & Customer Privacy (CRITICAL — do not break)

### 3.1 Permission Matrix — `backend/src/middleware/rbac.js`

`ROLE_PERMISSIONS` maps each role to capability keys. Enforced server-side via
`requireRole(...)` and `requirePermission(key)`. Mirrored on Flutter side in
`core/permissions/permissions.dart`.

| Role | Permissions |
|------|-------------|
| **admin** | users (read/approve/assign-role), projects (full CRUD + read-all), stages (design/execution/override), assignments (workers/staff), workplans (write), drawings (upload/delete), media (upload), reports (worker/supervisor), payments (read/write), activity (read-all/read-project) |
| **supervisor** | projects (read-all), stages (execution), assignments (workers), workplans (write), media (upload), reports (supervisor), activity (read-project) |
| **designer** | projects (read-all), stages (design), drawings (upload/delete), media (upload), activity (read-project) |
| **worker** | media (upload), reports (worker) |

### 3.2 Worker Scoping

Workers can only access projects they are actively assigned to (via `project_assignments`,
`role='worker'`, `active=true`). Backend enforces accessible-project guards on every
worker request — **enforced in APIs, not just hidden in UI.**

### 3.3 Customer Privacy for Workers

`serializeProject` strips fields based on role. Workers may see:
- ✅ Customer name, customer phone (to call), project name, site name, full site
  address, Google Maps location, progress, assigned supervisor/team, today's tasks,
  assigned drawings, latest reports, announcements.

Workers must **NOT** see:
- ❌ Customer email, payment details/history, project cost, quotations, invoices,
  receipts, admin remarks/internal notes, financials, customer documents.

Workers cannot edit customer info. Payments are **completely hidden** from the worker app.

---

## 4. Frontend (Flutter)

**Path:** `frontend/lib`

### 4.1 Core Layer

| File/Dir | Purpose |
|----------|---------|
| `core/config/env.dart` | `Env.apiBase` → `https://icms-backend-s2va.onrender.com/api/v1` |
| `core/router/app_router.dart` | GoRouter with auth-state redirects + ShellRoute per role |
| `core/network/dio_client.dart` | Dio instance, JWT interceptor, refresh handling |
| `core/services/socket_service.dart` | Socket.IO client: connects on login, `new_message`/`typing`/`message_read` |
| `core/services/offline_sync_service.dart` | Hive boxes (cache + outbound queue), connectivity listener, auto-sync |
| `core/services/push_notification_service.dart` | FCM push notifications |
| `core/permissions/permissions.dart` | Client-side mirror of RBAC matrix |

### 4.2 Routing & Role Shells

Redirect logic: loading → `/splash`; no user → `/login`; `pending` → `/pending`;
`rejected`/`disabled` → `/login`; approved → role home.

| Role | Home | Bottom-Nav Tabs |
|------|------|-----------------|
| admin | `/admin` | Home · Projects · Workers · Alerts |
| supervisor | `/supervisor` | Home · Projects · Reports · Alerts |
| designer | `/designer` | Home · Projects · Alerts |
| worker | `/worker` | Home · **Chat** (`/worker/reports`) · Alerts |

Full-screen routes (outside shells, wrapped in `BackGuard`): `/viewer` (PDF/drawing),
`/profile`, `/settings`, project detail screens, project form.

**Admin additional routes:** `/admin/approvals`, `/admin/assignments`, `/admin/tasks`,
`/admin/all-reports`, `/admin/payments`, `/admin/workers`.

**Supervisor additional routes:** `/supervisor/all-reports`, `/supervisor/assignments`,
`/supervisor/workers`, `/supervisor/tasks`.

### 4.3 Feature Folders

| Feature | Contents |
|---------|----------|
| `auth` | Login, register, forgot-password, splash, pending-approval screens |
| `dashboard` | Admin/Supervisor/Designer/Worker dashboards + attendance card widget |
| `projects` | Project list, detail (tabbed: details/drawings/payments/timeline), form, edit sheet, site photos, snag list, weekly status (set + history) |
| `reports` | Reports home (room list), WhatsApp-style chat, report form, all-reports, voice notes |
| `users` | Workers screen (workforce ops center), staff detail, approvals |
| `profile` | Profile screen, settings |
| `payments` | Payments overview (project payments) |
| `payroll` | Admin payroll screen, worker salary screen (my salary), attendance card, payment detail |
| `drawings` | PDF viewer |
| `assignments` | Assignment management |
| `tasks` | Task panel |
| `notifications` | Notifications screen |
| `activity` | Activity/audit trail |

### 4.4 Key Shared Widgets

- `voice_recorder_sheet.dart` — WhatsApp-style voice recording (record + timer + cancel/pause/send → AAC).
- `voice_note_player.dart` — voice note playback (just_audio, play/pause/seek).
- `weekly_status_chip.dart` — colored chip for on_track/normal/slow display.
- `gradient_button.dart`, `role_scaffold.dart`, `back_guard.dart`.

### 4.5 Key Dependencies

| Purpose | Package |
|---------|---------|
| State management | flutter_riverpod |
| Routing | go_router |
| HTTP | dio |
| Offline | hive, hive_flutter, connectivity_plus |
| Token storage | flutter_secure_storage |
| PDF | syncfusion_flutter_pdfviewer |
| Audio | just_audio, record |
| GPS / Location | geolocator |
| Push | firebase_core, firebase_messaging, flutter_local_notifications |
| Media | image_picker, file_picker, photo_view, video_player, chewie |
| Real-time | socket_io_client |

---

## 5. Dashboards

All dashboard data comes from `GET /dashboard` (role-detected server-side) in
`backend/src/modules/dashboard/dashboard.service.js`, plus `GET /dashboard/workforce`.

### 5.1 Admin Dashboard

**File:** `features/dashboard/presentation/admin_dashboard.dart`
**Backend:** `dashboard.service.admin()`

Shows:
- **Site stats:** total / active / completed projects.
- **Workforce:** workers planned today, active workers (`worker_status='at_site'`), assignments count.
- **Reports/approvals:** pending worker reports today, pending user approvals.
- **Payments:** amount received, outstanding, pending count.
- **Stage distribution** (graph) across project stages.
- **Recent projects** (8 newest active) — customer name prominent.
- **Recent updates** — activity log feed.

Additional admin screens: Projects, Workers (Workforce Ops Center), Approvals,
Assignments, Tasks, All Reports, Payments overview, Payroll, Notifications.

### 5.2 Supervisor Dashboard

**File:** `supervisor_dashboard.dart`
**Backend:** `dashboard.service.supervisor(userId)`

Shows:
- **My sites** count.
- **Today's work** — work plans for my sites today.
- **Report submitted today?** flag.
- **My workers** — workers on my projects with status, site, task.
- **Weekly status** — ability to set/view weekly status for supervised projects.
- **Recent updates** scoped to my projects.

### 5.3 Designer Dashboard

**File:** `designer_dashboard.dart`
**Backend:** `dashboard.service.designer(userId)`

Shows:
- **Sites needing design** — projects in discussion/3d_design/drawing stages.
- **My recent uploads** — files uploaded (3D designs, drawings, quotations).
- Designers always show **"Showroom"** status.

### 5.4 Worker Dashboard

**File:** `worker_dashboard.dart`
**Backend:** `dashboard.service.worker(userId)`

A personal field-operations assistant. Shows:
- Greeting + date + **status chip**.
- **Attendance card** — GPS check-in/check-out with geofence monitoring.
- **Report-due banner** (if no worker report submitted today).
- **Quick actions:** Voice, Photo, Report, Drawings.
- **Today's site card** + **tomorrow's work**.
- **Tasks checklist** (work_plan_workers status).
- **Recent drawings** (limited to assigned projects).
- **My sites** (assigned projects only).
- **Contacts** — ONLY admin + assigned supervisor (phone to call). No company-wide list.
- **Recent work** — own activity-log history.
- **No payments / no financials / no customer-private data** anywhere.

### 5.5 Workforce Operations Center

**File:** `features/users/presentation/workers_screen.dart`
**Backend:** `GET /dashboard/workforce`

Admin/supervisor view: summary cards, staff directory, project workforce distribution,
recent reports. Staff detail → Employee ID (copyable), contact, assignments, report
history; admin actions: Reset PIN, Disable, Delete (cannot delete admins).

---

## 6. Chat / Reports System

The **project's daily reports ARE the chat.** No separate messages table — reports are
shared across admin/supervisor/worker on a project and rendered as a WhatsApp-style thread.

- **UI:** `whatsapp_report_screen.dart` (WhatsApp Business light theme: `#ECE5DD` bg,
  own bubbles `#D9FDD3`, others white). Supporting: `report_chat_view.dart`,
  `report_form_sheet.dart`, `reports_home_screen.dart` (room list with avatars),
  `all_reports_screen.dart`.
- **Real-time:** Socket.IO `new_message`, "is typing…", `message_read`.
- **Offline:** banner shown; text messages queued in Hive and synced on reconnect;
  messages cached for offline reading.
- **Media:** photos, voice notes (record + playback), attachments. Voice/photos allowed
  for workers (`media:upload`).
- Worker bottom-nav "Reports" is labeled **"Chat"** (chat icon) at `/worker/reports`.

---

## 7. Files & Drawings

- Upload/download via the `drawings` (files) module. `fileBaseUrl()` builds public URLs
  from `PUBLIC_URL` env → X-Forwarded headers → fallback.
- Frontend opens drawings in-app: PDF via `/viewer` (Syncfusion PDF viewer), images via
  photo_view.
- Workers can **open / zoom / pan / download-offline / view revisions / mark viewed**.
  Workers **cannot** upload / delete / replace / approve / manage revisions.

---

## 8. Weekly Project Status

A traffic-light system for project health, set weekly by supervisors/admin.

- **Statuses:** `on_track` 🟢 · `normal` 🟡 · `slow` 🔴
- **Backend:** `weekly_status` module — upsert per project per ISO week (Monday-based).
- Supervisors can only set status for their own projects. Admin can set for any.
- When marked "slow", push notification sent to all admins.
- Activity log entry created for each status change.
- **Frontend:** `set_weekly_status_sheet.dart` (set), `weekly_status_history_screen.dart`
  (history), `weekly_status_chip.dart` (display).

---

## 9. Snag / Punch List

Per-project snag tracking for site handover quality control.

- **Statuses:** `open` → `resolved` → `closed`.
- **Priority:** low / medium / high (sorted high-first).
- Assignable to specific users. Resolution includes note + photo.
- **Backend:** `snag` module — CRUD + summary counts.
- **Frontend:** `snag_list_screen.dart` inside project detail.

---

## 10. Attendance & Geofencing

- **GPS attendance** (`attendance` module): check-in/out with lat/lng validation against
  project coordinates using haversine distance.
- **Geofence alerts:** periodic location reporting detects when worker moves outside
  project radius → creates alert → admin approves/declines.
- **Worker dashboard:** `AttendanceCard` widget — shows check-in/out buttons, live
  distance from site, geofence warning, active alert status.
- **Monthly summaries** for admin review.

---

## 11. Payroll & Worker Payments

Separate from project payments — this tracks individual worker compensation.

- **Salary setup:** admin sets `monthly_salary` + `working_days_per_month` per worker.
- **Attendance tracking:** `worker_attendance` table — daily at_site/workshop/leave/absent records.
- **Salary calculation:** days present × daily rate; deductions for absence; advances
  subtracted; bonuses added → net payable.
- **Payment types:** salary, advance, bonus — with proof image upload.
- **Frontend:**
  - `admin_payroll_screen.dart` — overview of all workers, mark attendance, process payments.
  - `my_salary_screen.dart` — worker's own salary/payment history.
  - `worker_payment_detail_screen.dart` — payment breakdown.

---

## 12. Build & Deploy

### Backend (Render)

- Build command: `npm install && npm run migrate`
- Start command: `npm start`
- Branch: **`main`**
- Required env: `PUBLIC_URL=https://icms-backend-s2va.onrender.com`, JWT secrets, `DATABASE_URL`.

### Frontend

- **Android APK:** `flutter build apk --release` from `frontend/`.
  Output: `frontend\build\app\outputs\flutter-apk\app-release.apk`.
  ⚠️ Command may exit code 1 due to terminal pipe quirk — APK still builds. Verify with
  `Test-Path "build\app\outputs\flutter-apk\app-release.apk"`.
- **Web (desktop fallback):** `flutter build web` from `frontend/`.
- **iOS:** cannot build on Windows.
- **Windows native:** FAILS (firebase_core + audio packages lack Windows support).
- **App icon:** `frontend/assets/icon/app_icon.png` → regenerate with
  `dart run flutter_launcher_icons`.

### System / Shell Notes

- OS: Windows, **cmd** shell. Use `&` to chain commands.

---

## 13. Hard Rules (things that must NOT be broken)

1. **No OTP** anywhere. Auth is Mobile (+91) + 4-digit PIN only.
2. **Phone format:** fixed `+91` prefix (non-editable), 10 digits. Block `+91+91`, `0091`.
3. **Single admin:** `users.service.approve()` throws if a second admin is assigned.
4. **Don't break other dashboards** when changing one role's features — they share backend APIs.
5. **Customer privacy for workers** enforced in BACKEND (`serializeProject`), not just UI.
6. **Designers** always show "Showroom".
7. **Workers** never see payments/financials/quotations/customer-private data.
8. RBAC enforced server-side via `rbac.js` (`requireRole`/`requirePermission`).
9. Render must deploy branch `main` with the migrate build command + `PUBLIC_URL`.
10. **Geofence alerts** only visible to admin — workers see their own alert status only.
11. **Weekly status** — supervisors can only set for their own projects; slow triggers admin push notification.

---

## 14. Quick "Where Do I Look?" Index

| I want to… | Go to |
|-----------|-------|
| Change dashboard data | `backend/src/modules/dashboard/dashboard.service.js` |
| Change role permissions | `backend/src/middleware/rbac.js` + `frontend/lib/core/permissions/permissions.dart` |
| Change what fields workers see | `serializeProject` in `backend/src/modules/projects/` |
| Touch login / PIN / avatar | `backend/src/modules/auth/*` + `frontend/lib/features/auth/*` + `profile/*` |
| Touch real-time chat | `backend/src/socket/index.js`, reports controller, `whatsapp_report_screen.dart` |
| Touch routing / role shells | `frontend/lib/core/router/app_router.dart` |
| Touch file/drawing URLs | `backend/src/modules/drawings/files.controller.js` (`fileBaseUrl`) |
| Touch project payments | `backend/src/modules/payments/payments.service.js` (`recomputeTotalReceived`) |
| Touch worker payroll | `backend/src/modules/payroll/payroll.service.js` + `frontend/lib/features/payroll/` |
| Touch attendance / geofencing | `backend/src/modules/attendance/attendance.service.js` + `AttendanceCard` widget |
| Touch weekly project status | `backend/src/modules/weekly_status/` + `frontend/.../set_weekly_status_sheet.dart` |
| Touch snag list | `backend/src/modules/snag/` + `frontend/.../snag_list_screen.dart` |
| Add a DB column/table | new file in `backend/src/db/migrations/` (next number: `045`) |
| Touch offline sync | `frontend/lib/core/services/offline_sync_service.dart` |
| Touch push notifications | `frontend/lib/core/services/push_notification_service.dart` + backend `notifyAdmins()` |
