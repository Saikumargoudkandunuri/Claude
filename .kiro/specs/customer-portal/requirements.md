# Requirements Document

## Introduction

The Customer Portal provides Metal & More Interiors customers with a dedicated interface to track their interior project progress. Unlike staff users who authenticate via email/password, customers authenticate using their mobile number and a 4-digit PIN. The portal is deployed as a Flutter Web PWA on a Hostinger subdomain and as an Android APK built from the same Flutter codebase. Customers see only their own project data — no internal operations, staff details, or raw transaction records are exposed.

## Glossary

- **Customer_Portal**: The Flutter-based web and Android application that serves as the customer-facing project tracking interface
- **Customer**: An end-user (project owner) who is NOT a staff member; authenticates via mobile number + PIN
- **Customer_Auth_Service**: The backend service handling customer authentication (mobile lookup, PIN management, JWT issuance)
- **Customer_API**: The set of backend endpoints prefixed with `/customer/` that serve customer-scoped data
- **Customer_JWT**: A JSON Web Token issued to authenticated customers, signed with CUSTOMER_JWT_SECRET, containing role:'customer', projectId, customerName, and mobile
- **Staff_JWT**: The existing JSON Web Token issued to staff users, signed with JWT_SECRET
- **PIN**: A 4-digit numeric code used by customers to authenticate after initial mobile verification
- **Project_Timeline**: The 13-stage progression tracking a project from discussion through handover
- **Customer_Shell**: The bottom-navigation wrapper providing Home, Photos, Timeline, Payments, and Messages tabs
- **Admin_Announcement**: A message posted by admin to a specific customer visible in the customer portal
- **Field_Whitelist**: The explicit set of project fields returned to customers, excluding internal data

## Requirements

### Requirement 1: Customer Mobile Lookup

**User Story:** As a customer, I want to enter my mobile number so that the system can identify my project and greet me by name.

#### Acceptance Criteria

1. WHEN a mobile number is submitted to the check-mobile endpoint, THE Customer_Auth_Service SHALL search the projects table for a matching customer_mobile value
2. WHEN a matching project is found, THE Customer_Auth_Service SHALL return the customer_name associated with that project
3. WHEN no matching project is found, THE Customer_Auth_Service SHALL return an error indicating no project is linked to that mobile number
4. THE Customer_Auth_Service SHALL accept the check-mobile request without requiring any authentication token

### Requirement 2: Customer PIN Creation

**User Story:** As a first-time customer, I want to set a 4-digit PIN so that I can securely access my project portal on future visits.

#### Acceptance Criteria

1. WHEN a customer whose customer_pin_set is false submits a 4-digit PIN, THE Customer_Auth_Service SHALL hash the PIN and store it in the customer_pin_hash column
2. WHEN the PIN is stored successfully, THE Customer_Auth_Service SHALL set customer_pin_set to true for that project record
3. WHEN a customer whose customer_pin_set is already true attempts to set a PIN, THE Customer_Auth_Service SHALL reject the request with an error
4. THE Customer_Auth_Service SHALL validate that the PIN is exactly 4 numeric digits before accepting it
5. THE Customer_Auth_Service SHALL require the customer mobile number in the set-pin request to identify the project

### Requirement 3: Customer PIN Login

**User Story:** As a returning customer, I want to log in with my mobile number and PIN so that I can access my project progress.

#### Acceptance Criteria

1. WHEN a customer submits a valid mobile number and correct PIN, THE Customer_Auth_Service SHALL issue a Customer_JWT with 30-day expiry
2. THE Customer_JWT SHALL contain the fields: role set to 'customer', projectId, customerName, and mobile
3. WHEN a customer submits an incorrect PIN, THE Customer_Auth_Service SHALL return an authentication error without revealing whether the mobile exists
4. WHEN a customer submits a correct PIN, THE Customer_Auth_Service SHALL update the customer_last_login timestamp
5. THE Customer_Auth_Service SHALL sign the Customer_JWT using CUSTOMER_JWT_SECRET, which is separate from the staff JWT_SECRET

### Requirement 4: Customer and Staff JWT Isolation

