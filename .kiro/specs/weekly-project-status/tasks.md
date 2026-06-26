# Implementation Plan: Weekly Project Status

## Overview

Implement a 3-state weekly health indicator (on_track / normal / slow) per project with Monday-reset cycle. Backend uses Express + PostgreSQL with upsert semantics. Frontend uses Flutter with existing DioClient singleton. All changes are additive — no existing files deleted or rewritten.

## Critical Constraints

- ADDITIVE ONLY — no existing files deleted or rewritten
- app.js gets only 2 new lines (import + route registration)
- Use existing `DioClient.instance` — do NOT create a new Dio instance
- Do NOT modify any existing migration (001–039)
- Supervisor RBAC: can only set status for own assigned projects
- Use `/dashboard/weekly-overview` for list views, NOT per-project calls in a loop
- Migration file uses `.sql` format matching the existing migration runner

## Tasks

- [x] 1. Database migration
  - [x] 1.1 Create migration file `backend/src/db/migrations/040_weekly_project_status.sql`
    - Create `project_weekly_status` table with columns: id (UUID PK), project_id (FK), status (VARCHAR(10) CHECK), notes (VARCHAR(200)), set_by (FK), week_start (DATE), created_at (TIMESTAMPTZ)
    - Add UNIQUE constraint on (project_id, week_start)
    - Add indexes: idx_pws_project_week (project_id, week_start DESC), idx_pws_set_by (set_by)
    - Use CASCADE on project_id FK, SET NULL on set_by FK
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [x] 1.2 Run migration to verify table creation
    - Run `npm run migrate` from backend directory
    - Verify table exists with correct schema
    - _Requirements: 1.1, 1.2_

- [x] 2. Backend module
  - [x] 2.1 Create `backend/src/modules/weekly_status/weekly_status.service.js`
    - Implement `getCurrentWeekMonday()` — returns 'YYYY-MM-DD' Monday of current ISO week
    - Implement `getProjectCurrentStatus(projectId)` — returns Status_Record or null
    - Implement `getProjectStatusHistory(projectId, limit=12)` — returns array sorted by week_start DESC
    - Implement `setProjectStatus(projectId, userId, userRole, { status, notes })` — validates input, checks supervisor assignment, upserts via INSERT...ON CONFLICT
    - Implement `getAllProjectsCurrentStatus()` — returns map of projectId → Status_Record for current week
    - Implement `getProjectsNeedingReview(userId, userRole)` — LEFT JOIN to find projects missing status, scoped for supervisors
    - Use `require('../../db/pool')` for queries, `require('../../utils/http')` for ApiError
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.1, 4.2, 4.3, 5.1, 6.1, 6.2, 6.3_

  - [x] 2.2 Create `backend/src/modules/weekly_status/weekly_status.controller.js`
    - Implement `getCurrentStatus(req, res, next)` — GET /projects/:id/weekly-status
    - Implement `getHistory(req, res, next)` — GET /projects/:id/weekly-status/history
    - Implement `setStatus(req, res, next)` — PUT /projects/:id/weekly-status
    - Implement `weeklyOverview(req, res, next)` — GET /dashboard/weekly-overview
    - Implement `needsReview(req, res, next)` — GET /dashboard/needs-review
    - All responses use `{ data: ... }` envelope pattern
    - _Requirements: 3.7, 4.1, 4.2, 5.1, 6.1_

  - [x] 2.3 Create `backend/src/modules/weekly_status/weekly_status.routes.js`
    - Mount routes with auth middleware (inherited from app.js `api` router)
    - GET `/projects/:id/weekly-status` — no extra role check (any authenticated user)
    - GET `/projects/:id/weekly-status/history` — requireRole('admin', 'supervisor')
    - PUT `/projects/:id/weekly-status` — requireRole('admin', 'supervisor')
    - GET `/dashboard/weekly-overview` — requireRole('admin')
    - GET `/dashboard/needs-review` — requireRole('admin', 'supervisor')
    - Router mounted at `/` (declares absolute paths like other modules)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

  - [x] 2.4 Register routes in `backend/src/app.js` (2 additive lines only)
    - Add import: `const weeklyStatusRoutes = require('./modules/weekly_status/weekly_status.routes');`
    - Add registration: `api.use('/', weeklyStatusRoutes);` in the `'/'`-mounted routes section
    - Do NOT modify any other lines in app.js
    - _Requirements: 7.1_

