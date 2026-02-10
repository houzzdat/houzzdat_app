# SiteVoice (Houzzapp) - Product Release Document

**Version:** 1.0
**Platform:** Flutter (Android, iOS, PWA)
**Backend:** Supabase (PostgreSQL, Auth, Edge Functions, Storage, Realtime)
**Last Updated:** February 2026

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [Getting Started](#2-getting-started)
3. [User Roles & Permissions](#3-user-roles--permissions)
4. [Worker Features](#4-worker-features)
5. [Manager / Admin Features](#5-manager--admin-features)
6. [Owner Features](#6-owner-features)
7. [Super Admin Features](#7-super-admin-features)
8. [Voice Notes & AI Pipeline](#8-voice-notes--ai-pipeline)
9. [Finance Module](#9-finance-module)
10. [Attendance & Geofencing](#10-attendance--geofencing)
11. [Multi-Company Support](#11-multi-company-support)
12. [Real-Time Features](#12-real-time-features)
13. [Supported Languages](#13-supported-languages)
14. [Technical Architecture](#14-technical-architecture)

---

## 1. Product Overview

SiteVoice is an AI-powered construction site management platform that transforms voice messages into actionable tasks. Workers speak updates in their native language, and the system automatically transcribes, translates, classifies, and routes them to the right manager with extracted materials, labor, and approval requests.

### Key Capabilities

- **Voice-first workflow** - Record voice notes that get automatically processed into structured tasks
- **22+ language support** - Automatic detection and translation of Indian languages to English
- **AI-powered classification** - Intent detection, priority assignment, material/labor extraction
- **Safety-first alerts** - Critical keyword detection triggers immediate red-banner alerts
- **Role-based dashboards** - Tailored interfaces for Workers, Managers, Owners, and Super Admins
- **Real-time collaboration** - Live updates via Supabase Realtime subscriptions
- **Geofenced attendance** - GPS-based check-in/check-out at construction sites
- **Finance management** - Invoice tracking, payment recording, owner fund requests
- **Multi-company support** - Users can belong to multiple companies with different roles
- **Cross-platform** - Native Android/iOS apps and Progressive Web App (PWA)

---

## 2. Getting Started

### Authentication Flow

1. **Login** - Enter email and password on the login screen
2. **Company Selection** - If you belong to multiple companies, select which one to work with. Your role badge and primary company indicator are shown for each
3. **Dashboard** - You are automatically routed to the dashboard matching your role:
   - Workers see the Construction Home Screen
   - Managers/Admins see the Manager Dashboard
   - Owners see the Owner Dashboard
   - Super Admins see the Super Admin Panel

### Switching Companies

If you belong to multiple companies, tap the **swap icon** in the top-right of the app bar to switch between them. Each company may have a different role assigned to you.

### Logging Out

Tap the **logout icon** in the top-right corner. A confirmation dialog appears before you are signed out.

---

## 3. User Roles & Permissions

| Role | Dashboard | What They Can Do |
|------|-----------|-----------------|
| **Worker** | Construction Home | Record voice notes, view assigned tasks, check attendance, add info to tasks, complete/reopen tasks |
| **Manager** | Manager Dashboard | Manage action items, coordinate teams, manage sites, record voice notes, approve/reject invoices, track finances, view attendance |
| **Admin** | Manager Dashboard | Same as Manager plus full company management, invite/remove users, manage roles |
| **Owner** | Owner Dashboard | View owned projects, approve/deny escalated requests, send/receive messages |
| **Super Admin** | Super Admin Panel | Onboard new companies, view all companies, manage company status |

---

## 4. Worker Features

Workers access a 3-tab interface designed for construction site use.

### 4.1 My Logs Tab

**Purpose:** View all voice notes you have sent, along with their processing status and manager responses.

**How to use:**
- Tap the **microphone FAB** at the bottom to start recording a voice note
- Speak your update, request, or report in any supported language
- Tap the mic again to stop and submit
- Your voice note appears in the list with a **processing** status
- Watch as the status progresses: Processing -> Transcribed -> Translated -> Completed
- A **typewriter animation** shows the transcript appearing in real-time

**Each log card shows:**
- Transcript preview (2 lines)
- Category badge (ACTION, APPROVAL, UPDATE, INFO)
- Time since recording (e.g., "2h ago")
- Processing status indicator
- Manager response section (if manager has acted on it)

**Actions available:**
- **Play audio** - Listen to the original recording
- **Record reply** - Send a follow-up voice note linked to this one
- **Delete** - Remove the voice note (only within 5 minutes of creation, with countdown timer)
- **View interactions** - See all manager actions taken on this note

### 4.2 Daily Tasks Tab

**Purpose:** View and manage tasks assigned to you by managers.

**How to use:**
- Cards show tasks in a two-tier expandable layout
- **Tap a card** to expand it and see full details
- Only one card can be expanded at a time (accordion behavior)

**Collapsed card shows:**
- Priority indicator (colored left border: red=High, orange=Med, green=Low)
- Category badge (ACTION, APPROVAL, UPDATE)
- Task summary (2 lines)
- Sender name and avatar
- Time since creation
- Status badge (if not pending)

**Expanded card shows:**
- **Audio player** - Play the original voice note
- **Full transcript** - Original language + English translation (for non-English)
- **AI Analysis** - What the AI extracted (intent, materials, labor needs)
- **Interaction trail** - Last 3 actions taken on this task

**Worker actions:**
- **ADD INFO** - Provide additional information via:
  - **Voice recording** - Record a voice reply
  - **Text input** - Type a text response
- **COMPLETE** - Mark the task as done
- **REOPEN** - Reopen a completed task if more work is needed

### 4.3 Attendance Tab

**Purpose:** Check in and out of your construction site with GPS verification.

**How to use:**
1. Tap **Check In** when you arrive at the site
2. The app verifies your GPS location against the site's geofence
3. If you are within the site radius, check-in is recorded with your distance from the site center
4. If you are outside the geofence, a warning is shown (manager can override)
5. Tap **Check Out** when leaving the site
6. Optionally provide a daily report via voice or text on checkout

**Attendance card shows:**
- Check-in and check-out times
- Duration worked
- Distance from site center
- Geofence status (verified or overridden)
- Daily report type badge (VOICE or TEXT)

---

## 5. Manager / Admin Features

Managers access a 5-tab dashboard with a central microphone FAB for quick voice recording.

### 5.1 Bottom Navigation

```
[Actions]  [Sites]  [ MIC ]  [Users]  [Finance]
```

The central microphone button is always visible. Tap it to start recording a voice note for the current project; tap again to stop and submit.

### 5.2 Critical Alert Banner

A persistent red banner appears at the top when safety-critical voice notes are detected. It shows up to 3 critical pending items with:
- **VIEW** button - Jump to the action in the Actions tab
- **INSTRUCT** button - Record an immediate voice instruction
- "+N more" indicator for additional alerts

Critical alerts trigger on safety keywords: injury, accident, collapse, fire, gas leak, electrocution, emergency, unsafe, danger, hazard, crack, structural failure.

### 5.3 Actions Tab

**Purpose:** Manage all action items across your sites.

**Filtering & Search:**
- **Status filter** - All, Pending, In Progress, Verifying, Completed
- **Category filter** - All, Approval, Action Required, Needs Review
- **Search** - Find actions by summary, details, or AI analysis text
- **Sort** - Newest, Oldest, Priority High-to-Low, Priority Low-to-High, Recently Updated
- **Stats cards** - Tappable cards showing counts per status. Tap to filter

**Feed access:** Tap the **feed icon** in the top-right of the search bar to open the full Voice Notes Feed in a separate screen.

**Action Item Lifecycle:**

```
PENDING --> IN PROGRESS --> VERIFYING --> COMPLETED
    |                          ^
    +---- COMPLETED -----------+  (direct completion)
```

**Action card (collapsed) shows:**
- Priority dot + label (HIGH / MED / LOW)
- Category badge
- Special badges: CRITICAL (red), AI-SUGGESTED (amber)
- AI-generated summary
- Sender avatar, name, project name
- Status badge
- Context-specific action buttons

**Action card (expanded) shows:**
- Voice note audio player
- Progressive transcript (shows as processing completes)
- AI Analysis section with confidence bar
- Structured approval details (category, amount, materials)
- Proof photo (if uploaded by worker)
- Interaction history (last 3 entries + "View all" link)

**Manager Actions on Action Items:**

| Action | When Available | What It Does |
|--------|---------------|-------------|
| **APPROVE** | Pending approvals | Approves the request, moves to In Progress |
| **WITH NOTE** | Pending approvals | Approves with conditions/notes attached |
| **DENY** | Pending approvals | Rejects with mandatory reason, moves to Completed |
| **INSTRUCT** | Pending action items | Records voice instruction sent back to worker |
| **FORWARD** | Any pending item | Reassigns to a different team member |
| **ACKNOWLEDGE** | Pending updates | Confirms receipt of update, moves to Completed |
| **UPLOAD PROOF** | In Progress items | Triggers camera to capture work evidence |
| **VERIFY** | Verifying items | Accepts the uploaded proof, moves to Completed |
| **REJECT PROOF** | Verifying items | Sends back to In Progress for re-work |
| **Set Priority** | Any item | Change to HIGH / MED / LOW |
| **Edit Summary** | Any item | Modify the AI-generated summary |
| **Escalate to Owner** | Any item | Create an owner approval request (spending, design change, material change, schedule change, or other) |
| **View Trail** | Any item | See full interaction history |

**AI Review Actions (for AI-suggested items):**
- **CONFIRM** - Accept the AI suggestion
- **EDIT** - Modify the AI summary
- **DISMISS** - Reject the AI suggestion

### 5.4 Sites Tab

Contains two sub-tabs: **SITES** and **ATTENDANCE**.

#### Sites Sub-Tab

**Purpose:** Create and manage construction sites/projects.

**Site grid shows:**
- Site photo or placeholder
- Site name and location
- User count badge

**Site management actions (via menu):**
- **Assign Users** - Bulk assign/unassign team members to this site
- **Assign Owner** - Link a project owner (existing or create new)
- **Edit** - Change name, location, geofence settings
- **Delete** - Permanently remove site (with confirmation)

**Create New Site dialog:**
- Site Name (required)
- Location (optional)
- **Geofence setup** (optional, collapsible):
  - "Use Current Location" button sets GPS coordinates
  - Radius slider: 50m to 500m (default 200m)
- **Link Owner** (optional, collapsible):
  - Select existing owner or create new with email/password

#### Attendance Sub-Tab

**Purpose:** View worker attendance across all sites.

**How to use:**
1. Select a **date** using the date picker chip (defaults to today)
2. Optionally filter by a specific **site**
3. View the summary bar: Workers count, Check-ins count, On-Site count

**Each attendance record shows:**
- Worker name and avatar
- Site name
- Status badge: ON SITE (green) or CHECKED OUT (gray)
- Check-in and check-out times
- Duration worked (e.g., "4h 32m")
- Report type badge: VOICE or TEXT (if daily report was submitted)
- Check-in distance from site center
- EXEMPT badge (if geofence was overridden by manager)

### 5.5 Users / Team Tab

Contains two sub-tabs: **ACTIVE** and **INACTIVE**.

**Purpose:** Manage your team members.

**Team members are grouped by role:** Admin > Manager > Owner > Worker

**Each user card shows:**
- Avatar with role-colored background
- Name, email, phone
- Role badge
- Current project (if assigned)
- Status dot (green=active, gray=inactive)
- **Send Voice Note** button - Record and send a direct voice instruction to the user

**User management actions:**
- **Invite User** - Add new team member:
  - Enter full name, email, password (or add existing user by email)
  - Select role from available company roles
  - Set language preferences
  - Sends invite via edge function
- **Edit User** - Modify details and project assignment
- **Deactivate** - Temporarily disable access (preserves data, can be reactivated)
- **Activate** - Re-enable a deactivated user
- **Remove** - Permanently remove from company (irreversible, data preserved as "Former Member")
- **Manage Roles** - Configure company-wide role definitions

### 5.6 Voice Notes Feed

**Purpose:** Browse all voice notes across your company with filtering.

Access by tapping the **feed icon** in the Actions tab search bar. Opens as a full-screen view.

**Features:**
- Search across transcripts, sender names, and project names
- Filter by Site/Project or User
- Sort by Newest First or Oldest First
- Shows result count when searching

**Each voice note card shows:**
- Sender name and avatar
- Project name
- Audio player (play/pause, seek, duration)
- Transcript text
- Timestamp

**Actions on voice notes:**
- **Reply** - Record a voice reply (linked as child note)
- **Acknowledge** - Mark as reviewed
- **Add Note** - Attach a text annotation
- **Create Action** - Promote an update to an action item with category and priority selection

### 5.7 AI Confidence Calibration

A collapsible panel in the Actions tab showing weekly AI performance:

- **This Week** average confidence percentage (color-coded)
- **Trend** week-over-week change
- **Items** total processed
- **Distribution** stacked bar (High/Medium/Low confidence tiers)
- **Manager Feedback** counts: Confirmed, Dismissed, Promoted, Total

**Site Glossary Manager:**
- Add construction-specific terms with definitions per project
- Categories: Material, Brand, Tool, Process, Location, Role, General
- Terms are injected into AI prompts for improved accuracy

---

## 6. Owner Features

Owners access a 3-tab dashboard for project oversight and approvals.

### 6.1 Projects Tab

**Purpose:** View all projects you own.

Each project card shows:
- Project name, location, created date
- Action item statistics: pending, in progress, completed counts
- Tap to view project details

### 6.2 Approvals Tab

**Purpose:** Respond to escalated approval requests from managers.

**Filter options:** All, Pending, Approved, Denied, Deferred

**Each approval shows:**
- Title and description
- Amount (INR formatted)
- Category badge (Spending, Design Change, Material Change, Schedule Change, Other)
- Requested by (manager name)
- Created date
- Status badge

**Actions:**
- **Approve** - Accept the request (optional note)
- **Deny** - Reject the request (optional note)
- **Defer** - Postpone decision (optional note)

Badge on tab icon shows pending approval count.

### 6.3 Messages Tab

**Purpose:** Receive and send voice messages.

- View voice messages directed to you (filtered by project)
- Record and send voice replies back to managers/workers
- Badge shows unread message count

---

## 7. Super Admin Features

Accessible only to users in the super_admins table. Provides system-wide administration.

### 7.1 Companies Tab

- View all companies in the system
- Filter by status: Active, Inactive, Archived
- Each company shows: name, status badge, user count, created date
- **Deactivate** or **Archive** companies
- View company details: all users, projects, and statistics (voice note count, action item count)

### 7.2 Onboard Tab

**Purpose:** Create new companies with an initial admin user.

**Form fields:**
- Company Name (required)
- Admin Name (optional)
- Admin Email (required)
- Admin Password (required, min 6 characters)
- Transcription Provider: Groq (free), OpenAI (paid), Gemini
- Language Preferences: English + up to 2 Indian languages

Creates the company account, admin user, and initial associations via the `create-account-admin` edge function.

---

## 8. Voice Notes & AI Pipeline

### 8.1 Recording

- **Native (Android/iOS):** AAC .m4a format via the `record` package
- **Web (PWA):** WebM format via MediaRecorder API
- Microphone permission is requested before the first recording
- Audio is uploaded to the Supabase `voice-notes` storage bucket

### 8.2 Processing Pipeline

When a voice note is uploaded, it triggers an automated pipeline:

```
RECORDING -> UPLOAD -> ASR (Transcribe) -> TRANSLATE -> AI CLASSIFY -> ACTION ITEMS
                         |                    |              |
                    Status: processing   Status: transcribed  Status: completed
                                          Status: translated
```

**Phase 1 - Upload & Trigger:**
- Voice note record created with status `processing`
- Database trigger invokes the `transcribe-audio` edge function

**Phase 2 - Speech-to-Text (ASR):**
- Audio transcribed using the account's configured provider:
  - **Groq** (default) - Whisper Large v3, ~164x real-time speed
  - **OpenAI** - Whisper-1 API
  - **Gemini** - 1.5 Flash multimodal
- Construction domain context injected for accuracy (material terms, roles, processes)
- Language auto-detected from audio
- Status updates to `transcribed` (visible immediately on client)

**Phase 3 - Translation:**
- Non-English transcripts translated to English via LLM text translation
- Project-specific glossary terms preserved during translation
- Recent manager corrections used as few-shot examples for improved accuracy
- English notes skip this phase
- Status updates to `translated`

**Phase 4 - AI Classification:**
- Intent classified: action_required, approval, update, information
- Priority assigned: Low, Med, High, Critical
- Confidence score calculated (0.0 - 1.0)
- Structured data extracted:
  - **Materials:** name, quantity, unit, brand, delivery date, urgency
  - **Labor:** type, headcount, duration, start date, urgency
  - **Approvals:** type, amount, currency, due date
  - **Project events:** type, title, description, follow-up requirements

**Phase 5 - Action Item Creation:**
- Action items created when intent is actionable OR critical keywords detected OR it is a direct manager-to-worker note
- Assignment: directed to recipient (if set), worker's manager (if reports_to set), or first manager in account
- Confidence routing:
  - >= 85%: Auto-approved, no review needed
  - 70-84%: Created with `needs_review` flag
  - < 70%: Created with `flagged` status for manager attention

**Phase 6 - Safety Detection:**
- Critical keywords (injury, accident, collapse, fire, gas leak, etc.) trigger:
  - Red alert banner on manager dashboard
  - Force action item creation regardless of intent
  - Notification sent to manager immediately

### 8.3 Audio Player

Two platform-specific implementations:
- **Native (Android/iOS):** Uses `audioplayers` package
- **Web (PWA/Safari):** Uses HTML5 `<audio>` element via `dart:js_interop` (fixes known Safari issues)

Both provide: play/pause, seek slider, duration display, error handling with retry.

### 8.4 AI Self-Improvement

Manager corrections are recorded in the `ai_corrections` table:
- Summary edits, priority changes, category corrections
- Confirmed/dismissed AI suggestions
- Updates promoted to action items
- Denied requests with reasons

These corrections are fed back as few-shot examples in future AI classification prompts, creating a continuous improvement loop.

---

## 9. Finance Module

Access via the **Finance tab** (wallet icon) in the manager dashboard bottom navigation. Contains two sub-tabs.

### 9.1 Site Finances Sub-Tab

**Purpose:** Track invoices and payments for site operations.

#### Summary Bar
Four scrollable metric cards:
- **Total Invoiced** (blue) - Sum of all invoice amounts
- **Total Paid** (green) - Sum of all payments
- **Pending** (orange) - Invoices in draft/submitted/approved status
- **Overdue** (red) - Invoices past due date and unpaid

All amounts displayed in INR format (e.g., "Rs. 1,50,000").

#### View Toggle
Switch between **Invoices** view and **Payments** view with item counts.

#### Filters
- **Site filter** - All Sites or a specific project
- **Status filter** (Invoices only) - All, Draft, Submitted, Approved, Rejected, Paid, Overdue

#### Invoice Workflow

```
DRAFT ---> SUBMITTED ---> APPROVED ---> PAID
                    \---> REJECTED
                                   \---> OVERDUE (if past due date)
```

**Creating an invoice:**
1. Tap the **+** FAB and select "New Invoice"
2. Fill in: Invoice Number, Vendor, Amount, Site, Due Date (optional), Description, Notes
3. Toggle "Submit for approval immediately" to send directly for review
4. Tap "Save as Draft" or "Create & Submit"

**Invoice card (collapsed) shows:**
- Color indicator (status-based)
- Invoice number with # prefix
- Vendor name
- Amount (INR)
- Status badge (color-coded)
- Due date (red if overdue)
- Payment progress bar (if payments exist)

**Invoice card (expanded) shows:**
- Full description
- Submitted by name
- Rejection reason (if rejected)
- Notes
- Payment history (all linked payments with amounts, methods, dates)
- Action buttons: Submit (draft), Approve/Reject (submitted), Add Payment (approved)

**Managing invoices:**
- **Approve** - Changes status to "approved" with timestamp and approver recorded
- **Reject** - Requires a reason. Changes status to "rejected"
- **Add Payment** - Opens payment form pre-linked to this invoice

**Auto-paid detection:** When total payments linked to an invoice equal or exceed the invoice amount, the status automatically changes to "paid".

#### Adding Payments

1. Tap **+** FAB and select "Add Payment"
2. Fill in: Amount, Payment Method (Cash/Bank Transfer/UPI/Cheque/Other), Reference Number, Paid To, Site, Link to Invoice (optional), Payment Date, Description
3. Tap "Add Payment"

Payment methods supported: Cash, Bank Transfer, UPI, Cheque, Other.

### 9.2 Owner Finances Sub-Tab

**Purpose:** Track payments from owners and fund requests to owners.

#### Summary Row
Three metric boxes:
- **Total Received** (green) - Sum of all owner payments
- **Total Requested** (blue) - Sum of all fund requests
- **Pending** (orange) - Count of pending fund requests

#### Payments Received Section

Collapsible section showing all payments received from project owners.

**Recording an owner payment:**
1. Tap "Record" button in the section header
2. Fill in: Owner (dropdown), Amount, Payment Method, Reference Number, Allocate to Site (optional), Received Date, Description
3. Tap "Record Payment"

**Owner payment card shows:**
- Owner name with avatar
- Confirmation status badge (CONFIRMED / UNCONFIRMED)
- Allocated site
- Amount in green bold text
- Payment method badge
- Date and reference number
- **Confirm** button (for unconfirmed payments) - Records confirmer and timestamp

#### Fund Requests Section

Collapsible section showing all fund requests submitted to owners.

**Creating a fund request:**
1. Tap "New Request" button
2. Fill in: Title, Amount, Site, Owner (dropdown), Urgency (Low/Normal/High/Critical), Description
3. Tap "Submit Request"

**Fund request statuses:** Pending (orange), Approved (green), Denied (red), Partially Approved (blue)

**Fund request card (collapsed) shows:**
- Urgency indicator (colored left border)
- Title, urgency badge
- Project and owner names
- Amount and status badge
- Request date

**Fund request card (expanded) shows:**
- Full description
- Partially approved amount vs requested amount (if applicable)
- Owner's response text with response date

---

## 10. Attendance & Geofencing

### 10.1 Worker Check-In Flow

1. Worker taps **Check In** on the Attendance tab
2. App requests GPS location
3. Location is checked against the site's geofence center + radius
4. If within radius: Check-in recorded with distance from center
5. If outside radius: Warning shown; manager can grant override
6. If GPS denied/disabled: Prompt to enable; bypass available with manager approval

### 10.2 Worker Check-Out Flow

1. Worker taps **Check Out**
2. Check-out timestamp recorded
3. Optional daily report (voice or text) can be attached

### 10.3 Geofence Configuration

Each site can have a geofence defined by:
- **Center coordinates** (latitude/longitude) - Set using "Use Current Location" in site settings
- **Radius** - 50m to 500m (default 200m)
- **Buffer** - 20m additional tolerance to prevent boundary flip-flopping

### 10.4 Geofence Exemptions

Managers can mark specific workers as **geofence exempt**, allowing them to check in from any location. Exempt check-ins are marked with an "EXEMPT" badge in attendance records.

### 10.5 Manager Attendance View

Managers view attendance via the **ATTENDANCE** sub-tab in Sites:
- Date picker for any date
- Site filter dropdown
- Summary metrics: unique workers, total check-ins, currently on-site
- Detailed cards with times, durations, GPS distances, and report types

---

## 11. Multi-Company Support

### How It Works

- Users can belong to **multiple companies** with different roles in each
- A singleton `CompanyContextService` manages the active company context
- Company selection is persisted across sessions

### Company Selection Priority

1. Previously saved preference
2. Primary company flag
3. First active company

### Switching Companies

Tap the **swap icon** in the dashboard app bar (only shown when you belong to multiple companies). This navigates back to the Company Selector Screen where all your companies are listed with:
- Company name
- Role badge (color-coded by role)
- Primary company star indicator

### Data Isolation

All data queries are scoped to the active `account_id`. Row-Level Security (RLS) policies ensure users can only access data within their company.

---

## 12. Real-Time Features

SiteVoice uses Supabase Realtime (PostgreSQL Change Data Capture) for live updates across the app:

| Feature | What Updates in Real-Time |
|---------|--------------------------|
| **Action Items** | New actions, status changes, and priority updates appear instantly |
| **Voice Notes** | Progressive transcript display as processing completes |
| **Critical Alerts** | Safety alerts appear on manager dashboard immediately |
| **Daily Tasks** | Worker's task list updates when items are assigned or modified |
| **Invoices** | New invoices and status changes sync across devices |
| **Payments** | Payment records appear without manual refresh |
| **Owner Payments** | Owner payment confirmations update live |
| **Fund Requests** | Request status changes reflected immediately |
| **Attendance** | Check-in/check-out events visible to managers in real-time |

All lists support **pull-to-refresh** for manual data reload.

---

## 13. Supported Languages

SiteVoice supports automatic speech recognition and translation for **22+ languages**:

| Language | Code | ASR | Translation |
|----------|------|-----|-------------|
| English | en | Yes | Native |
| Hindi | hi | Yes | Yes |
| Telugu | te | Yes | Yes |
| Tamil | ta | Yes | Yes |
| Kannada | kn | Yes | Yes |
| Marathi | mr | Yes | Yes |
| Gujarati | gu | Yes | Yes |
| Punjabi | pa | Yes | Yes |
| Malayalam | ml | Yes | Yes |
| Bengali | bn | Yes | Yes |
| Urdu | ur | Yes | Yes |
| Assamese | as | Yes | Yes |
| Odia | or | Yes | Yes |
| Konkani | kok | Yes | Yes |
| Maithili | mai | Yes | Yes |
| Sindhi | sd | Yes | Yes |
| Nepali | ne | Yes | Yes |
| Sanskrit | sa | Yes | Yes |
| Dogri | doi | Yes | Yes |
| Manipuri | mni | Yes | Yes |
| Santali | sat | Yes | Yes |
| Kashmiri | ks | Yes | Yes |
| Bodo | bo | Yes | Yes |

Workers can record in any supported language. The system automatically detects the language, transcribes in the original language, and translates to English for manager review.

---

## 14. Technical Architecture

### Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) - single codebase for Android, iOS, Web |
| **Backend** | Supabase (PostgreSQL 15, Auth, Edge Functions, Storage, Realtime) |
| **AI/ASR** | Groq (Whisper Large v3), OpenAI (Whisper-1), Google Gemini (1.5 Flash) |
| **LLM** | Groq (Llama 3.3 70B), OpenAI (GPT-4o-mini), Gemini (1.5 Flash) |
| **PWA Hosting** | Firebase Hosting |
| **Storage** | Supabase Storage (voice-notes, proof-photos, invoice-attachments buckets) |

### Key Database Tables

| Table | Purpose |
|-------|---------|
| `accounts` | Company accounts with transcription provider settings |
| `users` | User profiles with role, language, and geofence settings |
| `user_company_associations` | Multi-company membership with role and status |
| `projects` | Construction sites with geofence coordinates |
| `project_owners` | Owner-to-project linkage |
| `voice_notes` | All voice recordings with processing status and transcripts |
| `action_items` | Tasks with lifecycle status, priority, and interaction history |
| `owner_approvals` | Escalated approval requests for project owners |
| `attendance` | Worker check-in/check-out records with GPS data |
| `invoices` | Invoice records with approval workflow |
| `payments` | Payment records linked to invoices |
| `owner_payments` | Payments received from project owners |
| `fund_requests` | Fund requests submitted to project owners |
| `notifications` | Real-time notification records |
| `ai_corrections` | Manager feedback for AI self-improvement |
| `site_glossary` | Project-specific construction terminology |

### Security

- **Row-Level Security (RLS)** on all tables - users can only access data within their company
- **Supabase Auth** with email/password authentication
- **Edge Functions** for sensitive operations (user creation, account onboarding)
- **Multi-tenant isolation** via `account_id` scoping on all queries

### Performance

- **Voice note processing:** 4-8 seconds end-to-end (recording to completed action item)
- **Single audio download:** Audio is downloaded once and reused across ASR/analysis phases
- **Parallel database writes:** All structured data insertions run via Promise.all()
- **Progressive UI updates:** Transcripts and statuses appear as each processing phase completes
- **Realtime subscriptions:** Changes propagate to all connected clients within seconds

---

*SiteVoice - Turning voices into actions on the construction site.*
