# 06 — User Permissions Matrix

Four roles only: **Admin**, **Supervisor**, **Designer**, **Worker**.
✅ allowed · ➖ allowed but scoped (see notes) · ❌ not allowed

## 6.1 Capability Matrix

| Capability | Admin | Supervisor | Designer | Worker |
|------------|:-----:|:----------:|:--------:|:------:|
| Register account | ✅ | ✅ | ✅ | ✅ |
| Approve / reject users | ✅ | ❌ | ❌ | ❌ |
| Assign roles | ✅ | ❌ | ❌ | ❌ |
| Create another Admin | ✅ | ❌ | ❌ | ❌ |
| Create project | ✅ | ❌ | ❌ | ❌ |
| Edit project | ✅ | ❌ | ❌ | ❌ |
| Delete project | ✅ | ❌ | ❌ | ❌ |
| View all projects | ✅ | ✅ | ✅ | ❌ (assigned only) |
| Assign supervisor / designer | ✅ | ❌ | ❌ | ❌ |
| Assign workers | ✅ | ✅ | ❌ | ❌ |
| Tomorrow work planning | ✅ | ✅ | ❌ | ❌ |
| Upload working/measurement/site/pdf drawings | ✅ | ❌ | ✅ | ❌ |
| Upload 3D designs | ✅ | ❌ | ✅ | ❌ |
| Replace / delete drawings & 3D | ✅ | ❌ | ✅ | ❌ |
| Upload / replace / delete quotation | ✅ | ❌ | ✅ | ❌ |
| View / download drawings | ✅ | ✅ | ✅ | ✅ |
| Upload photos | ✅ | ✅ | ❌ | ✅ |
| Upload videos | ✅ | ✅ | ❌ | ✅ |
| Upload voice notes | ✅ | ✅ | ❌ | ✅ |
| Add site updates | ✅ | ✅ | ❌ | ➖ (via report) |
| Submit worker daily report | ➖ | ❌ | ❌ | ✅ |
| Submit supervisor daily report | ➖ | ✅ | ❌ | ❌ |
| Mark task started / completed | ✅ | ✅ | ❌ | ✅ (own task) |
| Control design stages (Discussion, 3D, Drawing) | ✅ | ❌ | ✅ | ❌ |
| Control execution stages (Material→Completed) | ✅ | ✅ | ❌ | ❌ |
| Override any stage | ✅ | ❌ | ❌ | ❌ |
| View payments | ✅ | ❌ | ❌ | ❌ |
| Manage payments | ✅ | ❌ | ❌ | ❌ |
| Manage quotations (financial) | ✅ | ❌ | ➖ (file only) | ❌ |
| Send / manage notifications | ✅ | ➖ (triggers) | ➖ (triggers) | ❌ |
| View reports | ✅ | ✅ | ➖ (design-related) | ➖ (own + supervisor) |
| View activity history | ✅ (all) | ➖ (project) | ➖ (project) | ❌ |
| View admin contact | ✅ | ✅ | ✅ | ✅ |
| View supervisor contact | ✅ | ✅ | ✅ | ✅ |
| View worker/designer contacts | ✅ | ✅ | ➖ | ❌ |

## 6.2 Stage Control by Role

| Stage | Designer | Supervisor | Admin |
|-------|:--------:|:----------:|:-----:|
| Discussion | ✅ | ❌ | ✅ |
| 3D Design | ✅ | ❌ | ✅ |
| Drawing | ✅ | ❌ | ✅ |
| Material Purchase | ❌ | ✅ | ✅ |
| Cutting | ❌ | ✅ | ✅ |
| Making | ❌ | ✅ | ✅ |
| Lamination | ❌ | ✅ | ✅ |
| Painting | ❌ | ✅ | ✅ |
| Packing | ❌ | ✅ | ✅ |
| Transport | ❌ | ✅ | ✅ |
| Installation | ❌ | ✅ | ✅ |
| Checking | ❌ | ✅ | ✅ |
| Completed | ❌ | ✅ | ✅ |

## 6.3 Employee Privacy Rules (enforced in API serializers)

**Workers MUST NOT see:** other workers' phone/email, designers' phone/email or personal details.
**Workers CAN see:** Admin name + phone, Supervisor name + phone (of their project).
**No employee directory endpoint exists.** `/users` is Admin-only. Contact info is exposed only through a project's `contacts` object that contains just `{adminName, adminPhone, supervisorName, supervisorPhone}` when requested by a worker.

## 6.4 Backend Permission Keys

Used by `requirePermission(...)`:
```
users:approve, users:assign-role, users:read
projects:create, projects:update, projects:delete, projects:read-all
stages:design, stages:execution, stages:override
assignments:workers, workplans:write
drawings:upload, drawings:delete            (admin, designer)
media:upload                                (admin, supervisor, worker)
reports:worker, reports:supervisor
payments:read, payments:write               (admin)
activity:read-all, activity:read-project
```
The mapping role→keys lives in `backend/src/middleware/rbac.js` and is mirrored in the Flutter `core/permissions/permissions.dart`.
