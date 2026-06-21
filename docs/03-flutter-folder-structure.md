# 03 — Flutter Folder Structure

Feature-first architecture with shared `core/`. State via **Riverpod**, navigation via **GoRouter**, HTTP via **Dio**, offline cache via **Hive**, Material 3 theming.

```
frontend/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── main.dart                       # bootstrap: ProviderScope + ICMSApp
│   ├── app.dart                        # MaterialApp.router + theme + router
│   │
│   ├── core/
│   │   ├── config/
│   │   │   └── env.dart                # API base URL, file base URL
│   │   ├── theme/
│   │   │   ├── app_colors.dart         # #00D1DC, #FFFFFF, #F8FAFC ...
│   │   │   ├── app_theme.dart          # Material 3 ThemeData
│   │   │   └── app_spacing.dart
│   │   ├── network/
│   │   │   ├── dio_client.dart         # Dio + auth interceptor + refresh
│   │   │   ├── api_result.dart         # Result/Either-style wrapper
│   │   │   └── api_exception.dart
│   │   ├── storage/
│   │   │   ├── secure_store.dart       # tokens (flutter_secure_storage)
│   │   │   └── offline_cache.dart      # Hive boxes for drawings/sites
│   │   ├── router/
│   │   │   ├── app_router.dart         # GoRouter + redirect guards
│   │   │   └── routes.dart             # route name constants
│   │   ├── permissions/
│   │   │   └── permissions.dart        # role → capability matrix
│   │   ├── utils/
│   │   │   ├── formatters.dart         # currency, dates
│   │   │   └── validators.dart
│   │   └── widgets/                    # shared UI
│   │       ├── primary_button.dart
│   │       ├── app_text_field.dart
│   │       ├── stat_card.dart
│   │       ├── stage_chip.dart
│   │       ├── empty_state.dart
│   │       ├── loading_view.dart
│   │       └── role_scaffold.dart      # bottom nav per role
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_api.dart
│   │   │   ├── domain/
│   │   │   │   └── auth_user.dart
│   │   │   ├── application/
│   │   │   │   └── auth_controller.dart   # Riverpod Notifier
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       ├── register_screen.dart
│   │   │       └── pending_approval_screen.dart
│   │   │
│   │   ├── dashboard/
│   │   │   ├── application/dashboard_controller.dart
│   │   │   └── presentation/
│   │   │       ├── admin_dashboard.dart
│   │   │       ├── supervisor_dashboard.dart
│   │   │       ├── designer_dashboard.dart
│   │   │       └── worker_dashboard.dart
│   │   │
│   │   ├── projects/
│   │   │   ├── data/projects_repository.dart
│   │   │   ├── domain/{project.dart, project_stage.dart}
│   │   │   ├── application/{projects_controller.dart, project_detail_controller.dart}
│   │   │   └── presentation/
│   │   │       ├── projects_list_screen.dart
│   │   │       ├── project_detail_screen.dart
│   │   │       ├── project_form_screen.dart        # create/edit (admin)
│   │   │       └── tabs/{details_tab.dart, drawings_tab.dart, media_tab.dart,
│   │   │                 reports_tab.dart, payments_tab.dart, activity_tab.dart}
│   │   │
│   │   ├── drawings/
│   │   │   ├── data/drawings_repository.dart
│   │   │   ├── domain/drawing_file.dart
│   │   │   ├── application/drawings_controller.dart
│   │   │   └── presentation/
│   │   │       ├── drawings_screen.dart
│   │   │       └── pdf_viewer_screen.dart          # zoom/rotate/fullscreen/offline
│   │   │
│   │   ├── reports/
│   │   │   ├── data/reports_repository.dart
│   │   │   ├── domain/daily_report.dart
│   │   │   ├── application/reports_controller.dart
│   │   │   └── presentation/
│   │   │       ├── reports_list_screen.dart
│   │   │       ├── worker_report_form.dart
│   │   │       └── supervisor_report_form.dart
│   │   │
│   │   ├── payments/                  # admin only
│   │   │   ├── data/payments_repository.dart
│   │   │   ├── domain/payment.dart
│   │   │   ├── application/payments_controller.dart
│   │   │   └── presentation/{payments_screen.dart, add_payment_sheet.dart}
│   │   │
│   │   ├── users/                     # admin: approvals & role assignment
│   │   │   ├── data/users_repository.dart
│   │   │   ├── domain/managed_user.dart
│   │   │   ├── application/users_controller.dart
│   │   │   └── presentation/{approvals_screen.dart, manage_users_screen.dart}
│   │   │
│   │   ├── assignments/
│   │   │   └── presentation/{assign_workers_sheet.dart, tomorrow_plan_screen.dart}
│   │   │
│   │   └── notifications/
│   │       ├── data/notifications_repository.dart
│   │       ├── domain/app_notification.dart
│   │       ├── application/notifications_controller.dart
│   │       └── presentation/notifications_screen.dart
│   │
│   └── l10n/                          # localization-ready
│       └── app_en.arb
└── test/
    ├── permissions_test.dart
    └── widget/...
```

## Layering rule (per feature)
- **data** — repositories + API calls (Dio). No widgets.
- **domain** — immutable models / value objects. No Flutter imports.
- **application** — Riverpod controllers (`Notifier`/`AsyncNotifier`) exposing state to UI.
- **presentation** — screens & widgets only; read state via `ref.watch`.

## Routing strategy
GoRouter with a `redirect` that reads `authControllerProvider`:
- not authenticated → `/login`
- authenticated but `status=pending` → `/pending`
- authenticated + approved → role home (`/admin`, `/supervisor`, `/designer`, `/worker`).

Shell routes give each role a bottom-navigation scaffold (`role_scaffold.dart`).
