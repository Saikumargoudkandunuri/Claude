# Requirements Document

## Introduction

The Weekly Project Status feature provides a simple 3-state health indicator (On Track / Normal / Slow) for every project in ICMS Work Management. Admin and Supervisor users set a project's weekly health once per week on a Monday-reset cycle. The status chip is displayed across dashboards, project cards, and detail screens. Projects missing a current-week status surface in a "Needs Review" section for proactive management.

## Glossary

- **System**: The ICMS Work Management backend API and Flutter frontend application
- **Admin**: A user with role 'admin' who has full access to all projects
- **Supervisor**: A user with role 'supervisor' who can only manage their assigned projects
- **Weekly_Status**: A single health state value: 'on_track', 'normal', or 'slow'
- **Week_Start**: The Monday date (YYYY-MM-DD) that anchors the current ISO week
- **Status_Record**: A database row in project_weekly_status representing one status entry
- **Needs_Review**: Projects that have no Status_Record for the current week
- **Chip**: A color-coded UI widget displaying the current status visually (green/amber/red/grey)

## Requirements

### Requirement 1: Store Weekly Status

**User Story:** As a system operator, I want weekly project status stored durably with one entry per project per week, so that status history is preserved and concurrent updates are safe.

#### Acceptance Criteria

1. THE System SHALL store each Status_Record with fields: id (UUID), project_id, status, notes, set_by, week_start, and created_at
2. THE System SHALL enforce a UNIQUE constraint on (project_id, week_start) to guarantee one status per project per week
3. WHEN a project is deleted, THEN THE System SHALL cascade-delete all associated Status_Records
4. THE System SHALL restrict the status column to values 'on_track', 'normal', or 'slow' via a CHECK constraint
5. THE System SHALL limit the notes field to 200 characters maximum

### Requirement 2: Calculate Current Week

**User Story:** As a system operator, I want the system to automatically determine the current week boundary, so that status entries are correctly anchored to their ISO week.

#### Acceptance Criteria

1. THE System SHALL calculate Week_Start as the Monday of the current ISO week
2. WHEN getCurrentWeekMonday() is called on any day of the week, THEN THE System SHALL return a date that is always a Monday
3. WHEN getCurrentWeekMonday() is called on a Monday, THEN THE System SHALL return that same date
4. THE System SHALL return Week_Start in 'YYYY-MM-DD' string format

### Requirement 3: Set Project Weekly Status

**User Story:** As an Admin or Supervisor, I want to set a project's weekly health status, so that stakeholders can see project health at a glance.

#### Acceptance Criteria

1. WHEN an Admin or Supervisor submits a valid status for a project, THEN THE System SHALL upsert a Status_Record for the current week
2. WHEN a status already exists for the same project and week, THEN THE System SHALL update the existing record with the new status, notes, and set_by
3. WHEN a Supervisor attempts to set status for a project they are not assigned to, THEN THE System SHALL return a 403 Forbidden error
4. WHEN an Admin sets status for any project, THEN THE System SHALL allow it regardless of assignment
5. WHEN the submitted status value is not one of 'on_track', 'normal', or 'slow', THEN THE System SHALL return a 400 Bad Request error
6. WHEN the submitted notes exceed 200 characters, THEN THE System SHALL return a 400 Bad Request error
7. WHEN a valid status is set, THEN THE System SHALL return the full upserted Status_Record in the response

### Requirement 4: Retrieve Project Status

**User Story:** As a user, I want to view a project's current weekly status and its history, so that I can track project health over time.

#### Acceptance Criteria

1. WHEN a user requests the current status for a project, THEN THE System SHALL return the Status_Record matching the current Week_Start, or null if none exists
2. WHEN a user requests the status history for a project, THEN THE System SHALL return Status_Records ordered by week_start descending
3. THE System SHALL limit history results to a configurable number (default 12 weeks)

### Requirement 5: Dashboard Weekly Overview

**User Story:** As an Admin, I want a single endpoint that returns all projects' current-week status in one call, so that dashboard rendering does not require per-project API calls.

#### Acceptance Criteria

1. WHEN an Admin requests the weekly overview, THEN THE System SHALL return a map of project_id to Status_Record for the current week
2. THE System SHALL serve the weekly overview from GET /dashboard/weekly-overview
3. THE System SHALL restrict the weekly-overview endpoint to Admin role only

