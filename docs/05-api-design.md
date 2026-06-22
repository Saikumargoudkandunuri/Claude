# 05 — API Design (REST)

Base URL: `/api/v1`. All responses JSON. Auth via `Authorization: Bearer <accessToken>`.
Success envelope: `{ "data": ... }`. Error envelope: `{ "error": { "code", "message", "details"? } }`.

Legend for access: **A**=Admin, **S**=Supervisor, **D**=Designer, **W**=Worker, **Pub**=public.

## 5.1 Auth
| Method | Path | Access | Body / Notes |
|--------|------|--------|--------------|
| POST | `/auth/register` | Pub | `{fullName,email,phone,password}` → status `pending` |
| POST | `/auth/login` | Pub | `{email,password}` → `{accessToken,refreshToken,user}` |
| POST | `/auth/refresh` | Pub | `{refreshToken}` → new tokens |
| POST | `/auth/logout` | any | `{refreshToken}` |
| GET | `/auth/me` | any | current user |
| PUT | `/auth/me/push-token` | any | `{pushToken}` |
| PUT | `/auth/me/worker-status` | W,S,A | `{status}` workshop/at_site/leave/holiday |

## 5.2 Users (Admin)
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/users` | A | filter `?status=&role=&q=` |
| GET | `/users/pending` | A | pending approvals |
| POST | `/users/:id/approve` | A | `{role}` assign role + approve |
| POST | `/users/:id/reject` | A | |
| PUT | `/users/:id/role` | A | reassign role |
| PUT | `/users/:id/disable` | A | |
| GET | `/users/assignable?role=` | A,S | supervisors/designers/workers for assignment pickers |

> Only an Admin can set role=`admin`.

## 5.3 Projects
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/projects` | A,S,D (all) / W (assigned only) | `?stage=&q=&assigned=me` |
| POST | `/projects` | A | create (full form) |
| GET | `/projects/:id` | role-scoped | worker only if assigned |
| PUT | `/projects/:id` | A | edit |
| DELETE | `/projects/:id` | A | |
| GET | `/projects/:id/stages` | role-scoped | stage history |
| PUT | `/projects/:id/stage` | A (any) / S (exec stages) / D (design stages) | `{stage,status,note}` |
| GET | `/projects/:id/assignments` | role-scoped | |
| POST | `/projects/:id/assignments` | A,S | `{userId,role,task}` assign worker/designer/supervisor |
| DELETE | `/projects/:id/assignments/:assignmentId` | A,S | |

## 5.4 Files / Drawings
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/projects/:id/files?category=` | role-scoped | list (drawings, 3d, media...) |
| POST | `/projects/:id/files` | upload rules below | multipart `file`, `category`, `caption?` |
| DELETE | `/files/:fileId` | A,D (drawings/3d/quotation); uploader for media | hard delete + remove file |
| GET | `/files/:fileId/download` | role-scoped | streams file (supports Range for video) |
| GET | `/files/:fileId/meta` | role-scoped | metadata for offline cache |

**Upload permission by category**
- `working_drawing, measurement_drawing, site_drawing, pdf_drawing, 3d_design, quotation` → **Admin, Designer** (latest-only: replaces previous of same category).
- `photo, video, voice_note` → **Admin, Supervisor, Worker** (accumulate).

## 5.5 Daily Reports
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/projects/:id/reports?date=&type=` | role-scoped | W sees own + supervisor's |
| POST | `/projects/:id/reports` | W (worker type), S (supervisor type) | EOD report fields |
| GET | `/reports/today/me` | W,S | my report status for today |
| POST | `/reports/:id/media` | author | attach photo/video/voice |

## 5.6 Work Plans (Tomorrow Planning)
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/projects/:id/workplans?date=` | role-scoped | |
| POST | `/projects/:id/workplans` | A,S | `{planDate,task,workerIds[]}` → notifies workers + supervisor |
| GET | `/workplans/me?date=` | W,S | my plan for a date (today/tomorrow) |
| DELETE | `/workplans/:id` | A,S | |

## 5.7 Payments (Admin only)
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/projects/:id/payments` | A | summary + history |
| PUT | `/projects/:id/payments` | A | `{quotationAmount}` |
| POST | `/projects/:id/payments/history` | A | `{kind,amount,paidOn,method,referenceNumber,remarks}` |
| DELETE | `/payments/history/:id` | A | recompute totals |

