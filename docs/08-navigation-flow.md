# 08 — Navigation Flow (GoRouter)

## 8.1 Route Table

| Route | Screen | Guard |
|-------|--------|-------|
| `/splash` | Splash | resolves session |
| `/login` | Login | unauth only |
| `/register` | Register | unauth only |
| `/pending` | Pending Approval | auth + status=pending |
| `/admin` | Admin shell → Dashboard | role=admin |
| `/admin/projects` | Projects list | admin |
| `/admin/projects/new` | Project form (create) | admin |
| `/admin/projects/:id` | Project detail | admin |
| `/admin/projects/:id/edit` | Project form (edit) | admin |
| `/admin/approvals` | Pending users | admin |
| `/admin/users` | Manage users | admin |
| `/admin/payments` | Payments overview | admin |
| `/admin/notifications` | Notifications | admin |
| `/supervisor` | Supervisor shell → Dashboard | role=supervisor |
| `/supervisor/projects` | Projects list | supervisor |
| `/supervisor/projects/:id` | Project detail | supervisor |
| `/supervisor/reports` | Reports / new report | supervisor |
| `/supervisor/plan` | Tomorrow planning | supervisor |
| `/supervisor/notifications` | Notifications | supervisor |
| `/designer` | Designer shell → Dashboard | role=designer |
| `/designer/projects` | Projects list | designer |
| `/designer/projects/:id` | Project detail | designer |
| `/designer/notifications` | Notifications | designer |
| `/worker` | Worker shell → Home | role=worker |
| `/worker/sites/:id` | Site detail | worker (assigned) |
| `/worker/reports` | EOD report | worker |
| `/worker/notifications` | Notifications | worker |
| `/viewer/:fileId` | PDF/Drawing viewer | any (scoped) |
| `/profile` | Profile/settings | any |

## 8.2 Redirect Logic (pseudo)

```dart
redirect: (context, state) {
  final auth = ref.read(authControllerProvider);
  final loggingIn = state.matchedLocation == '/login'
                 || state.matchedLocation == '/register';

  if (auth.isLoading) return '/splash';
  if (auth.user == null) return loggingIn ? null : '/login';

  if (auth.user!.status == 'pending')  return '/pending';
  if (auth.user!.status == 'rejected') return '/login';

  // approved → keep out of auth pages, land on role home
  if (loggingIn || state.matchedLocation == '/splash' ||
      state.matchedLocation == '/pending') {
    return _homeForRole(auth.user!.role);
  }
  return null;
}

String _homeForRole(String role) => switch (role) {
  'admin'      => '/admin',
  'supervisor' => '/supervisor',
  'designer'   => '/designer',
  'worker'     => '/worker',
  _            => '/login',
};
```

## 8.3 Shell / Bottom Navigation per role

Using `StatefulShellRoute.indexedStack` so each role keeps its own tab stack.

- **Admin tabs:** Dashboard · Projects · Approvals · Payments · Notifications
- **Supervisor tabs:** Dashboard · Projects · Reports · Plan · Notifications
- **Designer tabs:** Dashboard · Projects · Notifications
- **Worker tabs:** Home · Reports · Notifications

`role_scaffold.dart` builds the `NavigationBar` (Material 3) from a per-role list of destinations.

## 8.4 Deep Links (from notifications/push)
- `icms://project/:id` → role-appropriate project detail
- `icms://drawing/:fileId` → viewer
- `icms://report/:id` → report
- `icms://approvals` → admin approvals

Push payloads carry the same path in `data.route`, handled on tap to `context.go(route)`.
