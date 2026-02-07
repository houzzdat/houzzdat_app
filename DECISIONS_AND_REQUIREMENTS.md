# SiteVoice: Decision & Requirements Log

**Document purpose**: Single source of truth for all finalized UX/UI workflow decisions, confidence-tier handling, and implementation requirements.
**Last updated**: 2026-02-07

---

## Table of Contents

1. [Confidence Tier System (70% Accuracy Baseline)](#1-confidence-tier-system)
2. [Message Workflow: Worker Voice Note Submission](#2-worker-voice-note-submission)
3. [Message Workflow: AI Processing Pipeline](#3-ai-processing-pipeline)
4. [Message Workflow: Manager Actionable Inbox](#4-manager-actionable-inbox)
5. [Message Workflow: Manager-to-Worker Instructions](#5-manager-to-worker-instructions)
6. [Message Workflow: Worker Reply Flow](#6-worker-reply-flow)
7. [Message Workflow: Manager-to-Owner Escalation](#7-manager-to-owner-escalation)
8. [Message Workflow: Owner Response](#8-owner-response)
9. [Message Workflow: Proof-of-Work Gate](#9-proof-of-work-gate)
10. [Notification & Delivery System](#10-notification--delivery-system)
11. [Validation Gates Summary](#11-validation-gates-summary)
12. [Visual Design System](#12-visual-design-system)
13. [Data Model Requirements](#13-data-model-requirements)
14. [State Machines](#14-state-machines)
15. [Current State vs. Target State](#15-current-state-vs-target-state)
16. [Open Questions & Future Decisions](#16-open-questions)

---

## 1. Confidence Tier System

**Decision**: At 70% baseline AI accuracy, the system uses asymmetric risk-based thresholds per action category. False negatives on critical items are more dangerous than false positives.

### 1.1 Three-Tier Confidence Bands

| Band | Confidence | Visual Treatment | Auto-Action |
|------|-----------|-----------------|-------------|
| HIGH | >= 85% | Solid card, no qualifier | Auto-surface, standard workflow |
| MEDIUM | 70 - 84% | Amber border + "AI-suggested" label | Surface with confirmation gate |
| LOW | < 70% | Muted/greyed, collapsed | Flag for manual review only |

### 1.2 Category-Specific Thresholds

| Category | Auto-Surface | Auto-Act | Suppression | Rationale |
|----------|-------------|---------|-------------|-----------|
| **Update** | >= 70% | >= 85% | < 50% | Low stakes; worker can dismiss wrong update |
| **Approval** | >= 70% | NEVER auto-act | < 50% | High stakes; false approval request wastes owner trust |
| **Action Required** | >= 70% | >= 85% | < 50% | Medium stakes; manager reviews before delegating |
| **Critical / Safety** | ALWAYS (any %) | NEVER auto-act | NEVER suppress | Safety items must always surface; false negatives are dangerous |

### 1.3 Confidence Display Rules

- **HIGH band**: Show action card normally. No additional UI chrome.
- **MEDIUM band**: Show card with amber left border (4px). Display chip: "AI-suggested - Confirm or dismiss". Show raw transcript alongside AI summary in expandable section.
- **LOW band**: Collapse into "Flagged for Review" section at bottom of inbox. Badge count on section header. Manager must explicitly expand to see items.
- **Critical override**: If AI detects safety keywords (injury, collapse, fire, gas, emergency) at ANY confidence, surface immediately with red-amber gradient card. Push notification to manager if unacknowledged after 5 minutes.

### 1.4 Confidence Indicator Widget

Display on every action card:
- Horizontal bar (60px wide, 4px tall) in card footer
- Color: green (>=85%), amber (70-84%), grey (<70%)
- Tooltip on hover/long-press: "AI confidence: 78%"
- No numeric display by default (avoids information overload for field workers)

---

## 2. Worker Voice Note Submission

**Status**: Implemented (with modifications needed for validation gate)

### 2.1 Flow

```
Worker opens My Logs tab
  -> Taps 100px mic circle (Accent Amber)
  -> Circle turns red, timer appears (MM:SS)
  -> Taps again to stop
  -> "Processing..." state (spinner replaces mic)
  -> Card appears in feed below with status: processing
  -> Edge function completes -> card updates to: completed
```

### 2.2 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Recording trigger | Single tap to start, single tap to stop | Simpler than hold-to-record for workers with gloves |
| Max recording length | No hard limit (soft warning at 5 min) | Field conditions vary; don't cut off mid-thought |
| Recording feedback | Red pulsing border + timer | Clear "I am recording" state for noisy environments |
| Post-record action | Auto-upload, no preview | Minimize steps; validation gate handles review |
| Duplicate prevention | Disable mic during upload | Prevent accidental double-submissions |
| Error recovery | Toast with "Retry" action | Network failures common on-site |

### 2.3 Validation Gate (Phase 1 Requirement)

**Decision**: Workers get a one-time confirmation screen AFTER AI processing completes.

```
Voice note status: completed
  -> System shows validation prompt (inline, not modal)
  -> Worker sees: AI summary + category + original transcript
  -> Options: "Looks Good" (confirm) | "Edit Summary" (one-time) | "Discard"
  -> On confirm: validation_status = 'validated'
  -> On edit: worker_edited_summary saved, is_edited = true, validation locked
  -> On discard: validation_status = 'rejected', action item soft-deleted
```

**UI spec**:
- Validation prompt appears as an expandable banner on the VoiceNoteCard
- Banner background: `0xFFFFF8E1` (light amber)
- "Looks Good" button: solid green
- "Edit" button: outlined amber
- "Discard" button: text-only red, requires long-press confirmation
- After validation, banner collapses and shows green checkmark badge

---

## 3. AI Processing Pipeline

**Status**: Implemented in `supabase/Functions/transcribe-audio/index.ts`

### 3.1 Pipeline Phases

```
Phase 1: Fetch voice note record, validate not already processed
Phase 2: ASR transcription (Groq Whisper / OpenAI Whisper / Gemini)
         -> Capture asr_confidence score
Phase 3: Translation to English (if non-English detected)
         -> Use ai_prompts table for translation prompt
Phase 4: AI classification & summarization
         -> intent, priority, short_summary, detailed_summary
         -> confidence_score per extraction
Phase 5: Structured data extraction
         -> Materials, labor, approvals, project events
         -> Each entity gets its own confidence_score
Phase 6: Action item creation (if actionable)
         -> Apply confidence routing (NEW - see section 1.2)
Phase 7: Update voice note status to completed
```

### 3.2 Confidence Routing Logic (NEW)

Add to Phase 6 of the edge function:

```
IF intent == 'information' -> skip action item creation

IF confidence_score >= 0.85:
  -> Create action_item with needs_review = false
  -> Standard workflow applies

IF confidence_score >= 0.70 AND < 0.85:
  -> Create action_item with needs_review = true
  -> Set review_status = 'pending_review'

IF confidence_score < 0.70:
  -> Create action_item with needs_review = true
  -> Set review_status = 'flagged'
  -> Set status = 'pending' (do not auto-route)

IF critical_keywords_detected (ANY confidence):
  -> Create action_item with needs_review = true, priority = 'high'
  -> Create notification for assigned manager immediately
  -> Set is_critical_flag = true
```

### 3.3 Critical Keywords List

```
injury, injured, hurt, accident, collapse, collapsed, falling, fell,
fire, smoke, gas, leak, leaking, flood, flooding, electrocution,
emergency, unsafe, danger, dangerous, hazard, crack, structural
```

---

## 4. Manager Actionable Inbox

**Status**: Implemented (classic + kanban). Needs confidence tier integration.

### 4.1 Inbox Layout (Finalized)

**Classic view** (ActionsTab):
```
[Filter bar: Status | Priority | Category | Needs Review (NEW)]
  |
  +-- Section: Critical (red header, always expanded)
  |     Action cards with red-amber gradient (safety items)
  |
  +-- Section: Action Required (red header)
  |     Action cards with contextual buttons
  |
  +-- Section: Pending Approval (orange header)
  |     Action cards with Approve/Inquire/Deny
  |
  +-- Section: Updates (green header)
  |     Action cards with Ack/Note/Forward
  |
  +-- Section: Flagged for Review (grey header, collapsed by default)
        Low-confidence items requiring manual triage
        Badge: count of items
```

**Kanban view** (ActionsKanbanTab):
```
Queue (pending/validating) | Active (in_progress) | Verifying (proof) | Logs (completed)
```

### 4.2 Action Card UX (Finalized)

Each action card shows:

```
+-----------------------------------------------------+
| [Category badge]  [Priority dot]  [Confidence bar]  |
|                                                      |
| Short summary (bold, 15-word max)                    |
| "AI-suggested" chip (if needs_review = true)         |
|                                                      |
| [Expand: full transcript + audio player]             |
|                                                      |
| [Primary actions: contextual per category]           |
| [Secondary menu: priority, forward, escalate, trail] |
+-----------------------------------------------------+
```

### 4.3 Category-Specific Action Buttons

| Category | Primary Buttons | Secondary Actions |
|----------|----------------|-------------------|
| **action_required** | INSTRUCT, FORWARD, RESOLVE | Priority, Escalate, Stakeholder Trail |
| **approval** | APPROVE, INQUIRE, DENY | Priority, Escalate, Stakeholder Trail |
| **update** | ACK, ADD NOTE, FORWARD | Priority, Stakeholder Trail |
| **needs_review** (new) | CONFIRM, EDIT, DISMISS | View Raw Transcript, Priority |

### 4.4 Needs Review Flow (NEW)

When manager taps a `needs_review` card:

```
Card expands to show:
  - AI-generated summary (amber background)
  - Raw transcript (white background, side-by-side)
  - Audio player (replay original)
  - Three actions:
    CONFIRM -> removes needs_review flag, enters standard workflow
    EDIT    -> allows manager to rewrite summary, then confirms
    DISMISS -> soft-delete (archived, not destroyed)
```

---

## 5. Manager-to-Worker Instructions

**Status**: Implemented via InstructVoiceDialog

### 5.1 Flow

```
Manager taps INSTRUCT on action card
  -> Fullscreen InstructVoiceDialog opens
  -> Context card shows: original action summary + worker name
  -> Manager taps mic icon (80px, indigo)
  -> Icon turns red, timer shows
  -> Manager taps stop
  -> Options: Re-record (grey) | Send (green)
  -> On send:
     - Upload voice note with parentId = original voice note
     - Set recipientId = original worker
     - Update action_item: status = 'in_progress'
     - Store delegation_voice_note_id on action_item
     - Create notification: type 'action_instructed'
  -> Dialog closes, card status updates
```

### 5.2 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Dialog type | Fullscreen (not bottom sheet) | Gives manager space, prevents accidental dismissal |
| Context display | Show original action summary in card | Manager needs context while recording |
| Re-record option | Yes, unlimited retakes | Let managers get instruction right |
| Preview before send | No audio preview | Speed over perfection for instructions |
| Confirmation on send | No extra confirmation | Single "Send" button is clear enough |
| Instruction transcription | Yes, processed by same pipeline | Creates audit trail of what was instructed |

---

## 6. Worker Reply Flow

**Status**: Implemented via LogCard "RECORD REPLY" button

### 6.1 Flow

```
Worker sees instruction in My Logs tab (threaded under original)
  -> Instruction card shows REPLY badge (blue)
  -> Worker taps "RECORD REPLY"
  -> Inline recording starts (button turns red)
  -> Worker taps to stop
  -> Auto-upload with parentId = instruction voice note
  -> Edge function processes reply
  -> Reply appears threaded under instruction
  -> Action item remains in workflow (not auto-closed)
```

### 6.2 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Reply trigger | Inline button (not separate screen) | Workers stay in context |
| Threading display | Nested under parent (indented, connected line) | Visual hierarchy shows conversation flow |
| Reply badge | Blue "REPLY" chip on card | Distinguishes replies from new notes |
| Auto-close action | No | Manager decides when to resolve |
| Reply notification | Passive (feed update, no push) | Avoid notification fatigue; manager checks feed |

---

## 7. Manager-to-Owner Escalation

**Status**: Implemented via secondary actions menu

### 7.1 Flow

```
Manager taps secondary menu (burger icon) on action card
  -> Bottom sheet: "Escalate to Owner"
  -> Category selection dialog appears:
     [Spending]        - orange icon
     [Design Change]   - blue icon
     [Material Change] - indigo icon
     [Schedule Change] - red icon
     [Other]           - grey icon
  -> Manager selects category (required)
  -> System looks up project owner via project_owners table
  -> Creates owner_approvals record:
     - status: pending
     - Links to original action_item_id
  -> Records interaction: "escalated_to_owner"
  -> Notification sent to owner (type: 'escalated_to_owner')
```

### 7.2 Confidence Gate (NEW)

**Decision**: Escalations of medium-confidence items require manager confirmation.

```
IF action_item.needs_review = true AND not yet confirmed:
  -> Block escalation
  -> Show dialog: "This item has not been reviewed.
     Confirm the AI summary before escalating to the owner."
  -> Manager must CONFIRM first, then escalate
```

This prevents unverified AI output from reaching the owner.

### 7.3 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Escalation trigger | Secondary menu (not primary button) | Escalation is infrequent; keep primary actions clean |
| Category selection | Required, modal dialog | Owner needs context; prevents untagged escalations |
| Amount field | Optional, shown if category = spending | Only relevant for cost-related decisions |
| Owner notification | Push notification (NEW - currently missing) | Owners don't check app frequently |
| Escalation of unreviewed items | Blocked until confirmed | Protect owner from low-confidence AI output |

---

## 8. Owner Response

**Status**: Implemented via OwnerApprovalsTab

### 8.1 Flow

```
Owner opens Approvals tab
  -> Sees pending owner_approvals for their projects
  -> Each card shows:
     - Title + description
     - Category badge (colored)
     - Amount (if spending)
     - Requested by (manager name)
     - Project name
  -> Owner taps:
     APPROVE (green) -> optional response text -> status = approved
     ADD NOTE (blue)  -> appends to owner_response (cumulative)
     DENY (red)       -> required reason text -> status = denied
  -> System updates owner_approvals record
  -> Records interaction on linked action_item
  -> Notification sent to manager (type: 'owner_approval_response')
```

### 8.2 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Approval response | Optional text | Don't force owner to type for simple approvals |
| Denial reason | Required text | Manager needs to understand why it was denied |
| Defer option | Supported (status = deferred) | Owner may need time to decide |
| Multi-note | Cumulative append with `---` separator | Preserves conversation history |
| Notify manager | Push notification on response (NEW) | Manager needs timely feedback |
| Card after response | Dims, shows response, status badge | Clear visual that it's been handled |

---

## 9. Proof-of-Work Gate

**Status**: Implemented (DB trigger + partial UI)

### 9.1 Flow

```
Action item with category = action_required
  -> requires_proof auto-set to true
  -> Worker completes task on-site
  -> Taps "UPLOAD PROOF" button (blue, camera icon)
  -> Camera opens (native camera, not in-app)
  -> Photo captured -> uploaded to 'proof-photos' bucket
  -> Action item updated:
     - proof_photo_url = signed storage URL
     - status = 'verifying'
  -> Manager sees action in "Verifying" state
  -> Manager reviews:
     VERIFY & COMPLETE (green) -> status = completed
     REJECT (red)              -> status = in_progress, proof cleared
  -> Interaction recorded for each step
```

### 9.2 DB Enforcement

```sql
-- Trigger: enforce_proof_gate()
IF NEW.status = 'completed'
   AND NEW.requires_proof = true
   AND (NEW.proof_photo_url IS NULL OR '')
THEN RAISE EXCEPTION 'Cannot complete: proof required'
```

### 9.3 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Proof type | Photo only (no video) | Keeps uploads fast on-site |
| Capture method | Native camera (not in-app) | Better quality, familiar UX |
| Preview before upload | Yes (confirm/retake dialog) | Prevent blurry or wrong photos |
| Proof display | 200px thumbnail in expanded card | Manager can tap to view full-size |
| Rejection flow | Returns to in_progress, clears photo | Worker must re-upload |
| Proof for updates | Never required | Updates are informational only |
| Proof for approvals | Optional (manager discretion) | Not always applicable |

---

## 10. Notification & Delivery System

**Status**: Implemented (realtime via Supabase). Gaps in owner notifications.

### 10.1 Notification Types

| Type | Sender | Recipient | Trigger | Priority |
|------|--------|-----------|---------|----------|
| `action_instructed` | Manager | Worker | INSTRUCT action | Normal |
| `action_forwarded` | Manager | New assignee | FORWARD action | Normal |
| `proof_requested` | System | Worker | Action requires proof | Normal |
| `proof_uploaded` | Worker | Manager | Proof photo submitted | Normal |
| `status_changed` | System | Assignee | Action status transition | Normal |
| `owner_approval_response` | Owner | Manager | Owner approved/denied | High |
| `escalated_to_owner` | Manager | Owner | Escalation created | High |
| `note_added` | Any | Stakeholders | Note appended | Low |
| `critical_detected` (NEW) | System | Manager | Safety keyword at any confidence | Urgent |
| `review_needed` (NEW) | System | Manager | Medium-confidence item created | Normal |

### 10.2 Delivery Mechanisms

| Channel | Status | Notes |
|---------|--------|-------|
| In-app badge (bell icon) | Implemented | Realtime count via stream |
| In-app notification list | Implemented | Tap to navigate to reference |
| Push notification (mobile) | Not implemented | Phase 2 priority |
| Push notification (web) | Not implemented | Phase 2 priority |
| Email digest | Not implemented | Phase 3 |

### 10.3 Read Receipt Flow

```
Notification created -> badge count increments (realtime)
  -> User taps bell icon -> notification list opens
  -> User taps notification -> markAsRead(id), navigates to reference
  -> Badge count decrements
  -> is_read = true, read_at = timestamp
```

### 10.4 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Badge location | Bell icon in app bar | Standard pattern, always visible |
| Badge max display | "9+" for counts > 9 | Prevent visual overflow |
| Notification grouping | By type, newest first | Easy scan |
| Auto-dismiss | Never | User must explicitly read |
| Critical notification | Banner at top of screen + sound | Safety items can't wait |
| Notification retention | 30 days | Prevent table bloat |

---

## 11. Validation Gates Summary

All gates that block or require user action before proceeding:

| Gate | Who | When | Blocking? | Override |
|------|-----|------|-----------|----------|
| **Voice note validation** | Worker | After AI processing | Soft (auto-confirm after 24h) | None |
| **Transcription one-edit** | Worker | After first edit | Hard | None (by design) |
| **Proof-of-work** | Worker | Before completion | Hard (DB trigger) | Manager can waive via `requires_proof = false` |
| **Confidence review** | Manager | Medium/low confidence items | Soft (manager can skip) | Auto-confirm at 85%+ |
| **Escalation pre-review** | Manager | Before owner escalation | Hard | Must confirm first |
| **Geofence** | Worker | Attendance check-in | Soft (overridable) | `geofence_exempt = true` on user |
| **Owner approval** | Owner | Spending/design/schedule | Hard | Owner must respond |

---

## 12. Visual Design System

### 12.1 Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| Primary Indigo | `0xFF1A237E` | App bar, primary buttons, headings |
| Accent Amber | `0xFFFFCA28` | Recording button, highlights, accent |
| Background | `0xFFF5F7FA` | Screen background |
| Info Blue | `0xFF0066CC` | Links, informational badges |
| Success Green | `0xFF4CAF50` | Completed, approved, confirmed |
| Warning Orange | `0xFFFF9800` | Pending, medium confidence, edited |
| Error Red | `0xFFD32F2F` | Action required, denied, critical |
| Text Primary | `0xFF212121` | Body text |
| Text Secondary | `0xFF757575` | Captions, timestamps |
| Surface | `0xFFFFFFFF` | Card backgrounds |

### 12.2 Confidence-Specific Colors (NEW)

| Band | Border | Background | Badge |
|------|--------|------------|-------|
| HIGH (>=85%) | None (standard card) | White | None |
| MEDIUM (70-84%) | 4px left amber `0xFFFF9800` | `0xFFFFF8E1` (light amber) | "AI-suggested" amber chip |
| LOW (<70%) | 4px left grey `0xFFBDBDBD` | `0xFFF5F5F5` (light grey) | "Flagged" grey chip |
| CRITICAL | 4px left red gradient | `0xFFFFF3E0` (light orange-red) | "CRITICAL" red chip, pulsing |

### 12.3 Status Badge Colors

| Status | Background | Text |
|--------|-----------|------|
| pending | `0xFFEEEEEE` | `0xFF757575` |
| in_progress | `0xFFE3F2FD` | `0xFF0066CC` |
| verifying | `0xFFFFF3E0` | `0xFFFF9800` |
| completed | `0xFFE8F5E9` | `0xFF4CAF50` |
| needs_review | `0xFFFFF8E1` | `0xFFFF9800` |
| flagged | `0xFFFCE4EC` | `0xFFD32F2F` |

### 12.4 Category Badge Colors

| Category | Color | Icon |
|----------|-------|------|
| action_required | Error Red | `Icons.build` |
| approval | Warning Orange | `Icons.gavel` |
| update | Success Green | `Icons.info_outline` |
| critical | Error Red + pulse | `Icons.warning` |

### 12.5 Priority Indicators

| Priority | Color | Icon |
|----------|-------|------|
| high | Error Red | `Icons.priority_high` |
| med | Warning Orange | `Icons.remove` |
| low | Success Green | `Icons.low_priority` |

### 12.6 Typography

- Card title: 16sp, `FontWeight.w600`, Primary text color
- Card body: 14sp, `FontWeight.w400`, Primary text color
- Caption/timestamp: 12sp, `FontWeight.w400`, Secondary text color
- Badge text: 11sp, `FontWeight.w700`, UPPERCASE
- Button text: 14sp, `FontWeight.w600`, UPPERCASE

---

## 13. Data Model Requirements

### 13.1 New Fields on `action_items` (for confidence routing)

```sql
ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  confidence_score numeric DEFAULT NULL;

ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  needs_review boolean DEFAULT false;

ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  review_status text DEFAULT NULL
  CHECK (review_status IN ('pending_review', 'confirmed', 'dismissed', 'flagged'));

ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  reviewed_by uuid REFERENCES auth.users(id) DEFAULT NULL;

ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  reviewed_at timestamptz DEFAULT NULL;

ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  is_critical_flag boolean DEFAULT false;
```

### 13.2 Existing Tables (No Changes Needed)

| Table | Role in Workflows |
|-------|-------------------|
| `voice_notes` | Source of all messages; `parent_id` for threading |
| `action_items` | Manager inbox items; state machine + audit trail |
| `owner_approvals` | Owner escalation records |
| `notifications` | Delivery tracking with read receipts |
| `voice_note_ai_analysis` | AI confidence per analysis |
| `voice_note_edits` | Edit audit trail |
| `voice_note_forwards` | Forward tracking |
| `finance_transactions` | Spending verification |

### 13.3 Indexes Required

```sql
CREATE INDEX IF NOT EXISTS idx_action_items_needs_review
  ON action_items(needs_review) WHERE needs_review = true;

CREATE INDEX IF NOT EXISTS idx_action_items_review_status
  ON action_items(review_status) WHERE review_status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_action_items_is_critical
  ON action_items(is_critical_flag) WHERE is_critical_flag = true;
```

---

## 14. State Machines

### 14.1 Voice Note Lifecycle

```
recording -> uploading -> processing -> completed -> (validated | rejected)
                                           |
                                           +-> failed (on error)
```

### 14.2 Action Item Lifecycle

```
                         +-> completed (ACK, direct resolve)
                         |
pending -> in_progress -> verifying -> completed (verified)
   |           |              |
   |           |              +-> in_progress (proof rejected)
   |           |
   |           +-> completed (no proof required)
   |
   +-> pending_review (if needs_review = true, NEW)
          |
          +-> confirmed -> (re-enters standard flow as pending)
          +-> dismissed -> (archived)
```

### 14.3 Owner Approval Lifecycle

```
pending -> approved
        -> denied
        -> deferred -> pending (re-opened)
```

### 14.4 Validation Gate Lifecycle

```
pending_validation -> validated (worker confirms)
                   -> rejected (worker discards)
```

---

## 15. Current State vs. Target State

| Feature | Current State | Target State | Priority |
|---------|--------------|-------------|----------|
| Voice recording + upload | Done | Done | - |
| ASR transcription | Done (3 providers) | Done | - |
| AI classification | Done | Add confidence routing | P0 |
| Action item creation | Done | Add needs_review, confidence_score | P0 |
| Manager inbox (classic) | Done | Add confidence tier UI, review flow | P0 |
| Manager inbox (kanban) | Done | Add confidence indicators | P1 |
| INSTRUCT flow | Done | Done | - |
| FORWARD flow | Done | Done | - |
| Worker reply | Done | Done | - |
| Owner escalation | Done | Block unreviewed items, add notification | P0 |
| Owner response | Done | Add push notification to manager | P1 |
| Proof-of-work gate | Done (DB + partial UI) | Complete UI wiring | P1 |
| Validation gate | DB schema done | Build Flutter UI (banner on card) | P1 |
| Notification system | Done (in-app) | Add push notifications, critical alerts | P1 |
| Transcription edit lock | Done (one-edit) | Done | - |
| Edit history JSONB | Schema done | Wire Flutter append logic | P2 |
| Stakeholder trail | Done | Done | - |
| transcript_raw immutability | Schema done | Update edge function to write it | P2 |
| Critical keyword detection | Not started | Add to edge function Phase 4 | P0 |
| Geofence attendance | Done | Done | - |
| Confidence bar widget | Not started | Build reusable widget | P0 |

---

## 16. Open Questions

| # | Question | Options | Decision | Date |
|---|----------|---------|----------|------|
| 1 | Auto-confirm validation gate after timeout? | 24h auto-confirm vs. require explicit | TBD | - |
| 2 | Should low-confidence items create action_items at all? | Create as flagged vs. skip creation entirely | Create as flagged (preserve data) | 2026-02-07 |
| 3 | Push notification provider for mobile? | Firebase Cloud Messaging vs. OneSignal | TBD (FCM likely, Firebase already in stack) | - |
| 4 | Should workers see confidence scores? | Yes (transparency) vs. No (complexity) | No (managers only; workers see validated output) | 2026-02-07 |
| 5 | Notification retention period? | 7d / 30d / indefinite | 30 days (with export option later) | 2026-02-07 |
| 6 | Critical alert escalation chain? | Manager only vs. Manager + Owner | Manager first, auto-escalate to owner after 15 min | 2026-02-07 |
| 7 | Confidence threshold tuning? | Fixed vs. per-account configurable | Fixed for MVP, configurable in Phase 3 | 2026-02-07 |

---

## Appendix A: Interaction History Actions

All recorded `interaction_history` action types (JSONB array on `action_items`):

```
created, approved, denied, instructed, forwarded, resolved,
acknowledged, proof_uploaded, proof_rejected, note_added,
summary_edited, priority_changed, escalated_to_owner,
owner_approved, owner_denied, completed_and_logged,
review_confirmed (NEW), review_dismissed (NEW),
critical_acknowledged (NEW)
```

## Appendix B: File Reference

| File | Purpose |
|------|---------|
| `lib/features/worker/tabs/my_logs_tab.dart` | Worker recording + feed |
| `lib/features/worker/widgets/log_card.dart` | Worker voice note card + reply |
| `lib/features/dashboard/widgets/action_card_widget.dart` | Manager action card (1280+ lines) |
| `lib/features/dashboard/tabs/actions_tab.dart` | Manager inbox (classic) |
| `lib/features/dashboard/tabs/actions_kanban_tab.dart` | Manager inbox (kanban) |
| `lib/features/dashboard/widgets/instruct_voice_dialog.dart` | Instruction recording |
| `lib/features/owner/tabs/owner_approvals_tab.dart` | Owner approval screen |
| `lib/features/owner/widgets/owner_approval_card.dart` | Owner approval card |
| `lib/features/owner/tabs/owner_messages_tab.dart` | Owner messaging |
| `lib/features/voice_notes/widgets/voice_note_card.dart` | Voice note display |
| `lib/features/voice_notes/widgets/transcription_display.dart` | Transcript + edit lock |
| `lib/core/services/audio_recorder_service.dart` | Recording + upload |
| `lib/core/services/notification_service.dart` | Notification delivery |
| `lib/core/services/geofence_service.dart` | Location validation |
| `lib/core/theme/app_theme.dart` | Theme constants |
| `supabase/Functions/transcribe-audio/index.ts` | AI pipeline |
| `supabase/Migrations/` | Schema evolution |
