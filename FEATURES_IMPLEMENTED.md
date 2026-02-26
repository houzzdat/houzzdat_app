# SiteVoice Enhancement — Features Implemented

> **Date:** 25 February 2026
> **Platform:** Flutter + Supabase
> **Session scope:** 3 new features — DB schema, Dart models, services, UI, and edge functions

---

## Table of Contents

1. [Feature 1 — Goal-Oriented Milestone System](#feature-1--goal-oriented-milestone-system)
2. [Feature 2 — Role-Based Quality Checklists](#feature-2--role-based-quality-checklists)
3. [Feature 3 — Document Management Vault](#feature-3--document-management-vault)
4. [Database Migration](#database-migration)
5. [Edge Functions](#edge-functions)
6. [Modified Existing Files](#modified-existing-files)
7. [Deployment Checklist](#deployment-checklist)
8. [File Index](#file-index)

---

## Feature 1 — Goal-Oriented Milestone System

### What It Does
A 3-tier project planning hierarchy (Objective → Phase → Key Result) with AI-generated plans, strategic dashboard metrics, and progress tracking — tailored to Indian construction contexts.

### User Flow

1. **Manager opens Insights screen → MILESTONES tab**
2. If no plan exists, an empty state with a "Setup Milestones" button is shown
3. Tapping it opens the **3-step wizard** (`MilestoneSetupScreen`):
   - **Q1 — Starting point:** Where is the project now? (4 card options: Site Ready / Foundation Done / Structure Up / Finishing Stage)
   - **Q2 — Work types:** Multi-select chip grid of construction disciplines (Structural, MEP, Finishing, Legal, etc.)
   - **Q3 — Constraints:** Target completion date picker + freetext constraints + Indian context hints (monsoon season, IS codes, local suppliers)
4. Submitting calls the **`generate-milestone-plan` edge function** (Groq `llama-3.3-70b-versatile`)
5. AI returns a JSON plan → phases + key results are inserted into the database
6. The MILESTONES tab refreshes to show the full dashboard

### Dashboard Layout

```
┌──────────────────────────────────┐
│  Project selector dropdown        │
├────────────┬────────────┬─────────┤  2×2 metric grid
│  RUNWAY    │  BLOCKERS  │
│  14 days   │  2 items   │
├────────────┼────────────┤
│  VALUE     │  FORECAST  │
│  65%       │  72%       │
└──────────────────────────────────┘
│  Phase cards (expandable list)   │
└──────────────────────────────────┘
```

### 4 Strategic Metrics

| Metric | What It Shows | Colour Zones |
|---|---|---|
| **RUNWAY** | Days until next phase deadline | Green >14d / Amber 7–14d / Red <7d |
| **CRITICAL BLOCKERS** | Count of overdue/stalled phases | Green 0 / Amber 1 / Red 2+ |
| **VALUE DELIVERED** | Weighted % of completed KRs | Green ≥70% / Amber ≥30% / Red <30% |
| **FORECAST CONFIDENCE** | AI-derived plan quality score | Green ≥75% / Amber ≥50% / Red <50% |

### Phase Cards

Each expandable `PhaseCardWidget` shows:
- Status chip (PENDING / ACTIVE / COMPLETED / BLOCKED)
- Planned date range + days remaining
- Budget burn % bar
- Expandable list of **Key Results** with individual progress bars and update dialogs
- Gate action button: "Start Gate Checklist" (pre-start) or "Complete Phase Gate" (post-completion)

### Indian Construction Context

The AI prompt includes:
- 25 module templates (Foundation, Plinth Beam, Slab, Waterproofing, MEP Rough-In, etc.)
- Monsoon buffer rules (June–September = +20% duration)
- IS code references per phase
- Festival break awareness (Diwali, Dussehra, Holi)
- Local material lead time hints (AAC blocks, TMT steel, etc.)

### New Files

| File | Purpose |
|---|---|
| `lib/models/milestone_phase.dart` | `MilestonePhase`, `KeyResult`, `DailyDelta`, `PhaseHealthMetrics` models |
| `lib/models/milestone_module.dart` | `MilestoneModule`, `ModuleCategory`, `IndianConstructionContext` models |
| `lib/features/milestones/services/milestone_service.dart` | CRUD for phases, health metrics, AI plan generation |
| `lib/features/milestones/widgets/milestone_tab_content.dart` | Embedded tab widget for Insights screen |
| `lib/features/milestones/widgets/runway_metric_card.dart` | 4 strategic KPI cards with colour zones |
| `lib/features/milestones/widgets/phase_card_widget.dart` | Expandable phase card with gate actions |
| `lib/features/milestones/widgets/key_result_tile.dart` | KR progress tile + update dialog |
| `lib/features/milestones/screens/milestone_setup_screen.dart` | 3-step AI plan wizard |
| `supabase/functions/generate-milestone-plan/index.ts` | Groq-powered edge function |

---

## Feature 2 — Role-Based Quality Checklists

### What It Does
Pre-start and post-completion **phase gate checklists** with per-role item grouping, critical item blocking, and multi-type evidence capture. Guards phase transitions.

### User Flow

1. Manager/Owner taps gate button on a Phase Card
2. **`GateChecklistSheet`** modal slides up (88% screen height)
3. Items are grouped by role: MANAGER / WORKER / OWNER sections
4. Each item shows:
   - Checkbox (tap to toggle completion)
   - Critical badge (🔴) for blocking items
   - Evidence capture widget (camera / document / voice)
5. **Submit is disabled** until all critical items are checked
6. On submit → phase status transitions:
   - Pre-start gate → phase becomes `active`
   - Post-completion gate → phase becomes `completed`

### Evidence Types

| Type | Mechanism | Storage |
|---|---|---|
| **Photo** | `image_picker` — camera or gallery choice modal | `checklist-evidence` bucket |
| **Document** | `file_picker` — PDF, JPG, PNG | `checklist-evidence` bucket |
| **Voice** | Placeholder (microphone icon) — future integration with existing voice notes | — |

After upload, the evidence widget shows a thumbnail/file name. Tapping it opens a preview dialog.

### Gate Types

- `pre_start` — Must be completed before work begins (unlocks `active` status)
- `post_completion` — Must be completed before phase is marked done (unlocks `completed` status)

### Checklist Templates

Templates are stored in the `milestone_checklists` table (seeded for key modules like Foundation, Slab, Waterproofing). Each item has:
- Text in English / Hindi / Kannada
- Role assignment (`manager` / `worker` / `owner`)
- `is_critical` flag
- `evidence_required` type (`none` / `photo` / `document` / `voice`)

### New Files

| File | Purpose |
|---|---|
| `lib/models/checklist_item.dart` | `ChecklistItem`, `ChecklistCompletion`, `PhaseGateApproval`, `ChecklistItemWithCompletion` |
| `lib/features/milestones/services/checklist_service.dart` | Template loading, toggle completion, evidence upload, gate submit |
| `lib/features/milestones/widgets/gate_checklist_sheet.dart` | Modal checklist bottom sheet |
| `lib/features/milestones/widgets/evidence_capture_widget.dart` | Photo/doc/voice evidence capture widget |

---

## Feature 3 — Document Management Vault

### What It Does
A centralised document repository with automatic version control, owner approval workflow, expiry tracking, category filtering, and a full audit trail.

### Where It Lives

- **Manager Dashboard** → bottom nav "Docs" tab (index 5) — full document vault
- **Owner Dashboard** → Approvals screen → DOCUMENTS sub-tab — pending approvals only

### User Flow — Upload

1. Manager taps FAB (+) in Documents screen
2. `UploadDocumentSheet` modal opens
3. User picks file (PDF/JPG/PNG/DWG, max 50 MB via `file_picker`)
4. Auto-fills document name from filename
5. Selects **category** (dropdown: Drawings, Contracts, Permits, Reports, Safety, Other)
6. Selects **subcategory** (e.g. Architectural / Structural / MEP for Drawings)
7. Optionally sets **expiry date** (date picker)
8. Toggles **Requires Owner Approval** switch
9. If a document with the same name exists → shows "This will create v{n+1}" warning
10. Taps Upload → `DocumentService.uploadDocument()` runs:
    - File uploaded to `construction-documents` Supabase Storage bucket
    - DB record inserted with `version_number` auto-incremented
    - `process-document-upload` edge function called → logs audit + notifies owners

### User Flow — Approval

1. Owner opens Approvals screen → DOCUMENTS tab
2. Sees list of `DocumentCard` tiles with "PENDING APPROVAL" badge
3. Taps a card → navigates to `DocumentDetailScreen`
4. Owner-only approval card shows at top (visible only when role=owner + status=pending_approval)
5. Tapping "Review & Approve" opens `DocumentApprovalDialog`
6. Owner picks action: **Approve** / **Request Changes** / **Reject**
7. Comment required for Reject and Request Changes
8. Document status updates in real-time

### Document States

```
draft → pending_approval → approved
                        → rejected
                        → changes_requested → pending_approval (re-submit)
```

### Document Categories

| Category | Subcategories |
|---|---|
| Drawings | Architectural, Structural, MEP, Landscape, Interior |
| Contracts | Main Contract, Sub-contract, Vendor Agreement, LOI, PO |
| Permits | Building Permit, NOC, Environmental, Fire, Occupancy |
| Reports | Soil Test, Structural Audit, Quality Inspection, Progress |
| Safety | Method Statement, Risk Assessment, Safety Plan, Incident |
| Other | — |

### Version Control

- Versions are linked via `parent_document_id` chain in the `documents` table
- `version_number` auto-increments (service queries existing docs with same name+project)
- Version history shown as a timeline in `DocumentDetailScreen → DETAILS tab`
- Version badge (v2+) shown on `DocumentCard`

### Expiry Tracking

- Optional `expires_at` date stored per document
- `DocumentCard` shows amber "Expires in Xd" warning or red "Expired" badge
- Daily cron (`check-document-expiry` edge function) notifies managers 30/14/7 days before expiry
- `expiry_notified` flag prevents duplicate notifications

### Audit Trail

Every view, download, and upload is logged to `document_access_log`:
- `user_id`, `action` (`view` / `download` / `upload`), `metadata` (version, category)

### New Files

| File | Purpose |
|---|---|
| `lib/models/document.dart` | `Document`, `DocumentCategory`, `DocumentApprovalStatus`, `DocumentComment`, `DocumentAccessLog` models |
| `lib/features/documents/services/document_service.dart` | Upload, versioning, approval workflow, comments, audit |
| `lib/features/documents/screens/documents_screen.dart` | `DocumentsTabBody` — full vault with category tabs, search, filter |
| `lib/features/documents/screens/document_detail_screen.dart` | Detail view with DETAILS / COMMENTS tabs, version history, approval card |
| `lib/features/documents/widgets/document_card.dart` | List tile with category icon, version badge, status badge, expiry warning |
| `lib/features/documents/widgets/upload_document_sheet.dart` | File upload modal with version detection |
| `lib/features/documents/widgets/document_approval_dialog.dart` | 3-action approval dialog (Approve/Request Changes/Reject) |

---

## Database Migration

**File:** `supabase/Migrations/20260225_milestone_checklist_documents.sql`

### New Tables (10)

| Table | Description |
|---|---|
| `milestone_modules` | Global + account-specific phase templates (25 seeded) |
| `milestone_phases` | Project phase instances (from modules or custom) |
| `key_results` | OKR-style measurable outcomes per phase |
| `daily_deltas` | Daily KR value change log for trend analysis |
| `milestone_checklists` | Checklist item templates per module + gate type |
| `checklist_completions` | Per-user item completion records with evidence URL |
| `phase_gate_approvals` | Gate submission records with status history |
| `documents` | Document vault — all metadata + versioning |
| `document_access_log` | Audit trail for view/download/upload actions |
| `document_comments` | Comment thread per document |

### RLS Policies

All tables have Row Level Security enabled:
- Users can only read/write records belonging to accounts they are members of
- `account_members` join used for all policy checks
- `document_access_log` is insert-only for the authenticated user (no cross-user reads)

### Seed Data

- **25 construction module templates** (Foundation → Handover) with Indian context JSON
- **Checklist items** seeded for key modules: Foundation, Slab, Roof Waterproofing
- All seed data has `account_id = NULL` (global templates)

---

## Edge Functions

### `generate-milestone-plan`

**Trigger:** Called by `MilestoneService.generateMilestonePlan()` from the setup wizard.

**Flow:**
1. Receives `{ project_id, account_id, q1, q2, q3, language }`
2. Builds a construction-domain system prompt with all 25 module templates + Indian context rules
3. Calls Groq API (`llama-3.3-70b-versatile`) with `response_format: { type: 'json_object' }`
4. Parses JSON response → fuzzy-matches phase names to `milestone_modules` IDs from DB
5. Bulk-inserts `milestone_phases` + `key_results` records
6. Returns `{ phases_created, key_results_created }`

**Env vars required:** `GROQ_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

---

### `process-document-upload`

**Trigger:** Called by `DocumentService.uploadDocument()` immediately after upload.

**Flow:**
1. Receives `{ document_id }`
2. Fetches document record (with project name join)
3. Inserts `document_access_log` record (`action: 'upload'`)
4. If `requires_owner_approval = true` → queries all `account_members` with `role = 'owner'` → inserts notifications (`type: 'document_pending_approval'`)
5. If `version_number > 1` and original uploader ≠ current uploader → notifies original uploader (`type: 'document_versioned'`)
6. Returns `{ success, owner_notifications_sent }`

**Env vars required:** `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

---

### `check-document-expiry`

**Trigger:** Daily cron (1:30 AM UTC = 7:00 AM IST via pg_cron).

**Flow:**
1. Queries documents where `expires_at <= today+30 AND expiry_notified = false AND approval_status != 'rejected'`
2. For each document, calculates `days_until_expiry`
3. Notifies all `manager` + `admin` role users in the account with urgency-aware title:
   - `<= 0 days` → "Document Expired"
   - `<= 7 days` → "Document Expiring Soon" (high urgency)
   - `<= 30 days` → "Document Expiring Soon" (advisory)
4. Sets `expiry_notified = true` on each processed document (prevents duplicate alerts)
5. Returns `{ processed, notifications_created, documents_marked }`

**Env vars required:** `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

---

## Modified Existing Files

| File | Change |
|---|---|
| `lib/models/models.dart` | Added 4 export lines for new model files |
| `lib/features/insights/screens/insights_screen.dart` | `TabController length: 4 → 5`, added MILESTONES tab + `MilestoneTabContent` to both `InsightsTabBody` and `InsightsScreen` classes |
| `lib/features/dashboard/screens/manager_dashboard_classic.dart` | Added Documents import + `DocumentsTabBody` as tab index 5 |
| `lib/features/dashboard/widgets/custom_bottom_nav.dart` | Added Documents nav item (index 5, `LucideIcons.folderOpen`, label 'Docs'), reduced padding to fit 6 items |
| `lib/features/owner/tabs/owner_approvals_tab.dart` | Added SPENDING / DOCUMENTS sub-tabs; original content moved to `_buildSpendingTab()`; new `_buildDocumentsTab()` shows pending document approvals |

---

## Deployment Checklist

Complete these steps in order before going live:

- [ ] **1. Apply migration** — run `20260225_milestone_checklist_documents.sql` in Supabase SQL editor
- [ ] **2. Create storage buckets** (Supabase Dashboard → Storage):
  - `construction-documents` — Private
  - `checklist-evidence` — Private
  - Add RLS storage policies: authenticated reads for project members, authenticated uploads for managers/admins
- [ ] **3. Deploy edge functions** (Supabase CLI):
  ```bash
  supabase functions deploy generate-milestone-plan
  supabase functions deploy process-document-upload
  supabase functions deploy check-document-expiry
  ```
- [ ] **4. Set edge function secrets**:
  ```bash
  supabase secrets set GROQ_API_KEY=<your-groq-api-key>
  ```
- [ ] **5. Enable pg_cron** — Supabase Dashboard → Database → Extensions → enable `pg_cron`
- [ ] **6. Schedule expiry cron** — Run the `cron.schedule(...)` block from the migration comment, or configure via Dashboard → Database → Cron Jobs
- [ ] **7. Add `image_picker` + `file_picker` to `pubspec.yaml`** if not already present:
  ```yaml
  image_picker: ^1.0.0
  file_picker: ^6.0.0
  ```
- [ ] **8. Test end-to-end** — Milestone setup wizard → gate checklist → document upload → owner approval

---

## File Index

### New Dart Files (21)

```
lib/
├── models/
│   ├── milestone_phase.dart
│   ├── milestone_module.dart
│   ├── checklist_item.dart
│   └── document.dart
└── features/
    ├── milestones/
    │   ├── services/
    │   │   ├── milestone_service.dart
    │   │   └── checklist_service.dart
    │   ├── widgets/
    │   │   ├── milestone_tab_content.dart
    │   │   ├── runway_metric_card.dart
    │   │   ├── phase_card_widget.dart
    │   │   ├── key_result_tile.dart
    │   │   ├── gate_checklist_sheet.dart
    │   │   └── evidence_capture_widget.dart
    │   └── screens/
    │       └── milestone_setup_screen.dart
    └── documents/
        ├── services/
        │   └── document_service.dart
        ├── widgets/
        │   ├── document_card.dart
        │   ├── upload_document_sheet.dart
        │   └── document_approval_dialog.dart
        └── screens/
            ├── documents_screen.dart
            └── document_detail_screen.dart
```

### New Supabase Files (7)

```
supabase/
├── Migrations/
│   └── 20260225_milestone_checklist_documents.sql
└── Functions/
    ├── generate-milestone-plan/
    │   ├── index.ts
    │   └── deno.json
    ├── process-document-upload/
    │   ├── index.ts
    │   └── deno.json
    └── check-document-expiry/
        ├── index.ts
        └── deno.json
```

### Modified Files (5)

```
lib/models/models.dart
lib/features/insights/screens/insights_screen.dart
lib/features/dashboard/screens/manager_dashboard_classic.dart
lib/features/dashboard/widgets/custom_bottom_nav.dart
lib/features/owner/tabs/owner_approvals_tab.dart
```
