# Implementation Plan: Customer Portal

## Overview

Implement a customer-facing project tracking portal with separate mobile+PIN authentication, dedicated API endpoints under `/customer/`, and a Flutter frontend with 5-tab shell (Home, Photos, Timeline, Payments, Messages). Backend follows the existing module pattern (routes → controller → service → schema). Frontend follows data/ → application/ → presentation/ per feature. All changes are additive — no existing files deleted or rewritten.

## Critical Constraints

- ADDITIVE ONLY — no existing files deleted or migrations altered
- Customer JWT uses separate secret (`CUSTOMER_JWT_SECRET`) from staff (`JWT_SECRET`)
- Customer routes mounted BEFORE the `authenticate + requireApproved` middleware in app.js
- Customer auth middleware is a NEW file (`customerAuth.js`), not a modification of existing `auth.js`
- All customer data queries scoped by `WHERE project_id = $1` from JWT payload
- Migration file numbered `045` using `.sql` format
- Frontend uses existing `DioClient` pattern but with separate token storage key (`customer_access_token`)
- Do NOT use `serializeProject` for customer endpoints — use explicit field whitelists

## Tasks

- [x] 1. Database migration
  - [x] 1.1 Create migration file `backend/src/db/migrations/045_customer_portal.sql`
    - ALTER TABLE projects ADD COLUMN customer_mobile TEXT, customer_mobile_alt TEXT, customer_pin_hash TEXT, customer_pin_set BOOLEAN NOT NULL DEFAULT false, customer_last_login TIMESTAMPTZ
    - CREATE INDEX idx_projects_customer_mobile ON projects(customer_mobile) WHERE customer_mobile IS NOT NULL
    - CREATE TABLE customer_notifications (id UUID PK, project_id UUID FK, title TEXT NOT NULL, body TEXT NOT NULL, is_read BOOLEAN DEFAULT false, created_at TIMESTAMPTZ DEFAULT now())
    - CREATE TABLE customer_messages (id UUID PK, project_id UUID FK, title TEXT NOT NULL, body TEXT NOT NULL, posted_by UUID FK to users, created_at TIMESTAMPTZ DEFAULT now())
    - Add indexes: idx_customer_notifications_project (project_id, created_at DESC), idx_customer_messages_project (project_id, created_at DESC)
    - Use CASCADE on project_id FKs, SET NULL on posted_by FK
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 2. Backend customer auth middleware and rate limiters
  - [x] 2.1 Create `backend/src/middleware/customerAuth.js`
    - Extract Bearer token from Authorization header
    - Verify token using `CUSTOMER_JWT_SECRET` (from process.env)
    - Validate payload contains `role: 'customer'` — reject if not
    - Attach `req.customer = { projectId, customerName, mobile }` from payload
    - On any failure, return 401 with generic "Invalid or expired token" message (same as staff errors)
    - _Requirements: 4.1, 4.3, 4.4, 15.1_

  - [x] 2.2 Add customer rate limiters to `backend/src/middleware/rateLimit.js`
    - Add `customerLoginLimiter`: 5 attempts per mobile per 15-minute window (keyGenerator uses req.body.mobile)
    - Add `customerCheckMobileLimiter`: 10 attempts per IP per 15-minute window (default keyGenerator)
    - Both return 429 with `{ error: { code: 'RATE_LIMITED', message: 'Too many attempts, try later' } }`
    - Export both new limiters alongside existing ones
    - _Requirements: 23.1, 23.2, 23.3_

