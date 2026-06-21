# ICMS Frontend (Flutter)

Flutter client for the Interior Company Management System. Material 3, mobile-first, light theme (primary `#00D1DC`). State via **Riverpod**, navigation via **GoRouter**, HTTP via **Dio**.

## Requirements
- Flutter 3.19+ (Dart 3.3+). Latest stable recommended.

## Setup
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```
- Android emulator → host machine is `10.0.2.2`.
- Physical device → use your machine's LAN IP (e.g. `http://192.168.1.10:4000/api/v1`).
- Production → your domain, e.g. `--dart-define=API_BASE_URL=https://yourdomain.com/api/v1`.

Build web (served by Nginx on Hostinger):
```bash
flutter build web --dart-define=API_BASE_URL=https://yourdomain.com/api/v1
# output: build/web  →  copy to /var/www/icms-web
```

## Architecture
Feature-first with a shared `core/`. Layers per feature: `data` (API/repos) → `domain` (models) → `application` (Riverpod controllers) → `presentation` (screens).

```
lib/
├── main.dart / app.dart
├── core/{config,theme,network,storage,router,permissions,utils,widgets}
└── features/
    ├── auth/         # login, register, pending approval, session
    ├── dashboard/    # role dashboards (admin/supervisor/designer/worker)
    ├── projects/     # list, detail (tabbed), create/edit form
    ├── drawings/     # files repo, PDF viewer (zoom/rotate/fullscreen)
    ├── reports/      # daily EOD report form + lists
    ├── payments/     # admin payments tab
    ├── notifications/
    └── users/        # admin approvals
```
Details: [../docs/03-flutter-folder-structure.md](../docs/03-flutter-folder-structure.md).

## Navigation
GoRouter with a redirect guard based on auth state:
- not signed in → `/login`
- signed in but `pending` → `/pending` (polls for approval)
- approved → role home (`/admin`, `/supervisor`, `/designer`, `/worker`)

Each role has a Material 3 bottom-navigation shell. Full map: [../docs/08-navigation-flow.md](../docs/08-navigation-flow.md).

## Permissions
`core/permissions/permissions.dart` mirrors the backend RBAC matrix to show/hide UI. The server remains the source of truth and re-checks every request.

## Auth & tokens
Access/refresh tokens are stored with `flutter_secure_storage`. `core/network/dio_client.dart` attaches the access token and transparently refreshes on 401, forcing logout if refresh fails.

## Tests
```bash
flutter test           # e.g. test/permissions_test.dart
```

## Notes
- Drawings open in a full-screen PDF viewer (Syncfusion) with auth headers.
- Worker screens are intentionally minimal (today's work, sites, drawings, report, notifications) and never expose other staff contact details.
- Push notifications (FCM) and full offline caching (Hive) are scaffolded for Phase 2 — see [../docs/10-development-roadmap.md](../docs/10-development-roadmap.md).
