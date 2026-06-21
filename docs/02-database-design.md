# 02 — Database Design (PostgreSQL)

The authoritative schema is implemented in `backend/src/db/migrations/`. This document explains the model.

## 2.1 Conventions

- Primary keys: `uuid` (`gen_random_uuid()` via `pgcrypto`).
- Timestamps: `created_at`, `updated_at` (`timestamptz`, default `now()`), `updated_at` maintained by trigger.
- Soft delete only where business needs history; drawings are **hard deleted** (latest-only rule).
- Enumerations implemented as PostgreSQL `ENUM` types for integrity.

## 2.2 Enum Types

```sql
CREATE TYPE user_role     AS ENUM ('admin','supervisor','designer','worker');
CREATE TYPE user_status   AS ENUM ('pending','approved','rejected','disabled');
CREATE TYPE worker_status AS ENUM ('workshop','at_site','leave','holiday');
CREATE TYPE project_stage AS ENUM (
  'discussion','3d_design','drawing','material_purchase','cutting','making',
  'lamination','painting','packing','transport','installation','checking','completed'
);
CREATE TYPE file_category AS ENUM (
  'working_drawing','measurement_drawing','site_drawing','pdf_drawing',
  '3d_design','quotation','photo','video','voice_note'
);
CREATE TYPE report_type   AS ENUM ('worker','supervisor');
CREATE TYPE payment_kind  AS ENUM ('advance','second','third','final','other');
CREATE TYPE assignment_role AS ENUM ('supervisor','designer','worker');
```

## 2.3 Tables

### users
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| full_name | text NOT NULL | |
| email | citext UNIQUE NOT NULL | |
| phone | text NOT NULL | |
| password_hash | text NOT NULL | bcrypt |
| role | user_role NULL | null until admin assigns |
| status | user_status NOT NULL default 'pending' | |
| worker_status | worker_status default 'workshop' | only meaningful for workers |
| approved_by | uuid FK→users | |
| approved_at | timestamptz | |
| push_token | text | FCM token |
| created_at / updated_at | timestamptz | |

### projects
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| project_number | text UNIQUE NOT NULL | |
| customer_name | text NOT NULL | |
| phone | text NOT NULL | |
| alt_phone | text | |
| address | text | |
| site_location | text | |
| project_name | text NOT NULL | |
| project_type | text | |
| work_description | text | |
| start_date | date | |
| expected_completion_date | date | |
| quotation_amount | numeric(14,2) default 0 | |
| current_stage | project_stage default 'discussion' | |
| supervisor_id | uuid FK→users | |
| designer_id | uuid FK→users | |
| remarks | text | |
| is_archived | boolean default false | |
| created_by | uuid FK→users | |
| created_at / updated_at | timestamptz | |

### project_stage_history
Tracks when each stage was reached / completed (for progress + activity).
| id | uuid PK |
| project_id | uuid FK→projects ON DELETE CASCADE |
| stage | project_stage |
| status | text ('pending','in_progress','completed') |
| changed_by | uuid FK→users |
| note | text |
| changed_at | timestamptz |

### project_assignments
Workers (many-to-many), plus optional task label.
| id | uuid PK |
| project_id | uuid FK→projects ON DELETE CASCADE |
| user_id | uuid FK→users |
| role | assignment_role |
| task | text | e.g. "Kitchen Installation" |
| assigned_by | uuid FK→users |
| active | boolean default true |
| created_at | timestamptz |
UNIQUE(project_id, user_id, role)

### files
All binary artifacts. Latest-only enforced in app logic for drawings/3D/quotation.
| id | uuid PK |
| project_id | uuid FK→projects ON DELETE CASCADE |
| category | file_category |
| original_name | text |
| storage_key | text NOT NULL | path/key on disk/S3 |
| mime_type | text |
| size_bytes | bigint |
| uploaded_by | uuid FK→users |
| caption | text |
| created_at | timestamptz |

> **Latest-only rule:** for `working_drawing`, `measurement_drawing`, `site_drawing`, `pdf_drawing`, `3d_design`, `quotation`, uploading replaces the previous file of the same category for the project (old DB row + physical file deleted). Photos/videos/voice notes accumulate.

