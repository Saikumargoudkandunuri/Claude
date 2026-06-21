# Interior Company Management System (ICMS)

A production-ready management system built specifically for an **Interior Design & Execution company**. It replaces WhatsApp coordination, paper drawings, manual reporting, Excel tracking and lost project files with a **single source of truth**.

> Used daily by office staff, designers, supervisors and workers.

---

## Highlights

- **4 roles** — Admin, Supervisor, Designer, Worker — with strict, server-enforced permissions.
- **Project lifecycle** across 13 stages (Discussion → 3D Design → Drawing → … → Installation → Checking → Completed).
- **Drawings module** that solves the "worker reached site without the latest drawing" problem — latest-only drawings, offline download, PDF viewer with zoom/rotate/fullscreen.
- **Mandatory daily reports** (worker + supervisor) with photos, videos and voice notes.
- **Tomorrow work planning** with notifications to workers & supervisors.
- **Payments** (admin only) with history and outstanding tracking.
- **Activity history** auditing every action, and **notifications** for every important event.
- **Employee privacy** — workers never see other workers'/designers' contact details.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter, Material 3, Riverpod, GoRouter, Dio, Hive (offline), Syncfusion PDF viewer |
| Backend | Node.js, Express, PostgreSQL (raw `pg`), JWT auth, Zod validation, Multer uploads |
| Storage | Local disk (Hostinger compatible), swappable to S3/Spaces |
| Notifications | Firebase Cloud Messaging (push) + in-app notifications |

UI palette: primary `#00D1DC`, white background `#FFFFFF`, secondary `#F8FAFC`. Light, clean, mobile-first.

## Repository Layout

```
.
├── docs/         # Full design: architecture, DB, API, permissions, flows, roadmap
├── backend/      # Node.js + PostgreSQL API (see backend/README.md)
└── frontend/     # Flutter client (see frontend/README.md)
```

## Documentation (the 10 design outputs)

| # | Document |
|---|----------|
| 01 | [Product Architecture](docs/01-product-architecture.md) |
| 02 | [Database Design](docs/02-database-design.md) |
| 03 | [Flutter Folder Structure](docs/03-flutter-folder-structure.md) |
| 04 | [Backend Architecture](docs/04-backend-architecture.md) |
| 05 | [API Design](docs/05-api-design.md) |
| 06 | [User Permissions Matrix](docs/06-permissions-matrix.md) |
| 07 | [Screen Flow](docs/07-screen-flow.md) |
| 08 | [Navigation Flow](docs/08-navigation-flow.md) |
| 09 | [UI / UX Wireframe Structure](docs/09-ui-wireframe-structure.md) |
| 10 | [Development Roadmap](docs/10-development-roadmap.md) |

## Quick Start

### 1. Backend
```bash
cd backend
cp .env.example .env          # edit DB + secrets
npm install
npm run migrate               # create schema
npm run seed                  # create the first admin
npm run dev                   # http://localhost:4000/api/v1
```

### 2. Frontend
```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```
(`10.0.2.2` is the host machine from the Android emulator; use your LAN IP for a physical device.)

### 3. First login
Use the seeded admin (`SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` from `.env`). New users register from the app and appear under **Approvals** for the admin to approve and assign a role.

## Deployment (Hostinger)
See [backend/README.md](backend/README.md#deployment-hostinger-vps) and [docs/10-development-roadmap.md](docs/10-development-roadmap.md#deployment-checklist-hostinger-vps).

## License
Proprietary — built for internal company use.
