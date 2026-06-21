# 01 — Product Architecture

**Product:** Interior Company Management System (ICMS)
**Purpose:** A single source of truth for an Interior Design & Execution company, replacing WhatsApp coordination, paper drawings, manual reporting, Excel tracking and lost project files.

---

## 1.1 System Overview

```
                         ┌───────────────────────────────────────────┐
                         │              FLUTTER CLIENT                 │
                         │  (Android / iOS / Web — Material 3, M1 UI)  │
                         │                                             │
                         │  Riverpod (state)  ·  GoRouter (nav)        │
                         │  Dio (http)  ·  Hive (offline cache)        │
                         └───────────────────┬─────────────────────────┘
                                             │  HTTPS / REST + JWT
                                             ▼
                         ┌───────────────────────────────────────────┐
                         │            NODE.JS API (Express)            │
                         │                                             │
                         │  Auth · RBAC · Modules · File Service       │
                         │  Validation · Activity Logger · Notifier    │
                         └───┬───────────────┬───────────────┬─────────┘
                             │               │               │
                             ▼               ▼               ▼
                  ┌──────────────┐  ┌────────────────┐  ┌───────────────┐
                  │ PostgreSQL   │  │  File Storage   │  │  Push (FCM)   │
                  │ (relational) │  │  (disk/S3-like) │  │  + In-App     │
                  └──────────────┘  └────────────────┘  └───────────────┘
```

The system is a **client–server architecture**:

- **Flutter app** — single codebase for mobile (primary) and web (admin/office), mobile-first responsive layout.
- **Node.js REST API** — stateless, JWT-secured, modular monolith (easy to deploy on Hostinger VPS).
- **PostgreSQL** — relational data: users, projects, stages, reports, payments, notifications, activity logs.
- **File storage** — local disk on the server (Hostinger compatible) behind a file service abstraction so it can be swapped for S3/Spaces later. Stores drawings, 3D designs, quotations, photos, videos, voice notes.
- **Notifications** — Firebase Cloud Messaging for push + an in-app notifications table.

## 1.2 Architectural Principles

1. **Modular monolith** — one deployable backend, organized into feature modules (`auth`, `users`, `projects`, `drawings`, `reports`, `payments`, `notifications`, `activity`, `files`). Simpler to operate on Hostinger than microservices, but cleanly separated for future extraction.
2. **Single source of truth** — all project artifacts live in the system; nothing relies on WhatsApp/phone.
3. **Latest-only drawings** — no version history. Replacing a drawing deletes the old file (business requirement to avoid workers using wrong drawings).
4. **Role-based everything** — every endpoint and every screen is gated by one of four roles.
5. **Offline-first for field staff** — workers/supervisors cache assigned sites and drawings locally (Hive + downloaded files) for poor-connectivity sites.
6. **Audit by default** — every state-changing action writes an activity log row.
7. **Privacy by design** — workers never see other workers' or designers' contact details.

## 1.3 Core Domain Model (high level)

```
User (Admin/Supervisor/Designer/Worker)
  └─ approves/creates ──► Project
                            ├─ Stages (13 fixed stages, ordered)
                            ├─ Assignments (supervisor, designer, workers)
                            ├─ Files (drawings, 3D, quotation, photos, videos, voice)
                            ├─ Daily Reports (worker + supervisor)
                            ├─ Payments + Payment History
                            ├─ Work Plans (tomorrow planning)
                            ├─ Notifications
                            └─ Activity Logs
```

## 1.4 Roles & Responsibility Summary

| Role | Primary job | Controls stages |
|------|-------------|-----------------|
| **Admin** | Full control, projects, payments, approvals, oversight | Can override any stage |
| **Designer** | Designs & drawings | Discussion, 3D Design, Drawing |
| **Supervisor** | Field execution & coordination | Material Purchase → Completed |
| **Worker** | Do assigned work, daily reports | None (marks own task started/completed) |

## 1.5 Key Business Flows

1. **Onboarding** — User registers → status `pending` → Admin notified → Admin approves + assigns role.
2. **Project lifecycle** — Admin creates project → Designer uploads 3D + drawings → Supervisor assigns workers & manages execution stages → Workers do work + submit EOD reports → Supervisor submits EOD reports → Admin tracks payments & progress → project `Completed`.
3. **Drawing safety** — Designer/Admin upload drawings; supervisors/workers download for offline use so nobody reaches a site without the latest drawing.
4. **Daily reporting** — Mandatory worker & supervisor end-of-day reports with media.
5. **Tomorrow planning** — Admin/Supervisor assign next-day work → notifications to workers & supervisor.

## 1.6 Non-Functional Requirements

| Area | Target |
|------|--------|
| Availability | 99.5% (single VPS, daily DB backup) |
| API latency | p95 < 400 ms for reads |
| File upload | up to 200 MB (videos) with chunk-friendly multipart |
| Security | JWT access (15 min) + refresh (30 days), bcrypt password hashing, RBAC, rate limiting, helmet, input validation |
| Offline | Workers can open last-synced drawings without network |
| Auditability | 100% of mutations logged |
| Localization-ready | English first; strings externalized for future languages |

## 1.7 Deployment Topology (Hostinger)

- **Hostinger VPS (Ubuntu)** runs: Node.js API (PM2), PostgreSQL, Nginx reverse proxy + TLS (Let's Encrypt), local file storage under `/var/icms/storage`.
- **Flutter web build** served as static files by Nginx; mobile apps distributed via stores / APK.
- See `docs/10-development-roadmap.md` and `backend/README.md` for exact steps.