- [x] 3. Backend customer module
  - [x] 3.1 Create `backend/src/modules/customer/customer.schema.js`
    - Define Zod schema for check-mobile: `{ mobile: z.string() }`
    - Define Zod schema for set-pin: `{ mobile: z.string(), pin: z.string().regex(/^\d{4}$/) }`
    - Define Zod schema for login: `{ mobile: z.string(), pin: z.string() }`
    - Define Zod schema for admin announce: `{ projectId: z.string().uuid(), title: z.string().min(1), body: z.string().min(1) }`
    - Define Zod schema for admin reset-pin: `{ projectId: z.string().uuid() }`
    - Export all schemas
    - _Requirements: 2.4, 2.5, 13.3_

  - [x] 3.2 Create `backend/src/modules/customer/customer.service.js`
    - Implement `checkMobile(mobile)` — query projects WHERE customer_mobile = $1, return { found, customerName, pinSet } or throw 404
    - Implement `setPin(mobile, pin)` — find project by mobile, verify customer_pin_set is false (else 409), bcrypt hash PIN, UPDATE customer_pin_hash and customer_pin_set = true
    - Implement `login(mobile, pin)` — find project by mobile, bcrypt compare PIN, issue JWT with { role:'customer', projectId, customerName, mobile } signed with CUSTOMER_JWT_SECRET (30d expiry), update customer_last_login
    - Implement `getOverview(projectId)` — SELECT only: project_name, customer_name, current_stage, start_date, expected_completion_date, project_type, address FROM projects WHERE id = $1
    - Implement `getTimeline(projectId)` — SELECT stage history + planned dates for project
    - Implement `getPhotos(projectId)` — SELECT id, original_name, created_at FROM files WHERE project_id = $1 AND category = 'photo' ORDER BY created_at DESC
    - Implement `getDrawings(projectId)` — SELECT id, original_name, version_number, approved_at, created_at FROM files WHERE project_id = $1 AND category = 'drawing' AND approval_status = 'approved'
    - Implement `getPaymentSummary(projectId)` — SELECT quotation_amount, compute total_received from payments, calculate outstanding_balance
    - Implement `getNotifications(projectId)` — SELECT from customer_notifications WHERE project_id = $1 ORDER BY created_at DESC
    - Implement `markNotificationRead(notificationId, projectId)` — UPDATE is_read = true WHERE id = $1 AND project_id = $2
    - Implement `getMessages(projectId)` — SELECT id, title, body, created_at FROM customer_messages WHERE project_id = $1 ORDER BY created_at DESC (exclude posted_by)
    - Implement `postAnnouncement(projectId, title, body, adminUserId)` — INSERT into customer_messages
    - Implement `resetPin(projectId)` — UPDATE customer_pin_hash = NULL, customer_pin_set = false WHERE id = $1
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 7.4, 8.1, 8.2, 8.3, 8.4, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 11.1, 11.2, 11.3, 11.4, 12.1, 12.2, 12.3, 12.4, 13.1, 13.3, 14.1, 14.3, 15.1, 15.2, 15.3_

  - [x] 3.3 Create `backend/src/modules/customer/customer.controller.js`
    - Implement `checkMobile(req, res, next)` — call service.checkMobile, return { data: { found, customerName, pinSet } }
    - Implement `setPin(req, res, next)` — call service.setPin, return { data: { success: true } }
    - Implement `login(req, res, next)` — call service.login, return { data: { token, customerName, projectId } }
    - Implement `getOverview(req, res, next)` — use req.customer.projectId
    - Implement `getTimeline(req, res, next)` — use req.customer.projectId
    - Implement `getPhotos(req, res, next)` — use req.customer.projectId
    - Implement `getDrawings(req, res, next)` — use req.customer.projectId
    - Implement `getPayments(req, res, next)` — use req.customer.projectId
    - Implement `getNotifications(req, res, next)` — use req.customer.projectId
    - Implement `markNotificationRead(req, res, next)` — use req.customer.projectId + req.params.id
    - Implement `getMessages(req, res, next)` — use req.customer.projectId
    - Implement `postAnnouncement(req, res, next)` — use req.user.id as admin (staff auth)
    - Implement `resetPin(req, res, next)` — staff auth admin endpoint
    - _Requirements: 1.1, 1.2, 1.3, 3.1, 6.1, 7.1, 8.1, 9.1, 10.1, 11.1, 12.1, 13.1, 14.1_

  - [x] 3.4 Create `backend/src/modules/customer/customer.routes.js`
    - Public auth routes (no auth middleware):
      - POST `/customer/auth/check-mobile` — customerCheckMobileLimiter + validate(checkMobileSchema) + controller.checkMobile
      - POST `/customer/auth/set-pin` — validate(setPinSchema) + controller.setPin
      - POST `/customer/auth/login` — customerLoginLimiter + validate(loginSchema) + controller.login
    - Customer-authenticated routes (customerAuth middleware):
      - GET `/customer/overview` — controller.getOverview
      - GET `/customer/timeline` — controller.getTimeline
      - GET `/customer/photos` — controller.getPhotos
      - GET `/customer/drawings` — controller.getDrawings
      - GET `/customer/payments` — controller.getPayments
      - GET `/customer/notifications` — controller.getNotifications
      - PUT `/customer/notifications/:id/read` — controller.markNotificationRead
      - GET `/customer/messages` — controller.getMessages
    - Admin routes (staff authenticate + requireRole('admin')):
      - POST `/customer/admin/announce` — validate(announceSchema) + controller.postAnnouncement
      - POST `/customer/admin/reset-pin` — validate(resetPinSchema) + controller.resetPin
    - _Requirements: 4.1, 4.2, 13.2, 14.2, 23.1, 23.3_

  - [x] 3.5 Register customer routes in `backend/src/app.js`
    - Add import: `const customerRoutes = require('./modules/customer/customer.routes');`
    - Mount BEFORE the `authenticate + requireApproved` block: `api.use('/', customerRoutes);`
    - This ensures customer auth endpoints are public and customer-authenticated endpoints use their own middleware
    - Do NOT modify any other lines in app.js
    - _Requirements: 4.1, 4.2_

  - [x] 3.6 Add `CUSTOMER_JWT_SECRET` and `CUSTOMER_JWT_EXPIRY` to `backend/src/config/index.js`
    - Add `customerJwtSecret: process.env.CUSTOMER_JWT_SECRET` to config export
    - Add `customerJwtExpiry: process.env.CUSTOMER_JWT_EXPIRY || '30d'` to config export
    - _Requirements: 3.5, 4.3_

