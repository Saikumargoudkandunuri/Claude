# 09 — UI / UX Wireframe Structure

**Design language:** Material 3, mobile-first, clean & professional. Light only.
**Colors:** Primary `#00D1DC`, Background `#FFFFFF`, Secondary background `#F8FAFC`, text `#0F172A`, muted `#64748B`, success `#16A34A`, warning `#F59E0B`, danger `#DC2626`. No black backgrounds, no dark dashboards.
**Type:** clear sans (e.g. Inter). Big tap targets (≥48dp) for workers. Generous spacing (8/12/16/24).

---

## 9.1 Component Inventory
- `StatCard` — number + label + small icon, white card with soft shadow on `#F8FAFC`.
- `StageChip` — colored pill for current stage.
- `PrimaryButton` / `OutlineButton` — 48dp height, 12 radius, primary `#00D1DC`.
- `AppTextField` — labeled, validation aware.
- `ProjectTile` — project no, name, customer, stage chip, progress bar.
- `DrawingTile` — file icon, name, category badge, download/offline icon.
- `ReportCard` — author, date, sections.
- `EmptyState` — illustration + message + action.
- `RoleScaffold` — Material 3 `NavigationBar`.

---

## 9.2 Admin Dashboard (wireframe)

```
┌─────────────────────────────────────────────┐
│  Good morning, Admin           🔔(3)   👤     │
├─────────────────────────────────────────────┤
│  ┌────────────┐ ┌────────────┐ ┌──────────┐  │
│  │ Total Sites│ │Active Sites│ │Completed │  │
│  │     42     │ │     18     │ │    24    │  │
│  └────────────┘ └────────────┘ └──────────┘  │
│  ┌────────────┐ ┌────────────┐ ┌──────────┐  │
│  │Workers Today│ │Pending Rpts│ │Approvals │  │
│  │     12     │ │     3      │ │    2     │  │
│  └────────────┘ └────────────┘ └──────────┘  │
│  ┌────────────────── Payments ─────────────┐  │
│  │ Received ₹ 18,40,000   Outstanding ₹ 6L │  │
│  └─────────────────────────────────────────┘  │
│  Recent Updates                               │
│  • Designer uploaded 3D — Ramesh Villa  2h    │
│  • Report submitted — Lake View         3h    │
│  • Payment received ₹2L — Sky Residency 5h    │
├─────────────────────────────────────────────┤
│  [ + New Project ]  (FAB)                     │
│  Dashboard  Projects  Approvals  Pay  🔔      │
└─────────────────────────────────────────────┘
```

## 9.3 New / Edit Project Form

Grouped sections, scrollable, sticky save button:
```
Customer
  Project Number*        Customer Name*
  Phone*                 Alternative Phone
  Address                Site Location
Project
  Project Name*          Project Type
  Work Description (multiline)
  Start Date             Expected Completion Date
Commercials
  Quotation Amount       Upload Quotation PDF [file]
Assignment
  Assign Supervisor ▼    Assign Designer ▼
  Remarks
            [ Cancel ]            [ Save Project ]
```

## 9.4 Project Detail (tabbed)

```
┌─────────────────────────────────────────────┐
│ ‹  Ramesh Villa            #PRJ-1042   ⋮      │
│ Customer: Ramesh   ·  📞 (admin/supervisor)   │
│ Stage:  [ Installation ]   ▓▓▓▓▓▓▓░░ 75%      │
├──[Details][Drawings][Media][Reports][Pay][Log]│
│  (tab content)                                │
└─────────────────────────────────────────────┘
```
- **Drawings tab:** sections Working / Measurement / Site / PDF / 3D. Each shows latest file with View · Download · (Designer/Admin) Replace · Delete.
- **Media tab:** grid of photos, video thumbnails, voice note players + upload FAB.
- **Reports tab:** filter by date; worker & supervisor cards.
- **Payments tab (admin):** summary header + history list + "Add Payment".
- **Log tab:** activity timeline.

## 9.5 Drawing / PDF Viewer

```
┌──────────────────── full screen ─────────────┐
│ ‹  working-drawing-kitchen.pdf      ⤓  ⛶      │
│                                               │
│            [ rendered PDF page ]              │
│        pinch-zoom · drag · rotate ⟳           │
│                                               │
│  ◀  page 2 / 6  ▶              offline ✓       │
└───────────────────────────────────────────────┘
```

## 9.6 Worker Home (simple, large)

```
┌─────────────────────────────────────────────┐
│  Hi Ravi 👋          Status: At Site ▼   🔔    │
├─────────────────────────────────────────────┤
│  TODAY'S WORK                                 │
│  ┌─────────────────────────────────────────┐ │
│  │ Ramesh Villa — Kitchen Installation     │ │
│  │ [ Open Drawings ]  [ Start ] [ Complete ]│ │
│  └─────────────────────────────────────────┘ │
│  ASSIGNED SITES                               │
│  • Lake View — Wardrobe Making                │
│  • Sky Residency — Lamination                 │
│                                               │
│  [ Submit End-of-Day Report ]                 │
├─────────────────────────────────────────────┤
│   Home        Reports        Notifications     │
└─────────────────────────────────────────────┘
```

## 9.7 End-of-Day Report (worker)

```
Today's Work Done   (multiline)
Pending Work        (multiline)
Problems            (multiline)
Materials Needed    (multiline)
Tomorrow Notes      (multiline)
Attach: 📷 Photos  🎥 Videos  🎙 Voice
                         [ Submit Report ]
```

## 9.8 Approvals (admin)

```
Pending Approvals
┌─────────────────────────────────────────────┐
│ Suresh K   suresh@..   +91 98xxxxxx           │
│ Assign role: (Supervisor)(Designer)(Worker)   │
│            [ Reject ]        [ Approve ]       │
└─────────────────────────────────────────────┘
```

## 9.9 Empty / Loading / Error
- Loading: centered primary spinner.
- Empty: friendly icon + line + primary action.
- Error: inline banner with retry; never a raw stack trace.

## 9.10 Accessibility & Field usability
- Min 48dp targets, high contrast text on white, large fonts for worker screens, offline indicators, optimistic UI for mark started/completed, confirm dialogs for destructive actions (delete drawing/project).