**User Story:** As a system administrator, I want customer and staff authentication to be completely separate so that neither token type can access the other's endpoints.

#### Acceptance Criteria

1. THE Customer_API SHALL reject any request bearing a Staff_JWT with an unauthorized error
2. THE Staff API SHALL reject any request bearing a Customer_JWT with an unauthorized error
3. THE Customer_Auth_Service SHALL use a separate JWT secret (CUSTOMER_JWT_SECRET) from the staff authentication secret (JWT_SECRET)
4. WHEN a Customer_JWT is verified, THE Customer_API SHALL extract projectId from the token payload to scope all data queries

### Requirement 5: Database Schema for Customer Portal

**User Story:** As a developer, I want the database schema extended with customer portal columns and tables so that customer authentication and communication data can be stored.

#### Acceptance Criteria

1. THE Migration SHALL add columns customer_mobile (text), customer_mobile_alt (text), customer_pin_hash (text), customer_pin_set (boolean default false), and customer_last_login (timestamptz) to the projects table
2. THE Migration SHALL create a customer_notifications table with columns: id (uuid PK), project_id (uuid FK to projects), title (text), body (text), is_read (boolean default false), created_at (timestamptz)
3. THE Migration SHALL create a customer_messages table with columns: id (uuid PK), project_id (uuid FK to projects), title (text), body (text), posted_by (uuid FK to users), created_at (timestamptz)
4. THE Migration SHALL use the .sql file format numbered as 045
5. THE Migration SHALL be additive only and not alter existing column definitions or constraints

### Requirement 6: Customer Project Overview

**User Story:** As a customer, I want to see an overview of my project so that I can understand the current status at a glance.

#### Acceptance Criteria

1. WHEN an authenticated customer requests their project overview, THE Customer_API SHALL return only whitelisted fields: project_name, customer_name, current_stage, start_date, expected_completion_date, project_type, and address
2. THE Customer_API SHALL scope the query to the projectId extracted from the Customer_JWT
3. THE Customer_API SHALL exclude internal fields including: remarks, supervisor_id, designer_id, created_by, quotation_amount, and is_archived

### Requirement 7: Customer Project Timeline

**User Story:** As a customer, I want to see a 13-stage timeline of my project so that I can understand how far along my project is.

#### Acceptance Criteria

1. WHEN an authenticated customer requests the project timeline, THE Customer_API SHALL return all stage history entries for the customer's project ordered chronologically
2. THE Customer_API SHALL include for each stage entry: stage name, status, and changed_at timestamp
3. THE Customer_API SHALL also return planned dates from project_stage_plans where available
4. THE Customer_API SHALL scope the query to the projectId from the Customer_JWT

### Requirement 8: Customer Project Photos

**User Story:** As a customer, I want to view photos from my project site so that I can see visual progress updates.

#### Acceptance Criteria

1. WHEN an authenticated customer requests project photos, THE Customer_API SHALL return files where category is 'photo' for the customer's project
2. THE Customer_API SHALL return for each photo: id, original_name, and created_at
3. THE Customer_API SHALL order photos by created_at descending (newest first)
4. THE Customer_API SHALL scope the query to the projectId from the Customer_JWT

### Requirement 9: Customer Approved Drawings

**User Story:** As a customer, I want to view only the approved drawings for my project so that I see only finalized design documents.

#### Acceptance Criteria

1. WHEN an authenticated customer requests project drawings, THE Customer_API SHALL return only files where category is 'drawing' AND approval_status is 'approved'
2. THE Customer_API SHALL exclude drawings with approval_status of 'pending' or 'revision_requested'
3. THE Customer_API SHALL return for each drawing: id, original_name, version_number, approved_at, and created_at
4. THE Customer_API SHALL scope the query to the projectId from the Customer_JWT

### Requirement 10: Customer Payment Summary

**User Story:** As a customer, I want to see a summary of my payment status so that I understand my financial standing without seeing internal transaction details.

#### Acceptance Criteria

1. WHEN an authenticated customer requests payment information, THE Customer_API SHALL return only summary totals: quotation_amount, total_received, and outstanding_balance
2. THE Customer_API SHALL calculate outstanding_balance as quotation_amount minus total_received
3. THE Customer_API SHALL NOT return individual payment transaction records, dates, or methods
4. THE Customer_API SHALL scope the query to the projectId from the Customer_JWT

