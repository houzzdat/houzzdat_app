# SiteVoice: Decision & Requirements Log

**Document purpose**: Single source of truth for all finalized UX/UI workflow decisions, confidence-tier handling, and implementation requirements.
**Last updated**: 2026-02-07

---

## Table of Contents

1. [Decision Matrix: Workflow & Card UI Selections](#1-decision-matrix)
2. [Confidence Tier System (70% Accuracy Baseline)](#2-confidence-tier-system)
3. [Message Type Workflows (3 Types)](#3-message-type-workflows)
4. [Message Card UI: Two-Tier Card](#4-message-card-ui)
5. [Manager Actionable Inbox](#5-manager-actionable-inbox)
6. [Message Workflow: Worker Voice Note Submission](#6-worker-voice-note-submission)
7. [Message Workflow: AI Processing Pipeline](#7-ai-processing-pipeline)
8. [Message Workflow: Manager-to-Worker Instructions](#8-manager-to-worker-instructions)
9. [Message Workflow: Worker Reply Flow](#9-worker-reply-flow)
10. [Message Workflow: Manager-to-Owner Escalation](#10-manager-to-owner-escalation)
11. [Message Workflow: Owner Response](#11-owner-response)
12. [Message Workflow: Proof-of-Work Gate](#12-proof-of-work-gate)
13. [Notification & Delivery System](#13-notification--delivery-system)
14. [Validation Gates Summary](#14-validation-gates-summary)
15. [Visual Design System](#15-visual-design-system)
16. [Data Model Requirements](#16-data-model-requirements)
17. [State Machines](#17-state-machines)
18. [Current State vs. Target State](#18-current-state-vs-target-state)
19. [Open Questions & Future Decisions](#19-open-questions)

---

## 1. Decision Matrix: Workflow & Card UI Selections

**Date decided**: 2026-02-07

### 1.1 Message Type Workflow Picks

For each of the 3 message types, multiple options were evaluated. The selected option balances information density, manager cognitive load, and construction-site realities.

| Message Type | Options Considered | Selected | Rationale |
|---|---|---|---|
| **Regular Update** | A: Auto-ACK with Smart Digest, B: Inline Feed Action, **C: Ambient Updates** | **Option C** | Reduces noise — most updates don't need action items. Feed-only with optional promotion. |
| **Approval Request** | **A: Structured Approval Card**, B: Tiered Approval with Auto-Escalation, C: Approval Queue | **Option A** | Managers need clear extracted data (amounts, materials, requester). Budget-aware escalation deferred to Phase 2. |
| **Critical Condition** | **A: Red Alert Banner**, B: Escalation Timer + Action Chain, C: Incident Mode | **Option A** | Immediate visibility via persistent banner without overengineering. Escalation timers and incident model deferred to Phase 2. |

### 1.2 Card UI Pick

| Option | Description | Selected |
|---|---|---|
| A: Enhanced Current Card | Minimal change — add color bar, time badge, progress dots | No |
| **B: Two-Tier Card** | Collapsed summary + expanded detail (accordion) | **Yes** |
| C: Unified Inbox Card | Merge Feed + Actions into single stream | No |

**Rationale**: Two-Tier Card provides the best balance of information density vs. scanability. Managers see the critical info (priority, summary, sender, actions) at a glance in the collapsed state, and expand only when they need full context.

### 1.3 Options Evaluated but Deferred

| Option | Deferred To | Why |
|---|---|---|
| Auto-Escalation on budget threshold (Approval Option B) | Phase 2 | Requires configurable budget limits per project — not MVP |
| SLA timers on approval cards (Approval Option B) | Phase 2 | Needs backend scheduler / cron job infrastructure |
| Incident Mode (Critical Option C) | Phase 3 | Separate `incidents` table + timeline UI is significant scope |
| Unified Inbox (Card Option C) | Re-evaluate after MVP feedback | Merging Feed + Actions is a big UX shift; test current model first |

---

## 2. Confidence Tier System

**Decision**: At 70% baseline AI accuracy, the system uses asymmetric risk-based thresholds per action category. False negatives on critical items are more dangerous than false positives.

### 1.1 Three-Tier Confidence Bands

| Band | Confidence | Visual Treatment | Auto-Action |
|------|-----------|-----------------|-------------|
| HIGH | >= 85% | Solid card, no qualifier | Auto-surface, standard workflow |
| MEDIUM | 70 - 84% | Amber border + "AI-suggested" label | Surface with confirmation gate |
| LOW | < 70% | Muted/greyed, collapsed | Flag for manual review only |

### 1.2 Category-Specific Thresholds

| Category | Action Item Created? | Auto-Surface | Auto-Act | Suppression | Rationale |
|----------|---------------------|-------------|---------|-------------|-----------|
| **Update** | NO (Ambient — Feed only) | Feed tab at any confidence | ACK inline in feed | < 50% shows "AI-suggested" label | Low stakes; no inbox noise; optional promotion to action item |
| **Approval** | YES | >= 70% | NEVER auto-act | < 50% flagged for review | High stakes; false approval request wastes owner trust |
| **Action Required** | YES | >= 70% | >= 85% | < 50% flagged for review | Medium stakes; manager reviews before delegating |
| **Critical / Safety** | YES (always) | ALWAYS (any %) | NEVER auto-act | NEVER suppress | Safety items must always surface; false negatives are dangerous |

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

## 3. Message Type Workflows (3 Types)

### 3.1 Regular Update — Ambient Updates (Option C)

**Decision**: Updates do NOT create action items. They appear only in the Feed tab as informational entries. Managers can optionally promote an update to an action item if follow-up is needed.

**Rationale**: Most updates are FYI. Creating action items for every update floods the manager's inbox with items that don't need action, increasing cognitive load and burying the items that matter.

#### Flow

```
Worker records voice note
  -> AI classifies as intent: update
  -> Voice note appears in Feed tab with "UPDATE" badge (green)
  -> NO action_item created
  -> Manager sees it in the feed while browsing
  -> Options on the feed card:
     [ACK]           -> Marks as acknowledged (green checkmark overlay)
     [ADD NOTE]      -> Appends a text note to the voice note
     [CREATE ACTION] -> Promotes to action_item (manager picks category + priority)
```

#### UX Spec

| Element | Spec |
|---------|------|
| Feed card badge | Green "UPDATE" chip, top-right |
| Acknowledged state | Green checkmark overlay on card, card dims slightly |
| ACK button | Outlined green, inline on card (not in a bottom sheet) |
| ADD NOTE button | Outlined blue, inline on card |
| CREATE ACTION button | Text-only, in overflow menu `[...]` |
| Unacknowledged indicator | Subtle blue dot (left of timestamp), no urgency escalation |
| Auto-cleanup | Unacknowledged updates older than 7 days move to "Archived" in feed |

#### Impact on Existing System

- Edge function: when `intent == 'update'`, skip `action_items` INSERT entirely
- Feed tab: add ACK / ADD NOTE buttons directly on VoiceNoteCard
- Actions tab: no longer shows "Updates" section (reduces noise)
- Confidence routing: updates below 70% confidence still appear in feed but with "AI-suggested" label

---

### 3.2 Approval Request — Structured Approval Card (Option A)

**Decision**: Approval requests surface as structured cards in the Actions tab with extracted details (amount, category, requester, project) displayed inline. Manager sees all decision-relevant data without expanding.

#### Flow

```
Worker records voice note
  -> AI classifies as intent: approval
  -> AI extracts: category, estimated_amount, materials/items mentioned
  -> Action item created with category = 'approval'
  -> Structured Approval Card appears in Actions tab
  -> Manager sees extracted details inline
  -> Manager taps:
     [APPROVE]           -> status = approved, records interaction
     [APPROVE WITH NOTE] -> modal for condition text, then status = approved
     [DENY]              -> mandatory reason (text or voice), status = denied
```

#### Structured Approval Card Layout

```
+------------------------------------------------------+
| ▓▓ APPROVAL REQUEST                         3h ago   |
| ▓▓                                                   |
| ▓▓ "Need to purchase 50 bags cement for Floor 3"     |
| ▓▓                                                   |
| ▓▓  Category:   Material Purchase                    |
| ▓▓  Estimated:  [amount from AI extraction]          |
| ▓▓  Requested:  Rajesh (Site Engineer)               |
| ▓▓  Project:    Tower B, Floor 3                     |
| ▓▓                                                   |
| ▓▓ [APPROVE]  [APPROVE WITH NOTE]  [DENY]    [···]  |
+------------------------------------------------------+
  Left border: 4px Warning Orange (0xFFFF9800)
```

#### UX Spec

| Element | Spec |
|---------|------|
| Card border | 4px left, Warning Orange `0xFFFF9800` |
| Category field | Pulled from `voice_note_approvals.approval_type` |
| Estimated amount | Pulled from `voice_note_approvals.estimated_cost` or AI extraction; "Not specified" if absent |
| APPROVE button | Solid green `0xFF4CAF50`, `Icons.check` |
| APPROVE WITH NOTE | Outlined green, `Icons.check_circle_outline` |
| DENY button | Outlined red `0xFFD32F2F`, `Icons.close` |
| Deny reason | Required — modal with TextField + optional voice recording |
| "APPROVE WITH NOTE" modal | TextField with hint: "Add condition (e.g., use brand X instead)" |
| Confidence < 85% | Amber "AI-suggested" chip above extracted fields; shows raw transcript in expandable |
| Overflow menu `[···]` | Priority, Escalate to Owner, Forward, Stakeholder Trail |

#### Impact on Existing System

- ActionCardWidget: new structured layout variant for `category == 'approval'`
- New button: "APPROVE WITH NOTE" (currently only APPROVE exists)
- Extracted data: read from `voice_note_approvals` and `voice_note_material_requests` tables
- DENY: enforce mandatory reason (currently optional in some code paths)

---

### 3.3 Critical Condition — Red Alert Banner (Option A)

**Decision**: Critical items (action_required + high/critical priority OR safety keyword detected at any confidence) get a persistent red banner at the top of the manager dashboard, above all tabs. Banner stays until the item is acted on.

#### Flow

```
Worker records voice note about urgent site issue
  -> AI classifies as action_required + priority high/critical
     OR safety keywords detected at any confidence level
  -> Action item created with is_critical_flag = true
  -> RED ALERT BANNER appears at top of ManagerDashboard (above TabBar)
  -> Banner persists across all tabs until acted on
  -> Manager taps:
     [VIEW]          -> Scrolls/navigates to the full action card in Actions tab
     [INSTRUCT NOW]  -> Opens InstructVoiceDialog immediately
  -> After first action taken, banner dismisses
  -> Action item continues normal workflow in Actions tab
```

#### Red Alert Banner Layout

```
+------------------------------------------------------+
| [red bg]  CRITICAL: Water pipe burst on Floor 7      |
|           reported 12m ago                            |
|           [VIEW]  [INSTRUCT NOW]              [×]    |
+------------------------------------------------------+
```

#### UX Spec

| Element | Spec |
|---------|------|
| Banner position | Fixed at top of ManagerDashboard scaffold, above TabBar |
| Banner background | Gradient: `0xFFD32F2F` -> `0xFFB71C1C` (deep red) |
| Banner text | White, 14sp bold for title, 12sp normal for timestamp |
| Banner height | 72dp (compact, doesn't obscure too much content) |
| VIEW button | Outlined white, navigates to action card |
| INSTRUCT NOW button | Solid white with red text, opens InstructVoiceDialog |
| Dismiss [x] | Only visible AFTER an action is taken (cannot dismiss without acting) |
| Multiple criticals | Stack banners (max 3 visible, "+N more" for overflow) |
| Time badge | Live-updating relative time ("12m ago", "2h ago") |
| Animation | Slide-in from top on creation, subtle pulse every 30s if unacted |
| Sound | System alert sound on first appearance (respects device silent mode) |
| Notification | Push notification (type: `critical_detected`) sent to manager immediately |

#### Impact on Existing System

- ManagerDashboard: add banner overlay widget (both classic and kanban layouts)
- Edge function: set `is_critical_flag = true` when conditions met
- NotificationService: new `critical_detected` type with urgent priority
- Actions tab: critical cards also appear in normal flow with red-amber gradient (banner is supplementary)

---

## 4. Message Card UI: Two-Tier Card (Option B)

**Decision**: All action cards in the manager's Actions tab use a two-tier layout — collapsed for scanning, expanded for detail. Only one card can be expanded at a time (accordion behavior).

### 4.1 Collapsed State (List View)

The collapsed state shows everything the manager needs to decide whether to act or skip.

```
+--+----------------------------------------+
|▓▓| HIGH   APPROVAL              3h ago    |
|▓▓| Purchase 50 bags cement — [amount]     |
|▓▓| Rajesh · Tower B                       |
|▓▓| [APPROVE] [INQUIRE] [DENY]      [···]  |
+--+----------------------------------------+
```

**Layout rules**:
- Left color bar (4px): priority color (red = high, orange = med, green = low)
- **Line 1**: Priority pill + Category pill + relative time (right-aligned)
- **Line 2**: AI summary (truncated to 2 lines max, 15-word cap from AI)
- **Line 3**: Sender avatar (24px circle) + sender name + project badge
- **Line 4**: Primary action buttons (contextual per category) + overflow `[···]`

### 4.2 Expanded State (On Tap)

Tapping anywhere on the collapsed card (except buttons) expands to show full detail.

```
+--+----------------------------------------+
|▓▓| HIGH   APPROVAL              3h ago    |
|▓▓| Purchase 50 bags cement — [amount]     |
|▓▓| Rajesh · Tower B                       |
|▓▓|                                        |
|▓▓| [Audio Player: ▶ ━━━━━━━━━━ 1:23]     |
|▓▓|                                        |
|▓▓| Full transcription text here with all  |
|▓▓| language sections and translations...  |
|▓▓|                                        |
|▓▓| AI Analysis:                           |
|▓▓|  Category: Material Purchase           |
|▓▓|  Estimated: [amount]                   |
|▓▓|  Confidence: 78% [━━━━━━━━░░]         |
|▓▓|                                        |
|▓▓| Extracted Data:                        |
|▓▓|  Materials: 50 bags cement (OPC 53)    |
|▓▓|  Labor: —                              |
|▓▓|                                        |
|▓▓| [Proof photo thumbnail, if any]        |
|▓▓|                                        |
|▓▓| Stakeholder Trail (last 3):            |
|▓▓|  · Created by Rajesh — 3h ago         |
|▓▓|  · Forwarded to Suresh — 1h ago       |
|▓▓|  [View full trail]                     |
|▓▓|                                        |
|▓▓| [APPROVE] [INQUIRE] [DENY]      [···]  |
+--+----------------------------------------+
```

**Expanded sections** (in order):
1. Audio player (play/pause, seek bar, duration)
2. Full transcription (with language badges and translations)
3. AI analysis box (category, extracted amounts, confidence bar)
4. Extracted data (materials, labor — from extraction tables)
5. Proof photo thumbnail (if `proof_photo_url` exists, tap for full-size)
6. Mini stakeholder trail (last 3 interactions inline, "View full trail" link)
7. Action buttons (repeated at bottom for easy access)

### 4.3 Category-Specific Collapsed Cards

**Action Required**:
```
+--+----------------------------------------+
|▓▓| HIGH   ACTION REQUIRED       45m ago   |
|▓▓| Rebar delivery delayed, need alternate  |
|▓▓| Vikram · Site Alpha                     |
|▓▓| [INSTRUCT] [FORWARD] [RESOLVE]  [···]  |
+--+----------------------------------------+
  Left border: Error Red (0xFFD32F2F)
```

**Approval**:
```
+--+----------------------------------------+
|▓▓| MED    APPROVAL              3h ago    |
|▓▓| Purchase 50 bags cement — [amount]     |
|▓▓| Rajesh · Tower B                       |
|▓▓| [APPROVE] [APPROVE+NOTE] [DENY] [···]  |
+--+----------------------------------------+
  Left border: Warning Orange (0xFFFF9800)
```

**Needs Review** (medium/low confidence):
```
+--+----------------------------------------+
|░░| —      NEEDS REVIEW          1h ago    |
|░░| [AI-suggested] Possible material req.  |
|░░| Amit · Tower A                         |
|░░| [CONFIRM] [EDIT] [DISMISS]      [···]  |
+--+----------------------------------------+
  Left border: Grey (0xFFBDBDBD)
  Background: Light amber (0xFFFFF8E1)
```

### 4.4 Accordion Behavior

| Rule | Spec |
|------|------|
| Default state | All cards collapsed |
| Expand trigger | Tap card body (not action buttons) |
| Collapse trigger | Tap expanded card header, or tap a different card |
| Max expanded | 1 at a time (expanding one collapses the previous) |
| Animation | 200ms ease-in-out height transition |
| Scroll behavior | Auto-scroll so expanded card's top aligns with viewport top |
| Action buttons | Always visible in both states (collapsed bottom, expanded bottom) |

### 4.5 Card Dimensions

| Element | Collapsed | Expanded |
|---------|-----------|----------|
| Card height | ~96dp (4 lines) | Variable (content-dependent) |
| Left border | 4px wide, full height | 4px wide, full height |
| Card padding | 12dp horizontal, 8dp vertical | 16dp horizontal, 12dp vertical |
| Card margin | 4dp bottom | 8dp bottom |
| Card elevation | 1dp | 3dp (lifted feel when expanded) |
| Card radius | 8dp | 8dp |

### 4.6 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Card model | Two-tier (collapsed/expanded) | Best density-to-detail ratio |
| Accordion limit | 1 expanded at a time | Prevents scroll explosion |
| Actions in collapsed | Yes (primary buttons visible) | Manager can act without expanding |
| Actions in expanded | Repeated at bottom | Don't force scroll back up |
| Confidence bar | Expanded state only (inside AI analysis box) | Keep collapsed state clean |
| Sender avatar | 24px circle with initials | Adds human context without taking space |
| Time display | Relative ("3h ago") in collapsed, absolute in expanded | Relative for scanning, absolute for audit |

---

## 5. Manager Actionable Inbox

**Status**: Implemented (classic + kanban). Needs message type workflow integration + two-tier card.

### 5.1 Inbox Layout (Finalized)

**Classic view** (ActionsTab):
```
[Red Alert Banner — critical items, persistent above tabs]

[Filter bar: Status | Priority | Category | Needs Review]
  |
  +-- Section: Approvals (orange header, pinned at top)
  |     Structured Approval Cards (two-tier)
  |     Badge: "3 pending approvals"
  |
  +-- Section: Action Required (red header)
  |     Action cards (two-tier) with INSTRUCT/FORWARD/RESOLVE
  |
  +-- Section: Flagged for Review (grey header, collapsed by default)
        Low-confidence items requiring manual triage
        Badge: count of items
```

**Key change**: Updates section is REMOVED from Actions tab. Updates live in Feed tab only.

**Kanban view** (ActionsKanbanTab):
```
Queue (pending) | Active (in_progress) | Verifying (proof) | Logs (completed)
```
- Kanban only shows approval + action_required items (no updates)
- Two-tier cards apply in kanban columns too

### 5.2 Section Ordering

| Position | Section | Why |
|---|---|---|
| Banner (above tabs) | Critical alerts | Must be seen first, cannot be missed |
| 1st section | Approvals | Financial/schedule decisions block work; FIFO order (oldest first) |
| 2nd section | Action Required | Operational items needing delegation |
| Collapsed | Flagged for Review | Low-confidence items; don't clutter main view |

### 5.3 Action Buttons per Category

| Category | Primary Buttons | Overflow Menu |
|----------|----------------|---------------|
| **approval** | APPROVE, APPROVE WITH NOTE, DENY | Priority, Escalate to Owner, Forward, Stakeholder Trail |
| **action_required** | INSTRUCT, FORWARD, RESOLVE | Priority, Escalate to Owner, Stakeholder Trail |
| **needs_review** | CONFIRM, EDIT, DISMISS | View Raw Transcript, Priority |

### 5.4 Needs Review Flow

When manager taps a `needs_review` card:

```
Card expands to show:
  - AI-generated summary (amber background section)
  - Raw transcript (white background, below summary)
  - Audio player (replay original)
  - Confidence score bar with percentage
  - Three actions:
    CONFIRM -> removes needs_review flag, enters standard workflow
    EDIT    -> allows manager to rewrite summary, then confirms
    DISMISS -> soft-delete (archived, not destroyed)
```

---

## 6. Worker Voice Note Submission

**Status**: Implemented (with modifications needed for validation gate)

### 6.1 Flow

```
Worker opens My Logs tab
  -> Taps 100px mic circle (Accent Amber)
  -> Circle turns red, timer appears (MM:SS)
  -> Taps again to stop
  -> "Processing..." state (spinner replaces mic)
  -> Card appears in feed below with status: processing
  -> Edge function completes -> card updates to: completed
```

### 6.2 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Recording trigger | Single tap to start, single tap to stop | Simpler than hold-to-record for workers with gloves |
| Max recording length | No hard limit (soft warning at 5 min) | Field conditions vary; don't cut off mid-thought |
| Recording feedback | Red pulsing border + timer | Clear "I am recording" state for noisy environments |
| Post-record action | Auto-upload, no preview | Minimize steps; validation gate handles review |
| Duplicate prevention | Disable mic during upload | Prevent accidental double-submissions |
| Error recovery | Toast with "Retry" action | Network failures common on-site |

### 6.3 Validation Gate (Phase 1 Requirement)

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

## 7. AI Processing Pipeline

**Status**: Implemented in `supabase/Functions/transcribe-audio/index.ts`

### 7.1 Pipeline Phases

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
         -> Apply confidence routing (see section 2.2)
Phase 7: Update voice note status to completed
```

### 7.2 Confidence Routing Logic

Add to Phase 6 of the edge function:

```
IF intent == 'update':
  -> DO NOT create action_item (Ambient Updates decision — Section 3.1)
  -> Voice note appears in Feed tab only
  -> Skip to Phase 7

IF intent == 'information':
  -> DO NOT create action_item
  -> Skip to Phase 7

IF critical_keywords_detected (ANY confidence, ANY intent):
  -> OVERRIDE: Create action_item with needs_review = true, priority = 'high'
  -> Set is_critical_flag = true
  -> Create notification for assigned manager immediately (type: critical_detected)
  -> RED ALERT BANNER triggered on ManagerDashboard (Section 3.3)
  -> Continue to confidence routing below

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
```

**Note**: Critical keyword detection takes precedence over the update/information skip. A voice note classified as "update" but containing "fire" or "collapse" WILL create an action item with critical flag.

### 7.3 Critical Keywords List

```
injury, injured, hurt, accident, collapse, collapsed, falling, fell,
fire, smoke, gas, leak, leaking, flood, flooding, electrocution,
emergency, unsafe, danger, dangerous, hazard, crack, structural
```

---

## 8. Manager-to-Worker Instructions

**Status**: Implemented via InstructVoiceDialog

### 8.1 Flow

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

### 8.2 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Dialog type | Fullscreen (not bottom sheet) | Gives manager space, prevents accidental dismissal |
| Context display | Show original action summary in card | Manager needs context while recording |
| Re-record option | Yes, unlimited retakes | Let managers get instruction right |
| Preview before send | No audio preview | Speed over perfection for instructions |
| Confirmation on send | No extra confirmation | Single "Send" button is clear enough |
| Instruction transcription | Yes, processed by same pipeline | Creates audit trail of what was instructed |

---

## 9. Worker Reply Flow

**Status**: Implemented via LogCard "RECORD REPLY" button

### 9.1 Flow

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

### 9.2 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Reply trigger | Inline button (not separate screen) | Workers stay in context |
| Threading display | Nested under parent (indented, connected line) | Visual hierarchy shows conversation flow |
| Reply badge | Blue "REPLY" chip on card | Distinguishes replies from new notes |
| Auto-close action | No | Manager decides when to resolve |
| Reply notification | Passive (feed update, no push) | Avoid notification fatigue; manager checks feed |

---

## 10. Manager-to-Owner Escalation

**Status**: Implemented via secondary actions menu

### 10.1 Flow

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

### 10.2 Confidence Gate

**Decision**: Escalations of medium-confidence items require manager confirmation.

```
IF action_item.needs_review = true AND not yet confirmed:
  -> Block escalation
  -> Show dialog: "This item has not been reviewed.
     Confirm the AI summary before escalating to the owner."
  -> Manager must CONFIRM first, then escalate
```

This prevents unverified AI output from reaching the owner.

### 10.3 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Escalation trigger | Secondary menu (not primary button) | Escalation is infrequent; keep primary actions clean |
| Category selection | Required, modal dialog | Owner needs context; prevents untagged escalations |
| Amount field | Optional, shown if category = spending | Only relevant for cost-related decisions |
| Owner notification | Push notification (NEW - currently missing) | Owners don't check app frequently |
| Escalation of unreviewed items | Blocked until confirmed | Protect owner from low-confidence AI output |

---

## 11. Owner Response

**Status**: Implemented via OwnerApprovalsTab

### 11.1 Flow

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

### 11.2 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Approval response | Optional text | Don't force owner to type for simple approvals |
| Denial reason | Required text | Manager needs to understand why it was denied |
| Defer option | Supported (status = deferred) | Owner may need time to decide |
| Multi-note | Cumulative append with `---` separator | Preserves conversation history |
| Notify manager | Push notification on response (NEW) | Manager needs timely feedback |
| Card after response | Dims, shows response, status badge | Clear visual that it's been handled |

---

## 12. Proof-of-Work Gate

**Status**: Implemented (DB trigger + partial UI)

### 12.1 Flow

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

### 12.2 DB Enforcement

```sql
-- Trigger: enforce_proof_gate()
IF NEW.status = 'completed'
   AND NEW.requires_proof = true
   AND (NEW.proof_photo_url IS NULL OR '')
THEN RAISE EXCEPTION 'Cannot complete: proof required'
```

### 12.3 UX Decisions (Finalized)

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

## 13. Notification & Delivery System

**Status**: Implemented (realtime via Supabase). Gaps in owner notifications.

### 13.1 Notification Types

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

### 13.2 Delivery Mechanisms

| Channel | Status | Notes |
|---------|--------|-------|
| In-app badge (bell icon) | Implemented | Realtime count via stream |
| In-app notification list | Implemented | Tap to navigate to reference |
| Push notification (mobile) | Not implemented | Phase 2 priority |
| Push notification (web) | Not implemented | Phase 2 priority |
| Email digest | Not implemented | Phase 3 |

### 13.3 Read Receipt Flow

```
Notification created -> badge count increments (realtime)
  -> User taps bell icon -> notification list opens
  -> User taps notification -> markAsRead(id), navigates to reference
  -> Badge count decrements
  -> is_read = true, read_at = timestamp
```

### 13.4 UX Decisions (Finalized)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Badge location | Bell icon in app bar | Standard pattern, always visible |
| Badge max display | "9+" for counts > 9 | Prevent visual overflow |
| Notification grouping | By type, newest first | Easy scan |
| Auto-dismiss | Never | User must explicitly read |
| Critical notification | Banner at top of screen + sound | Safety items can't wait |
| Notification retention | 30 days | Prevent table bloat |

---

## 14. Validation Gates Summary

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

## 15. Visual Design System

### 15.1 Color Palette

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

### 15.2 Confidence-Specific Colors

| Band | Border | Background | Badge |
|------|--------|------------|-------|
| HIGH (>=85%) | None (standard card) | White | None |
| MEDIUM (70-84%) | 4px left amber `0xFFFF9800` | `0xFFFFF8E1` (light amber) | "AI-suggested" amber chip |
| LOW (<70%) | 4px left grey `0xFFBDBDBD` | `0xFFF5F5F5` (light grey) | "Flagged" grey chip |
| CRITICAL | 4px left red gradient | `0xFFFFF3E0` (light orange-red) | "CRITICAL" red chip, pulsing |

### 15.3 Red Alert Banner Colors

| Element | Spec |
|---------|------|
| Banner background | Gradient: `0xFFD32F2F` -> `0xFFB71C1C` |
| Banner text | White `0xFFFFFFFF`, 14sp bold title, 12sp normal subtitle |
| VIEW button | Outlined white border, white text |
| INSTRUCT NOW button | Solid white `0xFFFFFFFF` bg, red `0xFFD32F2F` text |
| Banner height | 72dp |
| Banner animation | Slide-in from top, subtle pulse every 30s if unacted |

### 15.4 Two-Tier Card Colors

| State | Elevation | Background | Border |
|-------|-----------|------------|--------|
| Collapsed | 1dp | White `0xFFFFFFFF` | 4px left = priority color |
| Expanded | 3dp | White `0xFFFFFFFF` | 4px left = priority color |
| Needs Review (collapsed) | 1dp | Light amber `0xFFFFF8E1` | 4px left grey `0xFFBDBDBD` |

### 15.5 Status Badge Colors

| Status | Background | Text |
|--------|-----------|------|
| pending | `0xFFEEEEEE` | `0xFF757575` |
| in_progress | `0xFFE3F2FD` | `0xFF0066CC` |
| verifying | `0xFFFFF3E0` | `0xFFFF9800` |
| completed | `0xFFE8F5E9` | `0xFF4CAF50` |
| needs_review | `0xFFFFF8E1` | `0xFFFF9800` |
| flagged | `0xFFFCE4EC` | `0xFFD32F2F` |

### 15.6 Category Badge Colors

| Category | Color | Icon |
|----------|-------|------|
| action_required | Error Red | `Icons.build` |
| approval | Warning Orange | `Icons.gavel` |
| update | Success Green | `Icons.info_outline` |
| critical | Error Red + pulse | `Icons.warning` |

### 15.7 Priority Indicators

| Priority | Color | Icon |
|----------|-------|------|
| high | Error Red | `Icons.priority_high` |
| med | Warning Orange | `Icons.remove` |
| low | Success Green | `Icons.low_priority` |

### 15.8 Typography

- Card title: 16sp, `FontWeight.w600`, Primary text color
- Card body: 14sp, `FontWeight.w400`, Primary text color
- Caption/timestamp: 12sp, `FontWeight.w400`, Secondary text color
- Badge text: 11sp, `FontWeight.w700`, UPPERCASE
- Button text: 14sp, `FontWeight.w600`, UPPERCASE

---

## 16. Data Model Requirements

### 16.1 New Fields on `action_items` (for confidence routing)

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

### 16.2 Existing Tables (No Changes Needed)

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

### 16.3 Indexes Required

```sql
CREATE INDEX IF NOT EXISTS idx_action_items_needs_review
  ON action_items(needs_review) WHERE needs_review = true;

CREATE INDEX IF NOT EXISTS idx_action_items_review_status
  ON action_items(review_status) WHERE review_status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_action_items_is_critical
  ON action_items(is_critical_flag) WHERE is_critical_flag = true;
```

---

## 17. State Machines

### 17.1 Voice Note Lifecycle

```
recording -> uploading -> processing -> completed -> (validated | rejected)
                                           |
                                           +-> failed (on error)
```

### 17.2 Action Item Lifecycle

**Note**: Updates do NOT enter this lifecycle (Ambient Updates — Feed only).

```
                         +-> completed (direct resolve)
                         |
pending -> in_progress -> verifying -> completed (verified)
   |           |              |
   |           |              +-> in_progress (proof rejected)
   |           |
   |           +-> completed (no proof required)
   |
   +-> pending_review (if needs_review = true)
          |
          +-> confirmed -> (re-enters standard flow as pending)
          +-> dismissed -> (archived)
```

### 17.5 Update (Ambient) Lifecycle

```
Voice note classified as 'update'
  -> Appears in Feed tab (no action_item created)
  -> Manager ACKs in feed -> green checkmark overlay
  -> OR Manager taps "Create Action" -> promoted to action_item
     -> Enters Action Item Lifecycle above at 'pending'
  -> Unacknowledged after 7 days -> auto-archived
```

### 17.6 Critical Condition Lifecycle

```
Voice note triggers critical flag (safety keywords OR high priority)
  -> Action item created with is_critical_flag = true
  -> RED ALERT BANNER appears on ManagerDashboard
  -> Banner persists until first action taken:
     [VIEW]          -> Navigates to card in Actions tab
     [INSTRUCT NOW]  -> Opens InstructVoiceDialog directly
  -> After action: banner dismisses, item continues normal lifecycle
  -> If unacknowledged after 5 min: push notification re-sent
```

### 17.3 Owner Approval Lifecycle

```
pending -> approved
        -> denied
        -> deferred -> pending (re-opened)
```

### 17.4 Validation Gate Lifecycle

```
pending_validation -> validated (worker confirms)
                   -> rejected (worker discards)
```

---

## 18. Current State vs. Target State

| Feature | Current State | Target State | Priority |
|---------|--------------|-------------|----------|
| Voice recording + upload | Done | Done | - |
| ASR transcription | Done (3 providers) | Done | - |
| AI classification | Done | Add confidence routing | P0 |
| Action item creation | Done (creates for all intents) | Skip creation for updates (Ambient); add needs_review, confidence_score | P0 |
| **Ambient Updates (Feed-only)** | Updates create action_items | Updates appear in Feed tab only; ACK/NOTE inline; "Create Action" promotion | P0 |
| **Structured Approval Card** | Basic approval card | Structured layout with extracted amounts, category, APPROVE WITH NOTE | P0 |
| **Red Alert Banner** | Critical items mixed in actions list | Persistent red banner above tabs on ManagerDashboard | P0 |
| **Two-Tier Card UI** | Single expandable card | Collapsed (4-line) + Expanded (full detail) with accordion | P0 |
| Manager inbox (classic) | Done | Remove Updates section; pin Approvals; add Flagged for Review | P0 |
| Manager inbox (kanban) | Done | Filter to approval + action_required only; add two-tier cards | P1 |
| INSTRUCT flow | Done | Done | - |
| FORWARD flow | Done | Done | - |
| Worker reply | Done | Done | - |
| Owner escalation | Done | Block unreviewed items, add notification | P0 |
| Owner response | Done | Add push notification to manager | P1 |
| Proof-of-work gate | Done (DB + partial UI) | Complete UI wiring | P1 |
| Validation gate | DB schema done | Build Flutter UI (banner on card) | P1 |
| Notification system | Done (in-app) | Add push notifications, critical_detected type | P1 |
| Transcription edit lock | Done (one-edit) | Done | - |
| Edit history JSONB | Schema done | Wire Flutter append logic | P2 |
| Stakeholder trail | Done | Done | - |
| transcript_raw immutability | Schema done | Update edge function to write it | P2 |
| Critical keyword detection | Not started | Add to edge function + trigger is_critical_flag | P0 |
| Geofence attendance | Done | Done | - |
| Confidence bar widget | Not started | Build reusable widget (expanded state only) | P0 |
| Feed tab ACK/NOTE buttons | Not available on feed cards | Add inline ACK, ADD NOTE, CREATE ACTION buttons on VoiceNoteCard | P0 |

---

## 19. Open Questions

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
