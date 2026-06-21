# 07 — Screen Flow

## 7.1 Entry & Auth

```
Splash
  ├─ has valid session? ── no ─► Login ──► (link) Register ──► Pending Approval (poll status)
  │                               │
  │                               └─ login success ──► route by role
  └─ yes ─► route by role / status
```

- **Register** → submits → "Awaiting admin approval" screen. App polls `/auth/me`; once `status=approved` and a role is set, it routes to the role home.

## 7.2 Admin Flow

```
Admin Dashboard (stats + recent updates)
 ├─ Projects ─► Projects List ─► Project Detail
 │                                 ├─ Details tab
 │                                 ├─ Drawings tab (view/download; upload via designer/admin)
 │                                 ├─ Media tab (photos/videos/voice)
 │                                 ├─ Reports tab (worker + supervisor)
 │                                 ├─ Payments tab (summary + add payment)
 │                                 ├─ Stages (override)
 │                                 └─ Activity tab
 │      └─ + New Project ─► Project Form ─► created (notify) ─► Project Detail
 ├─ Approvals ─► Pending Users ─► Approve(assign role)/Reject
 ├─ Users ─► Manage Users (disable / change role)
 ├─ Payments ─► cross-project outstanding overview
 └─ Notifications
```

## 7.3 Supervisor Flow

```
Supervisor Dashboard (my sites, today's work, pending reports)
 ├─ Projects List ─► Project Detail
 │     ├─ Assign Workers (sheet)
 │     ├─ Upload photos/videos/voice
 │     ├─ Advance execution stage
 │     ├─ Drawings (view/download)
 │     └─ Tomorrow Plan
 ├─ Daily Report ─► Supervisor Report Form (per site)
 ├─ Tomorrow Planning
 └─ Notifications
```

## 7.4 Designer Flow

```
Designer Dashboard (sites needing design, recent uploads)
 ├─ Projects List ─► Project Detail
 │     ├─ Upload 3D designs (replace/delete)
 │     ├─ Upload working/measurement drawings (replace/delete)
 │     ├─ Upload/replace quotation PDF
 │     └─ Advance design stage (Discussion/3D/Drawing)
 └─ Notifications
```

## 7.5 Worker Flow (intentionally minimal)

```
Worker Home
 ├─ Assigned Sites ─► Site Detail
 │     ├─ Today's Work (task)
 │     ├─ Drawings (open / download / offline)
 │     ├─ Mark Started / Mark Completed
 │     └─ Upload photo/video/voice
 ├─ Reports ─► End-of-Day Report Form (mandatory)
 ├─ Recent Sites
 └─ Notifications
```

Worker screens show only: Assigned Sites, Recent Sites, Today's Work, Drawings, Notifications, Reports. No payments, no other staff contacts, no directory.

## 7.6 Drawing Viewer (shared)

```
Drawings list ─► PDF Viewer
   • Zoom (pinch)  • Rotate  • Full screen  • Download  • Offline (cached)
```

## 7.7 Cross-cutting screens
- Notifications (all roles) — tap deep-links to project/report/drawing.
- Profile/Settings — name, phone, worker status (workshop/at site/leave/holiday), logout, push toggle.