### Requirement 11: Customer Notifications

**User Story:** As a customer, I want to receive and view notifications about my project so that I stay informed of important updates.

#### Acceptance Criteria

1. WHEN an authenticated customer requests notifications, THE Customer_API SHALL return entries from customer_notifications for the customer's project ordered by created_at descending
2. THE Customer_API SHALL return for each notification: id, title, body, is_read, and created_at
3. THE Customer_API SHALL scope the query to the projectId from the Customer_JWT
4. THE Customer_API SHALL NOT return staff notifications or activity_logs data to customers

### Requirement 12: Customer Messages (Admin Announcements)

**User Story:** As a customer, I want to see announcements posted by the admin so that I receive important communications about my project.

#### Acceptance Criteria

1. WHEN an authenticated customer requests messages, THE Customer_API SHALL return entries from customer_messages for the customer's project ordered by created_at descending
2. THE Customer_API SHALL return for each message: id, title, body, and created_at
3. THE Customer_API SHALL NOT expose the posted_by (admin user ID) field to the customer
4. THE Customer_API SHALL scope the query to the projectId from the Customer_JWT

### Requirement 13: Admin Post Customer Announcement

**User Story:** As an admin, I want to post announcements to a specific customer's portal so that I can communicate project updates directly.

#### Acceptance Criteria

1. WHEN an admin submits an announcement with title and body for a project, THE Customer_API SHALL insert a record into customer_messages with the project_id and posted_by set to the admin's user ID
2. THE Customer_API SHALL require admin role authentication (Staff_JWT with role 'admin') for posting announcements
3. THE Customer_API SHALL validate that title and body are non-empty strings before inserting

### Requirement 14: Admin PIN Reset

**User Story:** As an admin, I want to reset a customer's PIN so that a customer who has forgotten their PIN can set a new one.

#### Acceptance Criteria

1. WHEN an admin requests a PIN reset for a project, THE Customer_API SHALL set customer_pin_hash to NULL and customer_pin_set to false for that project
2. THE Customer_API SHALL require admin role authentication for PIN reset operations
3. WHEN a customer's PIN is reset, THE Customer_Auth_Service SHALL allow the customer to set a new PIN on their next login attempt

### Requirement 15: Customer Security Scoping

**User Story:** As a system administrator, I want all customer data queries to be scoped by projectId so that customers can never access data from other projects.

#### Acceptance Criteria

1. THE Customer_API SHALL include a WHERE project_id = $projectId clause in every database query, using the projectId from the verified Customer_JWT
2. THE Customer_API SHALL NOT use the serializeProject function used by staff endpoints
3. THE Customer_API SHALL NOT expose: internal notes, worker details, activity logs, staff list, or raw payment transactions
4. IF a customer attempts to access a resource outside their project scope, THEN THE Customer_API SHALL return a forbidden error

### Requirement 16: Customer Login Screen (Flutter)

**User Story:** As a customer, I want a dedicated login screen with mobile entry and PIN input so that I can access the portal with a premium, branded experience.

#### Acceptance Criteria

1. THE Customer_Portal SHALL present a mobile number input field on the CustomerLoginScreen
2. WHEN the customer enters a valid mobile number and a matching project is found, THE Customer_Portal SHALL display the customer's name and transition to the PIN input
3. WHEN the customer enters a valid mobile number and no project is found, THE Customer_Portal SHALL display an error message
4. THE Customer_Portal SHALL use the #00D1DC teal brand color throughout the customer interface
5. WHEN the mobile is found and customer_pin_set is false, THE Customer_Portal SHALL navigate to the CustomerSetPinScreen

### Requirement 17: Customer PIN Setup Screen (Flutter)

**User Story:** As a first-time customer, I want a custom numeric keypad to set my 4-digit PIN so that the setup feels secure and intentional.

#### Acceptance Criteria