### daily_reports
| id | uuid PK |
| project_id | uuid FK→projects ON DELETE CASCADE |
| author_id | uuid FK→users |
| type | report_type |
| report_date | date NOT NULL |
| work_done | text |
| pending_work | text |
| problems | text |
| materials_needed | text |
| tomorrow_notes | text |
| site_progress | text | supervisor only |
| created_at | timestamptz |
UNIQUE(project_id, author_id, report_date, type)
Media linked via `files` with `report_id` (nullable FK added to files for report attachments).

### work_plans (tomorrow planning)
| id | uuid PK |
| project_id | uuid FK→projects |
| plan_date | date NOT NULL |
| task | text |
| created_by | uuid FK→users |
| created_at | timestamptz |

### work_plan_workers
| work_plan_id | uuid FK→work_plans ON DELETE CASCADE |
| user_id | uuid FK→users |
PK(work_plan_id, user_id)

### payments
One row per project holding the summary, plus history rows.
| id | uuid PK |
| project_id | uuid UNIQUE FK→projects ON DELETE CASCADE |
| quotation_amount | numeric(14,2) |
| total_received | numeric(14,2) default 0 | maintained from history |
| updated_at | timestamptz |
> `balance_amount` is derived: `quotation_amount - total_received`.

### payment_history
| id | uuid PK |
| project_id | uuid FK→projects ON DELETE CASCADE |
| kind | payment_kind |
| amount | numeric(14,2) NOT NULL |
| paid_on | date |
| method | text | cash / upi / bank |
| reference_number | text |
| remarks | text |
| recorded_by | uuid FK→users |
| created_at | timestamptz |
A trigger recomputes `payments.total_received` on insert/delete.

### notifications
| id | uuid PK |
| user_id | uuid FK→users | recipient |
| type | text | enum-like string (see API doc) |
| title | text |
| body | text |
| project_id | uuid FK→projects NULL |
| data | jsonb | deep-link payload |
| is_read | boolean default false |
| created_at | timestamptz |

### activity_logs
| id | uuid PK |
| user_id | uuid FK→users |
| project_id | uuid FK→projects NULL |
| action | text | e.g. 'project.create', 'drawing.replace' |
| entity_type | text |
| entity_id | uuid |
| description | text |
| metadata | jsonb |
| created_at | timestamptz |

### refresh_tokens
| id | uuid PK |
| user_id | uuid FK→users ON DELETE CASCADE |
| token_hash | text |
| expires_at | timestamptz |
| revoked | boolean default false |
| created_at | timestamptz |

## 2.4 Key Indexes
- `users(email)`, `users(status)`, `users(role)`
- `projects(current_stage)`, `projects(supervisor_id)`, `projects(designer_id)`
- `files(project_id, category)`
- `daily_reports(project_id, report_date)`, `daily_reports(author_id)`
- `notifications(user_id, is_read)`
- `activity_logs(project_id, created_at)`, `activity_logs(user_id, created_at)`
- `project_assignments(user_id, active)`

## 2.5 Derived / Dashboard Queries
- **Total/Active/Completed sites** — count of projects grouped by `current_stage = 'completed'`.
- **Workers today** — distinct workers in `work_plan_workers` for today + assignments with `worker_status='at_site'`.
- **Pending reports** — assigned workers without a `daily_report` for today.
- **Pending approvals** — `users.status = 'pending'`.
- **Pending payments / outstanding** — `SUM(quotation_amount - total_received)`.
- **Amount received** — `SUM(total_received)`.

## 2.6 Entity Relationship (text ERD)

```
users 1───* project_assignments *───1 projects
users 1───* projects (supervisor_id, designer_id, created_by)
projects 1───* files
projects 1───* daily_reports *───1 users
projects 1───1 payments 1───* payment_history
projects 1───* work_plans 1───* work_plan_workers *───1 users
projects 1───* project_stage_history
users/projects 1───* notifications
users/projects 1───* activity_logs
users 1───* refresh_tokens
```