## 5.8 Notifications
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/notifications?unread=true` | any | own notifications |
| GET | `/notifications/unread-count` | any | badge |
| POST | `/notifications/:id/read` | owner | |
| POST | `/notifications/read-all` | any | |

**Notification types:** `project.created, drawing.uploaded, drawing.replaced, design3d.uploaded, worker.assigned, workplan.assigned, work.completed, photo.uploaded, video.uploaded, report.submitted, user.registration, payment.updated`.

## 5.9 Activity History
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/activity?projectId=&userId=&from=&to=` | A (all), S/D (project-scoped) | paginated |
| GET | `/projects/:id/activity` | role-scoped | project timeline |

## 5.10 Dashboard
| Method | Path | Access | Returns |
|--------|------|--------|---------|
| GET | `/dashboard/admin` | A | totalSites, activeSites, completedSites, workersToday, pendingReports, pendingApprovals, pendingPayments, amountReceived, outstandingAmount, recentUpdates[] |
| GET | `/dashboard/supervisor` | S | mySites, todaysWork, pendingReports, recentUpdates |
| GET | `/dashboard/designer` | D | sites needing design, recent uploads |
| GET | `/dashboard/worker` | W | assignedSites, todaysWork, reportDueToday, recentDrawings |

## 5.11 Health
| GET `/health` | Pub | liveness |
| GET `/health/db` | Pub | DB connectivity |

## 5.12 Pagination & Filtering
List endpoints accept `?page=1&limit=20`; respond with `{ data: [...], meta: { page, limit, total } }`.

## 5.13 Status codes
`200` ok · `201` created · `204` no content · `400` bad request · `401` unauthenticated · `403` forbidden · `404` not found · `409` conflict (duplicate) · `422` validation · `429` rate limited · `500` server error.


---

## 5.14 ERP Enhancements (v1.1)

### Daily Reports (enriched)
- Report bodies now also accept: `progressPercent` (0–100), `materialsUsed`, plus existing `workDone, pendingWork, problems` (issues faced), `materialsNeeded`, `tomorrowNotes`, `siteProgress`.
- Report responses include `progressPercent`, `materialsUsed`, `authorRole`, `projectName`, and a `media[]` array (each `{id, category, originalName, mimeType, sizeBytes, downloadUrl}`).
- `POST /reports/:id/media` (existing) attaches photo/video/voice_note files to a report.

| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/reports` | A (all), S (own projects) | All reports across projects. `?date=&type=&projectId=&page=&limit=` |

### Worker Tasks (work plans + status)
`work_plan_workers` now tracks per-worker `status` (`assigned`→`started`→`completed`) with `started_at`/`completed_at`.

| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/workplans?date=` | A, S | Task panel for a date (S scoped to own projects). Each plan includes `workers[]` with `status`. |
| PUT | `/workplans/:id/status` | W (own), A | `{status}` mark started/completed; completion notifies supervisor + admins |
| GET | `/workplans/me?date=` | W, S | now includes `status, startedAt, completedAt` |

### Payments (full CRUD)
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| PUT | `/payments/history/:id` | A | edit a payment entry (recomputes totals) |
| POST | `/projects/:id/payments/clear` | A | record a final payment equal to the remaining balance |

### Project Timeline
| Method | Path | Access | Notes |
|--------|------|--------|-------|
| GET | `/projects/:id/timeline` | role-scoped | full history (creation → completion), ascending, with `date/day/time/userName/action/description` |

### Notifications
- Stage changes now notify admins, the supervisor, the designer and all assigned workers (`type: 'project.stage'`).

### Dashboard
- `GET /dashboard/admin` adds `stageDistribution` (map of stage→count) for the graph and `projects[]` summary cards (`{id, projectNumber, projectName, customerName, currentStage, quotationAmount, totalReceived}`).
- `GET /dashboard/worker` adds `tomorrowWork[]` and includes task `status/startedAt/completedAt` in `todaysWork[]`.
