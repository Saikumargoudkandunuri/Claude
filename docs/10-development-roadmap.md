# 10 — Development Roadmap

A phased plan to take ICMS from this foundation to a deployed product an interior company can use daily.

## Phase 0 — Foundation (this repository)
- [x] Product architecture, DB design, API design, permissions matrix, screen & navigation flow, wireframes.
- [x] Backend skeleton: Express app, config, JWT auth, RBAC, PostgreSQL pool, migrations, seed.
- [x] Core modules: auth, users (approvals), projects, stages, files/drawings, reports, payments, workplans, notifications, activity, dashboard.
- [x] File storage service (local disk, Hostinger-ready) with latest-only drawing rule.
- [x] Flutter scaffold: theme (#00D1DC), Riverpod, GoRouter, Dio client, auth flow, role dashboards, projects, drawings, reports.

## Phase 1 — MVP hardening (Weeks 1–3)
- Wire every Flutter screen to live endpoints; finish project detail tabs.
- File upload from app (image/video/voice/pdf pickers) + progress.
- PDF viewer with zoom/rotate/fullscreen + offline caching of drawings.
- Worker mark started/completed + EOD report end-to-end.
- Seed first Admin via `npm run seed`; admin approves users.
- Manual QA against the permissions matrix.

## Phase 2 — Notifications & Offline (Weeks 4–5)
- Firebase Cloud Messaging integration (device token registration already in API).
- In-app notification center + unread badges + deep links.
- Offline cache (Hive) for assigned sites + downloaded drawings; sync on reconnect.
- Background upload queue for reports/media on poor connectivity.

## Phase 3 — Reporting & Payments polish (Weeks 6–7)
- Admin payments dashboard: outstanding by project, payment history, receipts.
- Daily report digests (per-site, per-day) + export to PDF.
- Tomorrow-work planning calendar view + reminders.

## Phase 4 — Quality, security, deployment (Weeks 8–9)
- Automated tests: backend (Jest/Supertest) for auth, RBAC, drawings latest-only, payments totals; Flutter widget/golden + permission tests.
- Security pass: rate limits, file scanning, JWT rotation, audit log review.
- CI: lint + test on PR.
- Deploy to Hostinger VPS (see below); TLS, PM2, nightly DB backup, storage backup.

## Phase 5 — Rollout & adoption (Weeks 10–12)
- Pilot with one live project; train office staff, designers, supervisors, workers.
- Migrate existing project files into the system.
- Feedback loop; refine worker UX.
- Company-wide rollout; decommission WhatsApp/Excel coordination.

## Future enhancements (post-launch)
- Localization (regional languages for workers).
- Material/inventory & vendor module.
- Attendance / geofenced check-in at site.
- Customer portal (read-only progress + approvals).
- Move file storage to S3/Spaces; multi-VPS scaling.

---

## Deployment Checklist (Hostinger VPS)
1. Provision Ubuntu VPS; install Node 20+, PostgreSQL 15+, Nginx, Certbot.
2. Create DB + user; set `.env` (see `backend/.env.example`).
3. `npm ci && npm run migrate && npm run seed` in `backend/`.
4. Run API under **PM2** (`pm2 start src/server.js --name icms-api`).
5. Nginx reverse proxy `/api` → Node; serve Flutter web build as static; enable TLS via Certbot.
6. Create `STORAGE_DIR` (e.g. `/var/icms/storage`) owned by the app user.
7. Cron: nightly `pg_dump` + storage rsync to backup location.
8. Point mobile apps' `API_BASE_URL` to the domain; ship APK / store builds.

## Definition of Done (per feature)
- Endpoint validated (zod) + RBAC enforced + activity logged + notification fired where required.
- Flutter screen handles loading/empty/error, respects permissions, works offline where specified.
- Covered by at least one automated test.