### Requirement 6: Needs Review List

**User Story:** As an Admin or Supervisor, I want to see which projects are missing a current-week status, so that I can ensure all projects are reviewed weekly.

#### Acceptance Criteria

1. WHEN an Admin requests the needs-review list, THEN THE System SHALL return all projects that have no Status_Record for the current week
2. WHEN a Supervisor requests the needs-review list, THEN THE System SHALL return only their assigned projects that have no Status_Record for the current week
3. THE System SHALL order the needs-review list alphabetically by project name
4. THE System SHALL serve the needs-review list from GET /dashboard/needs-review

### Requirement 7: API Route Protection

**User Story:** As a system architect, I want all weekly status endpoints properly authenticated and role-gated, so that unauthorized users cannot modify project status.

#### Acceptance Criteria

1. THE System SHALL require JWT authentication for all weekly status endpoints
2. WHEN an unauthenticated request is made to any weekly status endpoint, THEN THE System SHALL return a 401 Unauthorized error
3. THE System SHALL restrict PUT /projects/:id/weekly-status to Admin and Supervisor roles
4. THE System SHALL restrict GET /projects/:id/weekly-status/history to Admin and Supervisor roles
5. THE System SHALL allow any authenticated user to access GET /projects/:id/weekly-status (current status)
6. THE System SHALL restrict GET /dashboard/weekly-overview to Admin role
7. THE System SHALL restrict GET /dashboard/needs-review to Admin and Supervisor roles

### Requirement 8: Flutter Status Display

**User Story:** As a user, I want to see a color-coded status chip on project cards and detail screens, so that I can instantly assess project health without opening reports.

#### Acceptance Criteria

1. THE System SHALL display a WeeklyStatusChip on every project card in list views
2. THE System SHALL display a WeeklyStatusChip on the project detail screen header
3. WHEN the status is 'on_track', THEN THE Chip SHALL display in green
4. WHEN the status is 'normal', THEN THE Chip SHALL display in amber
5. WHEN the status is 'slow', THEN THE Chip SHALL display in red
6. WHEN no status exists for the current week, THEN THE Chip SHALL display in grey with "Not Set" text
7. THE Chip SHALL support a compact mode for list cards and a standard mode for detail screens

### Requirement 9: Flutter Set Status Interface

**User Story:** As an Admin or Supervisor, I want a bottom sheet interface to set or update a project's weekly status, so that I can quickly record my assessment with optional notes.

#### Acceptance Criteria

1. WHEN an Admin or Supervisor taps "Set Status" on a project detail screen, THEN THE System SHALL display a SetWeeklyStatusSheet bottom sheet
2. THE SetWeeklyStatusSheet SHALL present three radio options: On Track, Normal, and Slow
3. THE SetWeeklyStatusSheet SHALL include a notes text field limited to 200 characters
4. WHEN a status is submitted successfully, THEN THE System SHALL dismiss the sheet and update the chip in the UI
5. WHEN the current week already has a status set, THEN THE SetWeeklyStatusSheet SHALL pre-select the existing status and notes

### Requirement 10: Flutter Status History

**User Story:** As an Admin or Supervisor, I want to view the history of weekly status entries for a project, so that I can see trends over time.

#### Acceptance Criteria

1. WHEN an Admin or Supervisor opens the status history for a project, THEN THE System SHALL display a scrollable list of past Status_Records
2. THE System SHALL show each history entry with: status chip, notes (if any), set-by name, and week start date
3. THE System SHALL order history entries from most recent to oldest

### Requirement 11: Flutter Dashboard Needs Review Section

**User Story:** As an Admin or Supervisor, I want a "Needs Review" section on my dashboard showing projects without a current-week status, so that I can proactively manage incomplete reviews.

#### Acceptance Criteria

1. THE System SHALL display a "Needs Review" section on the Admin dashboard
2. THE System SHALL display a "Needs Review" section on the Supervisor dashboard
3. WHEN projects are missing a current-week status, THEN THE System SHALL display them as warning cards in the Needs Review section
4. WHEN all projects have a current-week status, THEN THE System SHALL hide or collapse the Needs Review section
5. THE System SHALL fetch needs-review data from GET /dashboard/needs-review in a single API call