1. THE Customer_Portal SHALL display a custom numeric keypad on the CustomerSetPinScreen
2. THE Customer_Portal SHALL require the customer to enter the PIN twice for confirmation
3. WHEN both PIN entries match and are exactly 4 digits, THE Customer_Portal SHALL submit the PIN to the set-pin endpoint
4. WHEN the PIN entries do not match, THE Customer_Portal SHALL display a mismatch error and clear the inputs

### Requirement 18: Customer Home Screen (Flutter)

**User Story:** As a customer, I want a home screen showing a progress hero card, latest photos, stage strip, payment summary, and messages so that I get a comprehensive overview in one place.

#### Acceptance Criteria

1. THE Customer_Portal SHALL display a hero progress card on the CustomerHomeScreen showing project name and current stage
2. THE Customer_Portal SHALL display the latest project photos in a horizontal scroll section
3. THE Customer_Portal SHALL display a horizontal stage strip showing the 13-stage progression
4. THE Customer_Portal SHALL display a payment summary section showing quotation amount, received, and outstanding
5. THE Customer_Portal SHALL display recent admin messages in a messages section

### Requirement 19: Customer Timeline Screen (Flutter)

**User Story:** As a customer, I want a vertical timeline showing all 13 project stages so that I can see completed, current, and upcoming stages.

#### Acceptance Criteria

1. THE Customer_Portal SHALL display a vertical timeline on the CustomerTimelineScreen with all 13 project stages
2. THE Customer_Portal SHALL visually distinguish completed stages, the current stage, and upcoming stages using distinct styling
3. THE Customer_Portal SHALL display the date each stage was reached for completed stages
4. THE Customer_Portal SHALL display planned dates for upcoming stages when available

### Requirement 20: Customer Shell Navigation (Flutter)

**User Story:** As a customer, I want bottom navigation with Home, Photos, Timeline, Payments, and Messages tabs so that I can easily navigate between portal sections.

#### Acceptance Criteria

1. THE Customer_Portal SHALL display a bottom navigation bar in the CustomerShell with five tabs: Home, Photos, Timeline, Payments, and Messages
2. THE Customer_Portal SHALL highlight the active tab using the #00D1DC teal brand color
3. THE Customer_Portal SHALL persist navigation state when switching between tabs

### Requirement 21: Customer Routing and Token Storage (Flutter)

**User Story:** As a developer, I want customer routes added to the router and a separate token storage key so that customer and staff sessions remain isolated in the app.

#### Acceptance Criteria

1. THE Customer_Portal SHALL store the customer access token using the key 'customer_access_token', separate from the staff 'access_token' key
2. THE Customer_Portal SHALL add customer routes as a new ShellRoute in app_router.dart without modifying existing staff routes
3. WHEN the Flutter web build has no customer token stored, THE Customer_Portal SHALL default to the /customer-login route
4. WHEN the Flutter Android build launches, THE Customer_Portal SHALL maintain the existing staff login flow as the default entry point

### Requirement 22: PWA Configuration and Deployment

**User Story:** As a customer, I want the web portal to work as a Progressive Web App so that I can add it to my home screen and use it like a native app.

#### Acceptance Criteria

1. THE Customer_Portal SHALL include a manifest.json configured for standalone display mode with the app name "Metal & More Interiors"
2. THE Customer_Portal SHALL include iOS meta tags enabling "Add to Home Screen" functionality
3. THE Customer_Portal SHALL include an .htaccess file configured for SPA routing on Hostinger hosting
4. THE Customer_Portal SHALL include a download.html landing page with a link to download the Android APK
5. THE Customer_Portal SHALL use the #00D1DC teal color as the theme color in the manifest

### Requirement 23: Rate Limiting for Customer Auth

**User Story:** As a system administrator, I want customer authentication endpoints rate-limited so that brute-force PIN attacks are mitigated.

#### Acceptance Criteria

1. THE Customer_Auth_Service SHALL apply rate limiting to the login endpoint allowing a maximum of 5 attempts per mobile number per 15-minute window
2. WHEN the rate limit is exceeded, THE Customer_Auth_Service SHALL return a 429 status with a retry-after indication
3. THE Customer_Auth_Service SHALL apply rate limiting to the check-mobile endpoint allowing a maximum of 10 attempts per IP per 15-minute window