- [x] 4. Backend checkpoint
  - [x] 4.1 Ensure all backend tests pass and endpoints work
    - Run migration 045 to verify schema creation
    - Test auth flow: check-mobile → set-pin → login → use token on customer endpoints
    - Test JWT isolation: staff token rejected on customer endpoints, customer token rejected on staff endpoints
    - Test admin endpoints: announce + reset-pin require admin role
    - Test rate limiting: 5 login attempts trigger 429, 10 check-mobile attempts trigger 429
    - Ensure all tests pass, ask the user if questions arise.
    - _Requirements: 1.1–1.4, 2.1–2.5, 3.1–3.5, 4.1–4.4, 23.1–23.3_

  - [ ]* 4.2 Write property test for PIN validation rejection
    - **Property 3: PIN Validation Rejects Invalid Input**
    - Use fast-check to generate arbitrary strings NOT matching `/^\d{4}$/` (letters, length ≠ 4, special chars, empty)
    - Verify all are rejected by the set-pin schema with validation error
    - **Validates: Requirements 2.4**

  - [ ]* 4.3 Write property test for JWT structure after login
    - **Property 4: Login Produces Correctly-Structured JWT**
    - Use fast-check to generate random 4-digit PINs and project data
    - After login, decode JWT with CUSTOMER_JWT_SECRET and verify payload contains exactly role:'customer', correct projectId, customerName, mobile, and expiry ~30 days
    - **Validates: Requirements 3.1, 3.2, 3.5**

  - [ ]* 4.4 Write property test for overview field whitelist
    - **Property 7: Project Overview Field Whitelist**
    - Use fast-check to generate random project rows with all fields populated
    - Verify customer overview response contains ONLY projectName, customerName, currentStage, startDate, expectedCompletionDate, projectType, address
    - Verify response does NOT contain remarks, supervisorId, designerId, createdBy, quotationAmount, isArchived
    - **Validates: Requirements 6.1, 6.3**

  - [ ]* 4.5 Write property test for payment summary calculation
    - **Property 10: Payment Summary Calculation**
    - Use fast-check to generate random quotation amounts and payment arrays
    - Verify outstandingBalance === quotationAmount - totalReceived
    - Verify no individual transaction records, dates, or methods in response
    - **Validates: Requirements 10.1, 10.2, 10.3**

  - [ ]* 4.6 Write property test for messages exclude posted_by
    - **Property 11: Messages Exclude posted_by Field**
    - Use fast-check to generate random messages with posted_by UUIDs
    - Verify customer messages response includes id, title, body, createdAt but NOT posted_by
    - **Validates: Requirements 12.1, 12.2, 12.3**

  - [ ]* 4.7 Write property test for JWT isolation
    - **Property 6: JWT Isolation Between Customer and Staff**
    - Generate valid staff JWTs and present to customer endpoints — verify 401
    - Generate valid customer JWTs and present to staff endpoints — verify 401
    - **Validates: Requirements 4.1, 4.2**

