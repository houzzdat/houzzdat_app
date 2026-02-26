# SiteVoice (Houzzapp) — Product Release Document V2

**Version:** 2.0
**Platform:** Flutter (Android, iOS, PWA)
**Backend:** Supabase (PostgreSQL, Auth, Edge Functions, Storage, Realtime)
**Release Date:** February 2026
**Supersedes:** PRODUCT_RELEASE_DOCUMENT.md (V1.0)

---

## Table of Contents

1. [What's New in V2](#1-whats-new-in-v2)
2. [Product Overview](#2-product-overview)
3. [Getting Started](#3-getting-started)
4. [User Roles & Permissions](#4-user-roles--permissions)
5. [Worker Features](#5-worker-features)
6. [Manager / Admin Features](#6-manager--admin-features)
7. [Owner Features](#7-owner-features)
8. [Super Admin Features](#8-super-admin-features)
9. [Voice Notes & AI Pipeline](#9-voice-notes--ai-pipeline)
10. [Project Planning Module](#10-project-planning-module)
11. [Finance Module](#11-finance-module)
12. [AI Report Generation](#12-ai-report-generation)
13. [Attendance & Geofencing](#13-attendance--geofencing)
14. [Agent Orchestration System](#14-agent-orchestration-system)
15. [Security & Data Isolation](#15-security--data-isolation)
16. [Multi-Company Support](#16-multi-company-support)
17. [Real-Time Features](#17-real-time-features)
18. [Supported Languages](#18-supported-languages)
19. [Technical Architecture](#19-technical-architecture)

---

## 1. What's New in V2

V2 is a major milestone release that expands SiteVoice from a voice-capture-and-routing tool into a full construction project management platform. The following capabilities are new or significantly enhanced since V1.0.

### New Features

| Feature | Description |
|---------|-------------|
| **Project Planning Module** | Milestone tracking, project plans, Bill of Quantities (BOQ), and project budgets now live within the platform |
| **Agent Orchestration System** | A dedicated Next.js/TypeScript server (`sitevoice-agents`) coordinates multi-step AI workflows, enabling complex processing chains beyond single edge function calls |
| **Sarvam AI Provider** | Native Indian language transcription via Sarvam's ASR API — highest accuracy for Indic scripts and regional dialects |
| **Hybrid Capture & Dedup** | Workers can use quick-tags to declare intent before recording, reducing AI ambiguity and duplicate action-item creation |
| **Structured Voice Note Data** | Voice notes now materialise into normalised sub-tables: `voice_note_approvals`, `voice_note_labor_requests`, `voice_note_material_requests`, `voice_note_project_events` — enabling precise querying and reporting |
| **Voice Note Forwarding** | Managers can forward a voice note to another team member directly from the action card |
| **Voice Note Edit History** | Full audit trail of transcript edits: who changed what, when, and what the original text was |
| **Project Health Score** | Configurable health score weights per account let managers tune how the system calculates a project's overall health |
| **Custom Roles** | Companies can define their own role labels beyond the defaults, stored in the new `roles` table |
| **User Management Audit Log** | Every invite, deactivation, role change, and removal is recorded in `user_management_audit_log` for compliance |
| **Eval Infrastructure** | Built-in AI evaluation harness (`eval_test_cases`, `eval_runs`, `eval_run_results`) for continuous quality measurement of the transcription and classification pipeline |
| **Full RLS Overhaul** | All 30+ database tables now have explicit, role-aware Row Level Security policies with named helper functions — hardening multi-tenant data isolation |
| **Critical Notification Type** | A dedicated `critical` push notification type triggers immediate delivery and distinct UI treatment for safety events |
| **Report Shared Notification** | Owners receive an in-app notification the moment a manager sends them a progress report |
| **Validation Gate** | A proof-of-work gate is enforced on action items before they can move to `verifying` status |

### Key Improvements

| Area | Change |
|------|--------|
| **AI Classification** | Enhanced classification pipeline with more granular confidence scoring and category-specific thresholds |
| **Attendance** | Database indexes added for date-range queries — significant speed improvement on large attendance datasets |
| **Voice Note Status** | Converted to a PostgreSQL enum type for database-level integrity |
| **Action Item Status** | Consistent enum values with migration to fix any legacy inconsistencies |
| **Transcription Trigger** | Voice note transcription now fires via a reliable database webhook trigger rather than client-side calls |
| **Project ID propagation** | `project_id` added directly to `voice_note_approvals`, `voice_note_labor_requests`, `voice_note_material_requests`, and `voice_note_project_events` — simplifying project-scoped queries |
| **Schema cleanup** | Removed redundant columns and resolved FK inconsistencies across multiple tables |

---

## 2. Product Overview

SiteVoice is an AI-powered construction site management platform that transforms voice messages into actionable tasks, structured data, and professional progress reports. Workers speak updates in their native language, and the system automatically transcribes, translates, classifies, and routes them to the right manager — while feeding a complete project management layer covering budgets, milestones, BOQ, finance, and owner communications.

### Key Capabilities

- **Voice-first workflow** — Record voice notes that get automatically processed into structured tasks, material requests, labour requests, and approval workflows
- **22+ language support** — Automatic detection and translation of Indian languages to English, with Sarvam for native Indic accuracy
- **AI-powered classification** — Intent detection, priority assignment, confidence scoring, and structured data extraction
- **Safety-first alerts** — Critical keyword detection triggers immediate red-banner alerts and push notifications
- **Role-based dashboards** — Tailored interfaces for Workers, Managers, Admins, Owners, and Super Admins
- **Project planning** — Milestones, project plans, BOQ, and budget tracking in one platform
- **Real-time collaboration** — Live updates via Supabase Realtime subscriptions
- **Geofenced attendance** — GPS check-in/check-out with configurable site radius
- **Finance management** — Invoice tracking, payment recording, owner fund requests, and owner payments
- **AI Report Generation** — Auto-generate dual reports (internal + client-facing) using multi-provider LLMs, with PDF export and email delivery
- **Agent orchestration** — Background multi-step AI workflows managed by the `sitevoice-agents` service
- **Multi-company support** — Users can belong to multiple companies with independent roles in each
- **Cross-platform** — Native Android/iOS apps and Progressive Web App (PWA)
- **Eval harness** — Built-in AI quality measurement infrastructure for continuous pipeline improvement

---

## 3. Getting Started

### Authentication Flow

1. **Login** — Enter email and password on the login screen
2. **Company Selection** — If you belong to multiple companies, select which one to work with. Your role badge and primary company indicator are shown for each
3. **Dashboard** — You are automatically routed to the dashboard matching your role:
   - Workers → Construction Home Screen
   - Managers/Admins → Manager Dashboard
   - Owners → Owner Dashboard
   - Super Admins → Super Admin Panel

### Switching Companies

If you belong to multiple companies, tap the **swap icon** in the top-right of the app bar to switch. Each company may have a different role assigned to you.

### Logging Out

Tap the **logout icon** in the top-right corner. A confirmation dialog appears before sign-out.

---

## 4. User Roles & Permissions

| Role | Dashboard | What They Can Do |
|------|-----------|-----------------|
| **Worker** | Construction Home | Record voice notes, view assigned tasks, check attendance, add info to tasks, complete/reopen tasks |
| **Manager** | Manager Dashboard | Manage action items, coordinate teams, manage sites, record voice notes, approve/reject invoices, track finances, view attendance, generate AI reports, view site details, manage project plans and BOQ |
| **Admin** | Manager Dashboard | Same as Manager plus full company management, invite/remove users, manage roles, manage AI prompts, view user management audit log |
| **Owner** | Owner Dashboard | View owned projects, approve/deny escalated requests, send/receive messages, view AI-generated progress reports, download PDF reports, track material specs, design changes, and finances |
| **Super Admin** | Super Admin Panel | Onboard new companies, view all companies, manage company status, manage eval infrastructure |

### Permission Matrix

| Action | Worker | Manager | Admin | Owner | Super Admin |
|--------|--------|---------|-------|-------|-------------|
| Record voice notes | ✓ | ✓ | ✓ | — | — |
| View all account voice notes | — | ✓ | ✓ | — | ✓ |
| Manage action items | — | ✓ | ✓ | — | ✓ |
| Manage projects/sites | — | ✓ | ✓ | — | ✓ |
| Invite/manage users | — | — | ✓ | — | ✓ |
| View finance module | — | ✓ | ✓ | view | ✓ |
| Approve owner escalations | — | — | — | ✓ | — |
| Generate AI reports | — | ✓ | ✓ | — | — |
| View received reports | — | — | — | ✓ | — |
| Manage AI prompts | — | — | ✓ | — | ✓ |
| Company onboarding | — | — | — | — | ✓ |
| Project planning / BOQ | — | ✓ | ✓ | view | ✓ |
| Health score weights | — | — | ✓ | — | ✓ |
| User management audit log | — | — | ✓ | — | ✓ |

---

## 5. Worker Features

Workers access a 3-tab interface designed for construction site use.

### 5.1 My Logs Tab

**Purpose:** View all voice notes you have sent, along with their processing status and manager responses.

**How to use:**
- Tap the **microphone FAB** at the bottom to start recording
- Optionally select a **quick-tag** before recording to declare your intent (Update, Approval Request, Action Required) — this improves AI classification accuracy and reduces duplicates
- Speak your update, request, or report in any supported language
- Tap the mic again to stop and submit
- Your voice note appears with a **processing** status
- Watch as the status progresses: Processing → Transcribed → Translated → Completed
- A **typewriter animation** shows the transcript appearing in real-time

**Each log card shows:**
- Transcript preview (2 lines)
- Category badge (ACTION, APPROVAL, UPDATE, INFO)
- Quick-tag badge (if a tag was set before recording)
- Time since recording
- Processing status indicator
- Manager response section (if manager has acted on it)

**Actions available:**
- **Play audio** — Listen to the original recording
- **Record reply** — Send a follow-up voice note linked to this one
- **Delete** — Remove the voice note (only within 5 minutes of creation, with countdown timer)
- **View interactions** — See all manager actions taken on this note

### 5.2 Daily Tasks Tab

**Purpose:** View and manage tasks assigned to you by managers.

**Two-tier expandable card layout:**

| State | What Is Shown |
|-------|--------------|
| **Collapsed** | Priority border (red/orange/green), category badge, summary (2 lines), sender, time, status |
| **Expanded** | Audio player, full transcript (original + English), AI analysis, structured data (materials/labour), interaction trail (last 3) |

**Worker actions:**
- **ADD INFO** — Provide additional information via voice recording or text
- **COMPLETE** — Mark the task as done (triggers the proof-of-work validation gate if configured)
- **REOPEN** — Reopen a completed task if more work is needed

### 5.3 Attendance Tab

**Purpose:** Check in and out of your construction site with GPS verification.

1. Tap **Check In** when you arrive at the site
2. The app verifies your GPS location against the site's geofence
3. If within the radius, check-in is recorded with distance from site centre
4. If outside the geofence, a warning is shown (manager can override)
5. Tap **Check Out** when leaving; optionally attach a daily report (voice or text)

**Attendance card shows:**
- Check-in and check-out times, duration worked
- Distance from site centre, geofence status (verified or overridden)
- Daily report type badge (VOICE or TEXT)

---

## 6. Manager / Admin Features

Managers access a 5-tab dashboard with a central microphone FAB for quick voice recording.

### 6.1 Bottom Navigation

```
[Actions]  [Sites]  [ MIC ]  [Users]  [Finance]
```

The central microphone button is always visible. Tap it to record a voice note for the current project.

**AppBar Actions:**
- **Reports icon** — AI Report Generation screen
- **Company switcher** — Switch between companies (shown for multi-company users)
- **Logout** — Sign out with confirmation

### 6.2 Critical Alert Banner

A persistent red banner appears when safety-critical voice notes are detected, showing up to 3 items:
- **VIEW** — Jump to the action in the Actions tab
- **INSTRUCT** — Record an immediate voice instruction
- "+N more" for additional alerts

**Critical trigger keywords:** injury, accident, collapse, fire, gas leak, electrocution, emergency, unsafe, danger, hazard, crack, structural failure.

### 6.3 Actions Tab

**Purpose:** Manage all action items across your sites.

**Filtering & Search:**
- Status filter — All, Pending, In Progress, Verifying, Completed
- Category filter — All, Approval, Action Required, Needs Review
- Search — Find actions by summary, details, or AI analysis text
- Sort — Newest, Oldest, Priority High-to-Low, Priority Low-to-High, Recently Updated
- Stats cards — Tappable counts per status

**Action Item Lifecycle:**

```
PENDING → IN PROGRESS → VERIFYING → COMPLETED
   |                       ↑
   +────── COMPLETED ───────  (direct completion if no proof gate)
```

**Action card details:**

| State | Content |
|-------|---------|
| **Collapsed** | Priority dot, category badge, CRITICAL/AI-SUGGESTED badges, AI summary, sender, project, status, action buttons |
| **Expanded** | Audio player, progressive transcript, AI analysis + confidence bar, structured approval/material/labour data, proof photo, interaction history |

**Manager Actions on Action Items:**

| Action | When Available | Effect |
|--------|---------------|--------|
| **APPROVE** | Pending approvals | Approves request, moves to In Progress |
| **WITH NOTE** | Pending approvals | Approves with attached conditions |
| **DENY** | Pending approvals | Rejects; mandatory reason recorded |
| **INSTRUCT** | Pending action items | Records voice instruction sent to worker |
| **FORWARD** | Any pending item | Reassigns to a different team member |
| **ACKNOWLEDGE** | Pending updates | Confirms receipt, moves to Completed |
| **UPLOAD PROOF** | In Progress items | Camera capture of work evidence |
| **VERIFY** | Verifying items | Accepts proof, moves to Completed |
| **REJECT PROOF** | Verifying items | Returns to In Progress for re-work |
| **Set Priority** | Any item | Change to HIGH / MED / LOW |
| **Edit Summary** | Any item | Modify the AI-generated summary |
| **Escalate to Owner** | Any item | Create owner approval request |
| **View Trail** | Any item | Full interaction history |

**AI Review Actions (AI-suggested items):**
- **CONFIRM** — Accept the AI suggestion
- **EDIT** — Modify the AI summary
- **DISMISS** — Reject the AI suggestion

### 6.4 Sites Tab

Contains two sub-tabs: **SITES** and **ATTENDANCE**.

#### Sites Sub-Tab

**Site management actions (long-press menu):**
- **Assign Users** — Bulk assign/unassign team members
- **Assign Owner** — Link a project owner
- **Edit** — Name, location, geofence settings
- **Delete** — Permanently remove (with confirmation)

**Create New Site fields:** Name, Location, Geofence (radius 50–500m, "Use Current Location"), Link Owner.

#### Attendance Sub-Tab

Select a date and optionally a site to view:
- Summary bar: Workers count, Check-ins, On-Site
- Per-worker cards with check-in/out times, duration, GPS distance, report type, EXEMPT badge

### 6.5 Users / Team Tab

Two sub-tabs: **ACTIVE** and **INACTIVE**. Members grouped by role (Admin > Manager > Owner > Worker).

**User management actions:**
- **Invite User** — Name, email, password/existing user, role, language preferences
- **Edit User** — Details and project assignment
- **Deactivate / Activate** — Toggle access without losing data
- **Remove** — Permanent removal (data preserved as "Former Member")
- **Manage Roles** — Configure company-wide role definitions (custom roles supported in V2)

**Every user management action is recorded in `user_management_audit_log`** (Admin-visible only).

### 6.6 Voice Notes Feed

**Access:** Tap the **feed icon** in the Actions tab search bar.

**Features:** Search, filter by site or user, sort by newest/oldest.

**Actions on voice notes:**
- **Reply** — Record a linked voice reply
- **Acknowledge** — Mark as reviewed
- **Add Note** — Attach a text annotation
- **Create Action** — Promote an update to an action item
- **Forward** — Send to another team member (new in V2)

### 6.7 AI Confidence Calibration

Collapsible panel showing weekly AI performance:
- Average confidence %, trend, items processed
- Distribution bar (High/Medium/Low tiers)
- Manager feedback counts (Confirmed, Dismissed, Promoted)

**Site Glossary Manager:** Add construction-specific terms per project (Material, Brand, Tool, Process, Location, Role, General) — injected into AI prompts for accuracy.

### 6.8 AI Reports

**Access:** Reports icon in the Manager Dashboard AppBar.

**Generating a report:**
1. Select type: Daily, Weekly, or Custom date range
2. Choose sites: All or specific
3. Tap **Generate** — produces a Manager Report and an Owner Report simultaneously
4. Review/edit in the markdown editor
5. Save Draft → Finalize → Send to Owner (PDF + email via Resend API)

See [Section 12 — AI Report Generation](#12-ai-report-generation) for full details.

### 6.9 Site Detail & Daily Reports

**Two-tab interface per site:**

**Summary Tab:**
- Status cards: Total, Pending, Active, Completed action items
- Quick stats: Worker count, today's voice notes
- Completion progress bar
- Blockers (high-priority blocking items)
- Recent actions (last 5)

**Daily Reports Tab:**
- Date range filter
- Voice notes grouped by date
- Full VoiceNoteCard (audio, transcript, sender)
- Real-time updates, pull-to-refresh

---

## 7. Owner Features

Owners access a 4-tab dashboard for project oversight, approvals, messaging, and report viewing.

### 7.1 Projects Tab

Each project card shows action item statistics (pending / in progress / completed). Tapping opens a **4-tab detail view:**

| Tab | Contents |
|-----|----------|
| **Summary** | Action counts, blockers, completion % |
| **Materials** | Material specs with status (ordered/delivered/installed) |
| **Design Log** | Design change proposals with before/after specs and approval status |
| **Finance** | Financial overview — approved spending, pending amounts, transaction list |

### 7.2 Approvals Tab

Respond to escalated approval requests from managers.

**Filter options:** All, Pending, Approved, Denied, Deferred

**Each approval shows:** Title, description, amount (INR), category badge, requested-by, date, status.

**Actions:** Approve (optional note), Deny (optional note), Defer (optional note).

Badge on tab icon shows pending approval count.

### 7.3 Messages Tab

- View voice messages directed to you (filtered by project)
- Record and send voice replies to managers/workers
- Badge shows unread message count

### 7.4 Reports Tab

Reports where `owner_report_status = 'sent'` that include your projects.

**Report card shows:** Date range, type (Daily/Weekly/Custom), sender name, project names, relative sent time.

**Tapping a report** opens a read-only markdown viewer with:
- Metadata header (sender, project names, sent date)
- Full report content rendered as styled markdown
- **PDF download** in the AppBar

**In V2:** Owners receive a push notification the moment a report is shared.

---

## 8. Super Admin Features

Accessible only to users in the `super_admins` table.

### 8.1 Companies Tab

- View all companies with status, user count, created date
- Filter by: Active, Inactive, Archived
- Deactivate or Archive companies
- View company details: users, projects, voice note count, action item count

### 8.2 Onboard Tab

Creates a new company with an initial admin user via the `create-account-admin` edge function.

**Fields:** Company Name, Admin Name, Admin Email, Admin Password, Transcription Provider (Groq / OpenAI / Gemini / **Sarvam** — new in V2), Language Preferences.

### 8.3 Eval Infrastructure (New in V2)

Super admins can access the built-in AI evaluation harness:

- **Eval Test Cases** — Curated voice note inputs with expected outputs (intent, priority, confidence)
- **Eval Runs** — Triggered pipeline runs against the test case suite
- **Eval Run Results** — Per-test-case results with pass/fail, actual vs expected, confidence drift

This enables the team to measure regression and improvement after any prompt or pipeline change.

---

## 9. Voice Notes & AI Pipeline

### 9.1 Recording

- **Native (Android/iOS):** AAC .m4a via the `record` package
- **Web (PWA):** WebM via MediaRecorder API
- **Quick-tag (New in V2):** Worker selects intent tag before recording to pre-declare message type

### 9.2 Processing Pipeline

```
RECORDING → UPLOAD → ASR → TRANSLATE → AI CLASSIFY → EXTRACT → ACTION ITEMS
               |        |        |            |            |
            status:  status:  status:      status:    Structured
           processing transcribed translated completed sub-tables
```

**Phase 1 — Upload & Trigger:**
- Voice note created with status `processing`
- Database webhook trigger fires the `transcribe-audio` edge function

**Phase 2 — Speech-to-Text (ASR):**
- Transcription provider selected per account:
  - **Groq** — Whisper Large v3, ~164× real-time speed (default, free tier)
  - **OpenAI** — Whisper-1 API (paid, high accuracy)
  - **Gemini** — 1.5 Flash multimodal
  - **Sarvam** *(New in V2)* — Native Indian language ASR, highest accuracy for Indic scripts
- Domain context injected (materials, roles, processes)
- Language auto-detected from audio
- Status updates to `transcribed`

**Phase 3 — Translation:**
- Non-English transcripts translated to English
- Project-specific glossary terms preserved
- Recent manager corrections used as few-shot examples
- Status updates to `translated`

**Phase 4 — AI Classification:**
- Intent: `action_required` / `approval` / `update` / `information`
- Priority: Low / Med / High / Critical
- Confidence score (0.0–1.0)

**Phase 5 — Structured Data Extraction (Enhanced in V2):**

Extracted data is written to normalised sub-tables alongside the voice note:

| Sub-Table | Data Extracted |
|-----------|---------------|
| `voice_note_approvals` | Type, amount, currency, due date, `project_id` |
| `voice_note_labor_requests` | Type, headcount, duration, start date, urgency, `project_id` |
| `voice_note_material_requests` | Name, quantity, unit, brand, delivery date, urgency, `project_id` |
| `voice_note_project_events` | Event type, title, description, follow-up requirements, `project_id` |

**Phase 6 — Action Item Creation:**
- Created when intent is actionable, critical keywords are detected, or it is a manager-to-worker note
- Confidence routing:
  - ≥ 85%: Auto-approved, standard workflow
  - 70–84%: `needs_review` flag, amber card treatment
  - < 70%: `flagged` status for manual manager attention

**Phase 7 — Safety Detection:**
- Critical keywords trigger red alert banner, forced action item creation, and immediate push notification to manager

### 9.3 Confidence Tier System

| Tier | Confidence | Visual | Auto-Action |
|------|-----------|--------|-------------|
| HIGH | ≥ 85% | Standard card | Auto-surface |
| MEDIUM | 70–84% | Amber border + "AI-suggested" chip | Confirmation gate |
| LOW | < 70% | Collapsed "Flagged for Review" section | Manual only |
| CRITICAL | Any | Red card, persistent banner | Always surface |

### 9.4 Audio Player

- **Native:** `audioplayers` package with play/pause, seek, duration
- **Web/PWA:** HTML5 `<audio>` element via `dart:js_interop` (fixes Safari issues)

### 9.5 Editable Transcription & Edit History (Enhanced in V2)

Managers can edit voice note transcripts directly from the action item view. In V2, every edit is recorded in `voice_note_edits`:
- `edited_by` (user ID)
- `previous_text` (original transcript)
- `new_text` (corrected transcript)
- `edited_at` timestamp

Edit history is visible in the voice note detail view and feeds back into AI self-improvement.

### 9.6 Voice Note Forwarding (New in V2)

Managers can forward a voice note to any team member from the action card:
- **FORWARD** button available on any pending item
- `voice_note_forwards` records: `original_note_id`, `forwarded_from`, `forwarded_to`, forward timestamp

### 9.7 AI Self-Improvement

Manager actions are recorded in `ai_corrections` as few-shot examples fed into future prompts:
- Summary edits, priority changes, category corrections
- Transcript corrections
- Confirmed/dismissed suggestions
- Promoted updates, denied requests with reasons

---

## 10. Project Planning Module

*(New in V2)*

Accessed from the Sites tab within a site detail view. Provides structured project management tooling alongside the voice-first workflow.

### 10.1 Project Plans

Store high-level plans for each project:
- Plan title, scope description, start and target end dates
- Current phase, overall status
- Account-scoped with admin/manager full access; owners view assigned projects; workers view all within account

### 10.2 Project Milestones

Milestone tracking within each project:
- Milestone name, description, target date, actual completion date
- Status: Upcoming / In Progress / Completed / Overdue
- Linked to `project_id` and `account_id`
- Visual progress indicator on the site summary screen

### 10.3 Project Budgets

Budget records per project:
- Total budget amount (INR)
- Budget type (overall / category-specific)
- Approved, spent, and remaining amounts
- Notes and approval status
- Links to finance transactions for reconciliation

### 10.4 Bill of Quantities (BOQ)

Structured item-by-item cost breakdown:
- Item name, description, unit, quantity, unit rate
- Calculated total cost
- Import from CSV or Excel via the file import service
- Owners can view BOQ for their assigned projects
- Workers can view for reference

### 10.5 Project Health Score

Each project has a calculated health score based on configurable weights:

| Factor | Default Weight |
|--------|---------------|
| Action items completion rate | Configurable |
| Overdue milestones | Configurable |
| Budget burn rate | Configurable |
| Attendance consistency | Configurable |
| Critical alerts in period | Configurable |

Admin users can adjust `health_score_weights` per account. Super admins manage global defaults (where `account_id IS NULL`).

---

## 11. Finance Module

Access via the **Finance tab** (wallet icon) in the manager dashboard. Contains two sub-tabs.

### 11.1 Site Finances Sub-Tab

**Summary metrics:** Total Invoiced, Total Paid, Pending, Overdue (all in INR).

**Invoice Workflow:**

```
DRAFT → SUBMITTED → APPROVED → PAID
                 ↘ REJECTED
```

Auto-paid: When total linked payments ≥ invoice amount, status changes to `paid` automatically.

**Creating an invoice:** Invoice number, vendor, amount, site, due date, description, notes. Toggle "Submit immediately" or save as draft.

**Managing invoices:** Approve, Reject (reason required), Add Payment.

**Payment methods:** Cash, Bank Transfer, UPI, Cheque, Other.

### 11.2 Owner Finances Sub-Tab

**Summary:** Total Received, Total Requested, Pending count.

**Payments Received:** Record owner payments with confirmation workflow (CONFIRMED / UNCONFIRMED badges).

**Fund Requests:**
- Urgency levels: Low / Normal / High / Critical
- Statuses: Pending, Approved, Denied, Partially Approved
- Owners see and respond to fund requests from their Owner Dashboard

---

## 12. AI Report Generation

SiteVoice generates dual AI reports from all site activity, producing internal management content and client-facing summaries simultaneously.

### 12.1 Report Types

| Type | Period |
|------|--------|
| Daily | Single day snapshot |
| Weekly | Monday–Sunday summary |
| Custom | User-defined date range |

### 12.2 Dual Report Generation

| Report | Audience | Tone | Contents |
|--------|----------|------|---------|
| **Manager Report** | Internal | Factual, no-nonsense | Work completed, action items, issues, finances (granular), attendance, voice notes, next period plan |
| **Owner Report** | Client-facing | Professional, solution-oriented | Executive summary, project wins, challenges resolved, financial summary (high-level), next steps, items requiring owner attention |

### 12.3 Generation Workflow

```
Configure → Generate → Review/Edit → Finalize → Send to Owner
    |            |            |           |            |
  Type,       Edge Fn     Markdown     Lock        PDF +
  Dates,     calls LLM    editor +    content     Email via
  Sites      (dual call)  preview                 Resend API
```

### 12.4 AI Provider Support

| Provider | Model | Notes |
|----------|-------|-------|
| Groq | Llama 3.3 70B | Fast, free-tier available |
| OpenAI | GPT-4o-mini | High quality, paid |
| Gemini | 1.5 Flash | Google multimodal |

Prompts are stored per provider in `ai_prompts` with versioning and activation control. Admin users can edit prompts from the Reports Hub settings.

### 12.5 PDF Generation

Client-side PDF generation via the `pdf` Flutter package:
- A4 format, branded header (company name, date range)
- Markdown converted to styled PDF (headings, bullets, bold, dividers)
- Checkmark bullets in green for project wins
- Footer: "Generated by SiteVoice" + page numbers
- Share/save via system dialog or email directly

### 12.6 Data Sources

| Source | Data Used |
|--------|----------|
| Action items | Status counts, completions, new items, blockers |
| Voice notes | Total notes, key themes, critical messages |
| Attendance | Check-ins, average hours, absences |
| Invoices | Invoiced, approved, rejected, paid, overdue amounts |
| Payments | Total payments, methods |
| Owner payments | Payments received from owners |
| Fund requests | Requested, approved, pending |
| Project glossary | Terminology for accurate reporting |

---

## 13. Attendance & Geofencing

### 13.1 Worker Check-In Flow

1. Tap **Check In**
2. App requests GPS location
3. Checked against site geofence (centre + radius + 20m buffer)
4. Within radius → recorded with distance from centre
5. Outside radius → warning shown; manager can override
6. GPS denied → prompt to enable; bypass available with manager approval

### 13.2 Worker Check-Out Flow

1. Tap **Check Out**
2. Checkout timestamp recorded
3. Optional daily report (voice or text) attached

### 13.3 Geofence Configuration

- **Centre:** Set via "Use Current Location" in site settings
- **Radius:** 50m–500m (default 200m)
- **Buffer:** 20m tolerance to prevent boundary flip-flopping

### 13.4 Geofence Exemptions

Managers can mark workers as geofence exempt (check in from any location). Exempt records are marked with an **EXEMPT** badge.

### 13.5 Manager Attendance View

- Date picker + site filter
- Summary: unique workers, total check-ins, currently on-site
- Detailed cards: times, durations, GPS distances, report types

### 13.6 Performance (New in V2)

Database indexes on `attendance.user_id`, `attendance.account_id`, and `attendance.check_in_time` significantly reduce query time for date-range attendance reports on large datasets.

---

## 14. Agent Orchestration System

*(New in V2)*

The `sitevoice-agents` service is a standalone Next.js/TypeScript application that coordinates multi-step AI workflows beyond what single edge functions can handle.

### 14.1 Architecture

```
Supabase DB → trigger → trigger-agents (edge function) → sitevoice-agents (Next.js)
                                                              |
                                          ┌───────────────────┤
                                          ↓                   ↓
                                    Groq SDK             Supabase JS
                                  (LLM calls)          (DB reads/writes)
```

### 14.2 Capabilities

- **Multi-step classification chains** — Run a first-pass classification, validate confidence, then re-classify with additional context if needed
- **Batch processing** — Handle multiple voice notes in parallel with coordinated database writes
- **Agent Processing Log** — Every agent run is recorded in `agent_processing_log` with input, output, duration, and error details
  - Super admins: full access
  - Admin/Manager: read-only (for debugging)
  - All writes performed by service role

### 14.3 Technology

| Component | Technology |
|-----------|-----------|
| Framework | Next.js 14.2 |
| Runtime | Node.js with TypeScript |
| LLM | Groq SDK |
| DB | Supabase JS client |
| Charts | Recharts (for admin dashboards) |

---

## 15. Security & Data Isolation

*(Significantly expanded in V2)*

### 15.1 Row Level Security

All 30+ tables have explicit RLS policies enforced at the database layer. No application-level workaround can bypass them.

**Helper functions (SECURITY DEFINER, stable):**

| Function | Returns |
|----------|---------|
| `is_super_admin()` | `true` if `auth.uid()` is in `super_admins` |
| `my_account_id()` | `account_id` of the calling user |
| `my_role()` | Role text of the calling user |
| `is_admin_or_manager()` | `true` if role is `admin` or `manager` |
| `is_owner_of_project(pid)` | `true` if user is in `project_owners` for that project |
| `is_account_admin_or_manager(account_id)` | `true` if calling user is admin/manager in the given account |

**Policy pattern per table:**

```
1. Super admin: FOR ALL (bypasses all restrictions)
2. Admin/Manager: FOR ALL scoped to my_account_id()
3. Owner: FOR SELECT scoped to assigned projects
4. Worker: FOR SELECT + limited INSERT/UPDATE on own rows
```

### 15.2 Multi-Tenant Isolation

- Every table carries `account_id` (or resolves to it via FK)
- All queries scoped to `my_account_id()`
- Service role (edge functions) bypasses RLS for writes the app user cannot perform
- `super_admins` table: users can only read their own row (prevents privilege escalation)

### 15.3 Edge Function Security

Sensitive operations are gated behind Supabase Edge Functions called with the service role key:

| Function | Purpose |
|----------|---------|
| `transcribe-audio` | Voice note processing pipeline |
| `generate-report` | AI report generation |
| `send-report-email` | PDF generation and email delivery |
| `create-account-admin` | Company onboarding |
| `invite-user` | User invitation |
| `manage-user-status` | User activation/deactivation/removal |
| `manage-company-status` | Company status changes |
| `trigger-agents` | Agent orchestration trigger |

### 15.4 User Management Audit Log

Every user management action performed by an admin is recorded in `user_management_audit_log`:
- Action type (invite, deactivate, activate, remove, role_change)
- Actor (admin who performed it)
- Target user
- Before/after state
- Timestamp

Visible to Admin and Super Admin users only; only the service role can insert.

---

## 16. Multi-Company Support

- Users belong to **multiple companies** with independent roles in each
- A singleton `CompanyContextService` manages active company context
- Company selection is persisted across sessions

**Selection priority:** Previously saved preference → Primary company flag → First active company.

**Data isolation:** All queries scoped to active `account_id`. RLS enforces access boundaries at the database level.

---

## 17. Real-Time Features

SiteVoice uses Supabase Realtime (PostgreSQL Change Data Capture) for live updates:

| Feature | What Updates in Real-Time |
|---------|--------------------------|
| Action Items | New actions, status changes, priority updates |
| Voice Notes | Progressive transcript display as processing completes |
| Critical Alerts | Safety alerts appear on manager dashboard immediately |
| Daily Tasks | Worker task list updates when items are assigned |
| Invoices | New invoices and status changes sync across devices |
| Payments | Payment records appear without manual refresh |
| Owner Payments | Confirmation updates live |
| Fund Requests | Status changes reflected immediately |
| Attendance | Check-in/check-out visible to managers in real-time |
| Reports | New reports and status changes update on both dashboards |
| Owner Reports | Sent reports appear instantly on owner's Reports tab |
| **Agent Processing Log** *(V2)* | Agent run results visible to super admins in real-time |

All lists support **pull-to-refresh** for manual reload.

---

## 18. Supported Languages

SiteVoice supports automatic speech recognition and translation for **22+ languages**. The addition of Sarvam in V2 provides native Indic ASR quality for regional languages.

| Language | Code | Groq ASR | OpenAI ASR | Sarvam ASR | Translation |
|----------|------|----------|------------|------------|-------------|
| English | en | ✓ | ✓ | — | Native |
| Hindi | hi | ✓ | ✓ | ✓ | ✓ |
| Telugu | te | ✓ | ✓ | ✓ | ✓ |
| Tamil | ta | ✓ | ✓ | ✓ | ✓ |
| Kannada | kn | ✓ | ✓ | ✓ | ✓ |
| Marathi | mr | ✓ | ✓ | ✓ | ✓ |
| Gujarati | gu | ✓ | ✓ | ✓ | ✓ |
| Punjabi | pa | ✓ | ✓ | ✓ | ✓ |
| Malayalam | ml | ✓ | ✓ | ✓ | ✓ |
| Bengali | bn | ✓ | ✓ | ✓ | ✓ |
| Urdu | ur | ✓ | ✓ | ✓ | ✓ |
| Assamese | as | ✓ | ✓ | ✓ | ✓ |
| Odia | or | ✓ | ✓ | ✓ | ✓ |
| Konkani | kok | ✓ | — | ✓ | ✓ |
| Maithili | mai | ✓ | — | ✓ | ✓ |
| Sindhi | sd | ✓ | — | ✓ | ✓ |
| Nepali | ne | ✓ | ✓ | — | ✓ |
| Sanskrit | sa | ✓ | — | — | ✓ |
| Dogri | doi | ✓ | — | ✓ | ✓ |
| Manipuri | mni | ✓ | — | ✓ | ✓ |
| Santali | sat | ✓ | — | ✓ | ✓ |
| Kashmiri | ks | ✓ | — | ✓ | ✓ |
| Bodo | bo | ✓ | — | ✓ | ✓ |

---

## 19. Technical Architecture

### Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) — single codebase for Android, iOS, Web |
| **State Management** | Flutter Riverpod 2.6 (primary), Provider 6.1 (legacy) |
| **Routing** | go_router 17.1 |
| **Backend** | Supabase (PostgreSQL 17, Auth, Edge Functions, Storage, Realtime) |
| **Edge Functions** | Deno / TypeScript (8 functions) |
| **AI/ASR** | Groq (Whisper Large v3), OpenAI (Whisper-1), Gemini (1.5 Flash), Sarvam |
| **LLM** | Groq (Llama 3.3 70B), OpenAI (GPT-4o-mini), Gemini (1.5 Flash) |
| **Agent Orchestration** | Next.js 14.2 / Node.js / TypeScript (`sitevoice-agents`) |
| **PWA Hosting** | Firebase Hosting |
| **Storage** | Supabase Storage (voice-notes, proof-photos, reports-pdfs buckets) |
| **Email** | Resend API |
| **CI/CD** | GitHub Actions (Firebase Hosting deploy on merge/PR) |

### Database Tables (V2 — Full List)

| Table | Purpose |
|-------|---------|
| `accounts` | Company accounts with transcription provider settings |
| `super_admins` | Platform super admin identities |
| `users` | User profiles with role, language, and geofence settings |
| `user_company_associations` | Multi-company membership |
| `roles` | Custom role definitions per company *(V2)* |
| `user_management_audit_log` | Audit trail for all user management actions *(V2)* |
| `projects` | Construction sites with geofence coordinates |
| `project_owners` | Owner-to-project linkage |
| `project_plans` | High-level project plans *(V2)* |
| `project_milestones` | Milestone tracking per project *(V2)* |
| `project_budgets` | Budget records per project *(V2)* |
| `boq_items` | Bill of Quantities line items *(V2)* |
| `health_score_weights` | Configurable health score factor weights *(V2)* |
| `voice_notes` | All voice recordings with processing status and transcripts |
| `voice_note_ai_analysis` | AI classification results per voice note |
| `voice_note_approvals` | Structured approval data extracted from voice notes |
| `voice_note_labor_requests` | Labour request data extracted from voice notes |
| `voice_note_material_requests` | Material request data extracted from voice notes |
| `voice_note_project_events` | Project event data extracted from voice notes |
| `voice_note_edits` | Transcript edit history *(V2)* |
| `voice_note_forwards` | Voice note forwarding records *(V2)* |
| `action_items` | Tasks with lifecycle status, priority, and interactions |
| `owner_approvals` | Escalated approval requests for project owners |
| `owner_payments` | Payments received from project owners |
| `fund_requests` | Fund requests to project owners |
| `attendance` | Worker check-in/check-out records with GPS |
| `invoices` | Invoice records with approval workflow |
| `payments` | Payment records linked to invoices |
| `notifications` | Real-time notification records |
| `ai_corrections` | Manager feedback for AI self-improvement |
| `site_glossary` | Project-specific construction terminology |
| `reports` | AI-generated dual reports (manager + owner) |
| `ai_prompts` | Configurable LLM prompts per provider, with versioning |
| `design_change_logs` | Design change proposals with before/after specs |
| `material_specs` | Material specs with delivery status tracking |
| `agent_processing_log` | AI agent run records *(V2)* |
| `eval_test_cases` | AI evaluation test case inputs *(V2)* |
| `eval_runs` | AI evaluation run records *(V2)* |
| `eval_run_results` | Per-test-case evaluation results *(V2)* |

### Performance Benchmarks

| Operation | Target |
|-----------|--------|
| Voice note processing (record → completed action item) | 4–8 seconds |
| Report generation (data aggregation + dual LLM calls) | 15–30 seconds |
| Realtime subscription propagation | < 2 seconds |
| Attendance date-range query (V2 indexed) | < 200ms for up to 10,000 records |
| Audio download (single, reused across ASR phases) | 1× download, cached |

### Architecture Patterns

- **Clean architecture** — `core/` (framework & utilities), `features/` (feature modules), `models/` (domain), `providers/` (state), `repositories/` (data access)
- **Repository pattern** — All data access abstracted behind typed repository classes
- **Two-tier card UI** — Collapsed summary + expanded detail (accordion) throughout all role dashboards
- **Confidence routing** — Risk-based visibility rules per category at the database and UI layers
- **Service role writes** — Sensitive operations (user creation, audit logging, agent processing) performed only by edge functions using the service key, never the client JWT

---

## Appendix A — V1 → V2 Migration Notes

No breaking changes to the app authentication or core voice note workflow. The following require one-time setup after upgrading to V2:

1. **Run `20260224_rls_policies.sql`** — Applies comprehensive RLS policies to all tables. Run in Supabase dashboard under SQL editor.
2. **Sarvam provider** — If using Sarvam for transcription, set the Sarvam API key in the account's transcription provider settings via Super Admin onboarding.
3. **Health score weights** — Create default weights row for each account (or rely on the global `account_id IS NULL` row).
4. **Custom roles** — Existing role strings (admin, manager, owner, worker) continue to work. Optionally seed the `roles` table with display labels.
5. **Agent service** — Deploy `sitevoice-agents` as a separate Next.js service and configure `SITEVOICE_AGENTS_URL` in the `trigger-agents` edge function environment.

---

*SiteVoice — Turning voices into actions on the construction site.*