- [x] 3. Backend testing checkpoint
  - [x] 3.1 Test all 5 API endpoints manually or via automated tests
    - Test GET /projects/:id/weekly-status — returns null when no status set
    - Test PUT /projects/:id/weekly-status — set status with valid values, verify response
    - Test PUT with invalid status value — verify 400 error
    - Test PUT as supervisor on unassigned project — verify 403 error
    - Test GET /projects/:id/weekly-status/history — verify ordering
    - Test GET /dashboard/weekly-overview — verify map response
    - Test GET /dashboard/needs-review — verify projects without status appear
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 4.1, 4.2, 5.1, 6.1, 6.2, 7.3, 7.4, 7.5, 7.6, 7.7_

  - [ ]* 3.2 Write property test for getCurrentWeekMonday
    - **Property 1: Monday calculation invariant**
    - Generate random dates, verify result is always a Monday in 'YYYY-MM-DD' format within the same ISO week
    - **Validates: Requirements 2.1, 2.2, 2.4**

  - [ ]* 3.3 Write property test for upsert idempotence
    - **Property 2: Upsert idempotence**
    - Generate random valid status values, set status multiple times for same project/week, verify exactly one record exists with latest values
    - **Validates: Requirements 1.2, 3.1, 3.2**

  - [ ]* 3.4 Write property test for invalid status rejection
    - **Property 3: Invalid status rejection**
    - Generate random strings that are NOT 'on_track', 'normal', or 'slow', verify all are rejected
    - **Validates: Requirements 1.4, 3.5**

- [x] 4. Flutter data layer
  - [x] 4.1 Create `frontend/lib/features/projects/data/models/weekly_status_model.dart`
    - Define `WeeklyStatusModel` class with fields: id, projectId, status, notes, setBy, setByName, weekStart, createdAt
    - Implement `factory WeeklyStatusModel.fromJson(Map<String, dynamic> json)`
    - Implement `Map<String, dynamic> toJson()`
    - _Requirements: 4.1, 8.1_

  - [x] 4.2 Create `frontend/lib/features/projects/data/weekly_status_api.dart`
    - Use `DioClient.instance.dio` for HTTP calls (existing singleton)
    - Implement `getCurrentStatus(String projectId)` → WeeklyStatusModel?
    - Implement `getHistory(String projectId)` → List<WeeklyStatusModel>
    - Implement `setStatus(String projectId, String status, String? notes)` → WeeklyStatusModel
    - Implement `getWeeklyOverview()` → Map<String, WeeklyStatusModel>
    - Implement `getNeedsReview()` → List<Map<String, dynamic>>
    - _Requirements: 4.1, 4.2, 5.1, 6.1, 11.5_

- [x] 5. Flutter widgets
  - [x] 5.1 Create `frontend/lib/shared/widgets/weekly_status_chip.dart`
    - StatelessWidget with parameters: `String? status`, `bool compact`
    - Color mapping: on_track → green, normal → amber, slow → red, null → grey
    - Compact mode: smaller text + padding for list cards
    - Standard mode: larger chip for detail screens
    - Show "Not Set" text when status is null
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [x] 5.2 Create `frontend/lib/features/projects/presentation/set_weekly_status_sheet.dart`
    - StatefulWidget bottom sheet with parameters: projectId, currentStatus, currentNotes
    - Three radio cards: On Track (green), Normal (amber), Slow (red)
    - Notes TextField with 200 char maxLength
    - Pre-select current status and notes if provided
    - Submit calls WeeklyStatusApi.setStatus, then pops sheet on success
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [x] 5.3 Create `frontend/lib/features/projects/presentation/weekly_status_history_screen.dart`
    - Scaffold with AppBar title "Status History"
    - Fetch history from WeeklyStatusApi.getHistory on init
    - Display ListView of entries: WeeklyStatusChip + notes + set-by name + week_start date
    - Order: most recent first (API returns this order)
    - _Requirements: 10.1, 10.2, 10.3_