- [x] 5. Flutter customer auth feature
  - [x] 5.1 Create `frontend/lib/features/customer_auth/data/customer_auth_api.dart`
    - Use Dio with base URL from Env.apiBase
    - Implement `checkMobile(String mobile)` → returns { found, customerName, pinSet }
    - Implement `setPin(String mobile, String pin)` → returns success
    - Implement `login(String mobile, String pin)` → returns { token, customerName, projectId }
    - No auth interceptor needed for these endpoints (they're public)
    - _Requirements: 1.1, 2.1, 3.1_

  - [x] 5.2 Create `frontend/lib/features/customer_auth/application/customer_auth_controller.dart`
    - Riverpod StateNotifier or AsyncNotifier managing customer auth state
    - Store token in flutter_secure_storage under key `customer_access_token`
    - Implement checkMobile flow: mobile → API call → return result
    - Implement setPin flow: mobile + pin → API call → auto-login
    - Implement login flow: mobile + pin → API call → store token → navigate to shell
    - Implement logout: clear `customer_access_token`, navigate to customer-login
    - On 401 response from any customer API call: trigger logout
    - _Requirements: 3.1, 21.1, 21.3_

  - [x] 5.3 Create `frontend/lib/features/customer_auth/presentation/customer_login_screen.dart`
    - Mobile number input with +91 prefix (matching existing staff pattern)
    - "Continue" button calls checkMobile API
    - On success (found=true, pinSet=true): show greeting with customerName, transition to PIN input (4-digit custom keypad)
    - On success (found=true, pinSet=false): navigate to CustomerSetPinScreen
    - On failure (not found): show inline error "No project linked to this mobile number"
    - Use #00D1DC teal brand color throughout
    - PIN input: 4 circles with custom numeric keypad, submit on 4th digit entry
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_

  - [x] 5.4 Create `frontend/lib/features/customer_auth/presentation/customer_set_pin_screen.dart`
    - Custom numeric keypad for 4-digit PIN entry
    - Two-step flow: enter PIN → confirm PIN
    - On match: call setPin API, then auto-login and navigate to customer shell
    - On mismatch: show error "PINs do not match", clear both inputs
    - Use #00D1DC teal brand color
    - _Requirements: 17.1, 17.2, 17.3, 17.4_

- [x] 6. Flutter customer portal data layer
  - [x] 6.1 Create `frontend/lib/core/network/customer_dio_client.dart`
    - Separate Dio instance or interceptor that reads token from `customer_access_token` storage key
    - Attach Authorization: Bearer header from stored token
    - On 401 response: clear token, redirect to /customer-login
    - No refresh token logic — simple token expiry handling
    - _Requirements: 21.1, 4.4_

  - [x] 6.2 Create `frontend/lib/features/customer_portal/data/customer_api.dart`
    - Use CustomerDioClient for all calls
    - Implement `getOverview()` → project overview data
    - Implement `getTimeline()` → list of stage entries
    - Implement `getPhotos()` → list of photos
    - Implement `getDrawings()` → list of approved drawings
    - Implement `getPaymentSummary()` → { quotationAmount, totalReceived, outstandingBalance }
    - Implement `getNotifications()` → list of notifications
    - Implement `markNotificationRead(String id)` → success
    - Implement `getMessages()` → list of messages
    - _Requirements: 6.1, 7.1, 8.1, 9.1, 10.1, 11.1, 12.1_

  - [x] 6.3 Create `frontend/lib/features/customer_portal/application/customer_providers.dart`
    - FutureProvider for overview data
    - FutureProvider for timeline data
    - FutureProvider for photos list
    - FutureProvider for drawings list
    - FutureProvider for payment summary
    - FutureProvider for notifications
    - FutureProvider for messages
    - All providers use CustomerApi methods
    - _Requirements: 6.1, 7.1, 8.1, 9.1, 10.1, 11.1, 12.1_

- [x] 7. Flutter customer portal screens
  - [x] 7.1 Create `frontend/lib/features/customer_portal/presentation/customer_shell.dart`
    - Bottom navigation bar with 5 tabs: Home, Photos, Timeline, Payments, Messages
    - Use #00D1DC teal brand color for active tab
    - Persist navigation state when switching between tabs (use StatefulShellRoute or IndexedStack)
    - Icons: Home, PhotoLibrary, Timeline, Payments, Message
    - _Requirements: 20.1, 20.2, 20.3_

  - [x] 7.2 Create `frontend/lib/features/customer_portal/presentation/customer_home_screen.dart`
    - Hero progress card: project name + current stage with visual indicator
    - Latest photos section: horizontal scroll of recent photos (thumbnail tap → full view)
    - Stage strip: horizontal scrollable 13-stage progression indicator
    - Payment summary section: quotation, received, outstanding amounts
    - Recent messages section: latest admin announcements
    - Pull-to-refresh to reload all data
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5_

  - [x] 7.3 Create `frontend/lib/features/customer_portal/presentation/customer_photos_screen.dart`
    - Grid layout of project photos
    - Tap photo → full-screen view (use existing photo_view pattern)
    - Ordered newest first
    - Empty state when no photos available
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 7.4 Create `frontend/lib/features/customer_portal/presentation/customer_timeline_screen.dart`
    - Vertical timeline widget showing all 13 project stages
    - Completed stages: teal checkmark + date reached
    - Current stage: highlighted/animated indicator
    - Upcoming stages: greyed out + planned dates where available
    - _Requirements: 19.1, 19.2, 19.3, 19.4_

  - [x] 7.5 Create `frontend/lib/features/customer_portal/presentation/customer_payments_screen.dart`
    - Summary card showing: Quotation Amount, Total Received, Outstanding Balance
    - Visual progress indicator (received / quotation ratio)
    - No individual transaction records shown
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 7.6 Create `frontend/lib/features/customer_portal/presentation/customer_messages_screen.dart`
    - List of admin announcements ordered newest first
    - Each message card shows: title, body preview, created_at formatted
    - Tap to expand full message body
    - Empty state when no messages
    - _Requirements: 12.1, 12.2, 12.3_

- [x] 8. Flutter routing integration
  - [x] 8.1 Add customer routes to `frontend/lib/core/router/app_router.dart`
    - Add new ShellRoute for customer paths (ADDITIVE — do not modify existing routes)
    - Routes: /customer-login, /customer-set-pin, /customer (shell with sub-routes)
    - Sub-routes: /customer/home, /customer/photos, /customer/timeline, /customer/payments, /customer/messages
    - Redirect logic: if web build and no customer_access_token → /customer-login
    - Android build maintains existing staff login as default entry point
    - _Requirements: 21.1, 21.2, 21.3, 21.4_

- [x] 9. Frontend checkpoint
  - [x] 9.1 Ensure Flutter app builds and all screens render
    - Verify `flutter build web` succeeds with customer portal routes
    - Verify `flutter build apk --release` succeeds
    - Verify customer login → set PIN → home flow works
    - Verify all 5 tabs display correct data from API
    - Verify staff login flow is unaffected
    - Ensure all tests pass, ask the user if questions arise.
    - _Requirements: 16.1–22.5_

  - [ ]* 9.2 Write widget tests for customer auth screens
    - Test CustomerLoginScreen renders mobile input, transitions to PIN on valid mobile
    - Test CustomerSetPinScreen double-entry confirmation and mismatch error
    - Test CustomerShell displays 5 tabs with correct icons
    - _Requirements: 16.1, 17.1, 20.1_

- [x] 10. PWA configuration and deployment files
  - [x] 10.1 Configure PWA files for Hostinger deployment
    - Update/create `frontend/web/manifest.json` with: name "Metal & More Interiors", short_name "M&M Portal", display "standalone", theme_color "#00D1DC", background_color "#FFFFFF"
    - Add iOS meta tags to `frontend/web/index.html`: apple-mobile-web-app-capable, apple-mobile-web-app-status-bar-style, apple-mobile-web-app-title
    - Create `.htaccess` file for SPA routing on Hostinger (rewrite all routes to index.html)
    - Create `download.html` landing page with APK download link
    - _Requirements: 22.1, 22.2, 22.3, 22.4, 22.5_

- [x] 11. Final checkpoint
  - [x] 11.1 End-to-end verification of complete customer portal
    - Verify full auth flow: check-mobile → set-pin → login → token issued → customer shell loads
    - Verify JWT isolation: customer token cannot access staff endpoints and vice versa
    - Verify all 5 tabs return correctly scoped data (photos, timeline, payments, messages, overview)
    - Verify admin can post announcement and reset PIN
    - Verify rate limiting works on auth endpoints
    - Verify PWA manifest and meta tags are correct
    - Ensure all tests pass, ask the user if questions arise.
    - _Requirements: 1.1–23.3_

## Notes

- Tasks marked with `*` are optional property-based tests and can be skipped for faster MVP
- Migration number is 045 (044 is the latest existing migration)
- Customer routes must be mounted BEFORE the `authenticate + requireApproved` middleware block in app.js so that public customer auth endpoints work and customer-authed endpoints use their own middleware
- The existing `serializeProject` function is NOT used — customer endpoints use explicit column selection
- `CUSTOMER_JWT_SECRET` must be added to `.env` and `.env.example` before testing
- The customer module follows the same pattern as other modules: routes.js → controller.js → service.js → schema.js
- Frontend customer_auth and customer_portal are separate feature folders matching the existing feature-folder architecture
- PWA deployment assumes Hostinger Apache hosting with .htaccess SPA rewrite support

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1", "2.2", "3.1", "3.6"] },
    { "id": 2, "tasks": ["3.2", "3.3"] },
    { "id": 3, "tasks": ["3.4", "3.5"] },
    { "id": 4, "tasks": ["4.1", "4.2", "4.3", "4.4", "4.5", "4.6", "4.7"] },
    { "id": 5, "tasks": ["5.1", "6.1"] },
    { "id": 6, "tasks": ["5.2", "5.3", "5.4", "6.2"] },
    { "id": 7, "tasks": ["6.3", "7.1"] },
    { "id": 8, "tasks": ["7.2", "7.3", "7.4", "7.5", "7.6"] },
    { "id": 9, "tasks": ["8.1"] },
    { "id": 10, "tasks": ["9.1", "9.2", "10.1"] },
    { "id": 11, "tasks": ["11.1"] }
  ]
}
```