- [x] 6. Flutter integration
  - [x] 6.1 Integrate WeeklyStatusChip into project cards
    - Add WeeklyStatusChip(compact: true) to existing project list card widget
    - Fetch current status from the weekly-overview map (single API call, NOT per-card)
    - ADDITIVE ONLY — add chip widget to existing card layout
    - _Requirements: 8.1_

  - [x] 6.2 Integrate chip + set button into project detail screen
    - Add WeeklyStatusChip(compact: false) to project detail header
    - Add "Set Status" button (visible only for admin/supervisor roles)
    - Tapping button opens SetWeeklyStatusSheet
    - Add navigation to WeeklyStatusHistoryScreen from detail
    - ADDITIVE ONLY — add widgets to existing layout
    - _Requirements: 8.2, 9.1_

  - [x] 6.3 Add "Needs Review" section to admin and supervisor dashboards
    - Fetch from GET /dashboard/needs-review via WeeklyStatusApi.getNeedsReview()
    - Display as collapsible section with warning-style project cards
    - Hide section when list is empty
    - Tapping a card navigates to that project's detail screen
    - ADDITIVE ONLY — add section widget to existing dashboard body
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 7. Final verification
  - [x] 7.1 Test full flow end-to-end
    - Verify: set status → chip updates → history shows entry → needs-review excludes project
    - Verify supervisor RBAC: cannot set status on unassigned project
    - Verify admin: can set status on any project
    - Verify upsert: setting same week again updates rather than duplicates
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 6.1, 6.2_

  - [x] 7.2 Build release APK
    - Run `flutter build apk --release` from frontend directory
    - Verify build completes without errors
    - _Requirements: all_

## Task Dependency Graph

```json
{
  "waves": [
    {
      "name": "Wave 1: Database",
      "tasks": ["1.1", "1.2"]
    },
    {
      "name": "Wave 2: Backend Module",
      "tasks": ["2.1", "2.2", "2.3", "2.4"],
      "dependsOn": ["Wave 1: Database"]
    },
    {
      "name": "Wave 3: Backend Testing",
      "tasks": ["3.1", "3.2", "3.3", "3.4"],
      "dependsOn": ["Wave 2: Backend Module"]
    },
    {
      "name": "Wave 4: Flutter Data Layer & Widgets",
      "tasks": ["4.1", "4.2", "5.1", "5.2", "5.3"],
      "dependsOn": ["Wave 3: Backend Testing"]
    },
    {
      "name": "Wave 5: Flutter Integration",
      "tasks": ["6.1", "6.2", "6.3"],
      "dependsOn": ["Wave 4: Flutter Data Layer & Widgets"]
    },
    {
      "name": "Wave 6: Final Verification",
      "tasks": ["7.1", "7.2"],
      "dependsOn": ["Wave 5: Flutter Integration"]
    }
  ]
}
```

## Notes

- Tasks marked with `*` are optional property-based tests and can be skipped for faster MVP
- Migration number is 040 (031–039 are already taken by existing migrations)
- The migration runner processes `.sql` files only — do NOT use `.js` migration format
- All route registration follows the existing pattern: mounted at `/` with absolute paths
- The WeeklyStatusApi uses `DioClient.instance.dio` (the Dio getter on the existing singleton)
- Dashboard views use `/dashboard/weekly-overview` for batch fetching (not per-project calls)
- Dependencies between tasks: 2→1, 3→2, 4 & 5 can run in parallel after 3, 6→(4+5), 7→6
