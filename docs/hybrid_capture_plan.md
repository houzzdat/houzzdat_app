# Hybrid Message-to-Data Capture with Dedup Review Queue

## Context

Stakeholders (workers, site engineers, purchase managers) send voice notes to managers. The existing AI pipeline transcribes, classifies, and routes voice notes to domain agents (material, finance, project_state) that auto-create records. However, there's no way for senders to hint what their message is about (reducing AI ambiguity), no deduplication across voice notes, and no consolidated manager review queue for auto-created records.

**Goal:** Add an optional quick-tag after recording to boost AI accuracy, implement semantic deduplication to prevent duplicate records from multiple reporters, and build a manager review queue to confirm/dismiss auto-created entries.

---

## Part 1: Database Migration

**New file:** `supabase/Migrations/20260220_hybrid_capture_dedup.sql`

### 1a. Add `user_declared_intent` to `voice_notes`
```sql
ALTER TABLE voice_notes
  ADD COLUMN IF NOT EXISTS user_declared_intent text
  CHECK (user_declared_intent IN (
    'material_received', 'payment_made', 'stage_complete', 'general_update'
  ));
```

### 1a-ii. Add `quick_tag_enabled` to `users` table
```sql
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS quick_tag_enabled boolean DEFAULT NULL;
```
- `NULL` = use account-level default (see below)
- `true` = always show quick-tag for this user
- `false` = never show quick-tag for this user

### 1a-iii. Add `quick_tag_default` to `accounts` table
```sql
ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS quick_tag_default boolean DEFAULT true;
```
- Account-level default. If a user's `quick_tag_enabled` is NULL, this value applies.
- Admin can set this per-company (e.g., default ON for engineering firms, OFF for labour-heavy crews).

**Resolution logic (Flutter side):**
```
effective = user.quick_tag_enabled ?? account.quick_tag_default ?? true
```

### 1b. Add dedup columns to `material_specs`
```sql
ALTER TABLE material_specs
  ADD COLUMN IF NOT EXISTS source_event_hash text,
  ADD COLUMN IF NOT EXISTS possible_duplicate_of uuid REFERENCES material_specs(id),
  ADD COLUMN IF NOT EXISTS completeness_status text DEFAULT 'complete'
    CHECK (completeness_status IN ('complete', 'incomplete')),
  ADD COLUMN IF NOT EXISTS missing_fields text[] DEFAULT '{}';

CREATE INDEX idx_material_specs_event_hash ON material_specs(source_event_hash)
  WHERE source_event_hash IS NOT NULL;
CREATE INDEX idx_material_specs_needs_confirm ON material_specs(project_id, needs_confirmation)
  WHERE needs_confirmation = true;
```

### 1c. Add dedup columns to `payments`
```sql
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS source_event_hash text,
  ADD COLUMN IF NOT EXISTS possible_duplicate_of uuid REFERENCES payments(id),
  ADD COLUMN IF NOT EXISTS completeness_status text DEFAULT 'complete'
    CHECK (completeness_status IN ('complete', 'incomplete')),
  ADD COLUMN IF NOT EXISTS missing_fields text[] DEFAULT '{}';

CREATE INDEX idx_payments_event_hash ON payments(source_event_hash)
  WHERE source_event_hash IS NOT NULL;
CREATE INDEX idx_payments_needs_confirm ON payments(project_id, needs_confirmation)
  WHERE needs_confirmation = true;
```

### 1d. Add dedup columns to `invoices`
```sql
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS source_event_hash text,
  ADD COLUMN IF NOT EXISTS possible_duplicate_of uuid REFERENCES invoices(id);

CREATE INDEX idx_invoices_event_hash ON invoices(source_event_hash)
  WHERE source_event_hash IS NOT NULL;
```

### 1e. Add review tracking columns to `finance_transactions`
```sql
ALTER TABLE finance_transactions
  ADD COLUMN IF NOT EXISTS possible_duplicate_of uuid REFERENCES finance_transactions(id),
  ADD COLUMN IF NOT EXISTS source_event_hash text;
```

### 1f. Milestone dedup (lightweight)
```sql
ALTER TABLE project_milestones
  ADD COLUMN IF NOT EXISTS last_updated_by_voice_note uuid REFERENCES voice_notes(id);
```

---

## Part 2: Quick-Tag UI (Flutter)

### 2a. New widget: `lib/features/voice_notes/widgets/quick_tag_overlay.dart`

A bottom sheet or inline overlay shown **after** voice note upload completes. Shows 4 tappable chips:

```
[📦 Material Received]  [💰 Payment Made]  [✅ Stage Complete]  [💬 Just an Update]
```

- Appears for 5 seconds with auto-dismiss (or tap to dismiss)
- On tap: updates `voice_notes.user_declared_intent` via Supabase
- On dismiss/timeout: no update (AI-only pipeline proceeds as before)
- Minimal, non-blocking — a suggestion, not a requirement
- **Only shown if quick-tag is enabled for this user** (see 2d below)

### 2a-ii. Admin toggle for quick-tag per user

**Where:** Manager's Team tab already lists team members. Add a toggle per user.

**File:** `lib/features/dashboard/tabs/team_tab.dart` (or the user detail/edit screen)

- Each team member card gets a "Quick-Tag" toggle switch (only visible to admin/manager)
- Toggle writes to `users.quick_tag_enabled` (true/false)
- A separate account-level toggle in Settings (the existing settings sheet) controls `accounts.quick_tag_default`

**UX for admin:**
- In Team tab → tap a user → see "Quick-Tag Enabled" toggle
- In Settings sheet → "Quick-Tag Default for New Users" toggle
- Suggested defaults: ON for roles like site_engineer, purchase_manager; OFF for roles like worker (but admin can override per-user)

### 2b. Modify `AudioRecorderService.uploadAudio()`
**File:** `lib/core/services/audio_recorder_service.dart`

- Change return type from `Future<String?>` (URL) to `Future<Map<String, String>?>` returning `{id: voice_note_id, url: audio_url}`
- The voice note ID is needed to write `user_declared_intent` back after tag selection

### 2c. Modify recording flows to show quick-tag (conditionally)
**Files to update:**
- `lib/features/dashboard/screens/manager_dashboard_classic.dart` — `_handleProjectNote()` (line 171-213)
- `lib/features/worker/screens/construction_home_screen.dart` — `_handleRecording()`

After successful upload:
1. Check `effective_quick_tag_enabled` for current user (fetched at init, cached in state)
2. If enabled: show `QuickTagOverlay` with the returned voice note ID
3. If disabled: skip overlay, show only the existing "Voice note submitted" snackbar

### 2d. Quick-tag eligibility check
**File:** Add to init logic in both dashboard screens

At screen initialization, fetch the user's effective quick-tag setting:
```dart
final quickTagEnabled = userData['quick_tag_enabled']
    ?? accountData['quick_tag_default']
    ?? true;
```
Cache this in widget state. The overlay widget receives it as a parameter and simply doesn't render if `false`.

---

## Part 3: Enhanced Domain Routing (Agent Layer)

### 3a. Modify `sitevoice-agents/src/lib/utils/domain-router.ts`

In `determineDomains()`:
- Accept `userDeclaredIntent` as optional parameter
- If set, **always include** the matching domain with boosted confidence (+0.2, capped at 1.0):
  - `material_received` → material domain
  - `payment_made` → finance domain
  - `stage_complete` → project_state domain
  - `general_update` → no boost, normal routing
- Existing keyword/structured-data routing still runs (user intent is additive, not exclusive)

### 3b. Modify `sitevoice-agents/src/lib/agents/orchestrator.ts`

- Fetch `user_declared_intent` from voice_notes alongside existing data
- Pass it through to `determineDomains()` and into `AgentInput`

### 3c. Update `AgentInput` type in `sitevoice-agents/src/lib/agents/types.ts`
- Add `userDeclaredIntent?: string` field

---

## Part 4: Semantic Deduplication (Agent Layer)

### 4a. Shared dedup utility: `sitevoice-agents/src/lib/utils/dedup.ts`

```typescript
// Compute event hash for cross-voice-note dedup
function computeEventHash(params: {
  projectId: string;
  normalizedEntity: string; // material name or vendor, lowercased/trimmed
  dateBucket: string;       // YYYY-MM-DD
  quantityBucket?: string;  // rounded to nearest 10% bucket
}): string

// Check for potential duplicates in a table
async function findPotentialDuplicate(supabase, params: {
  table: string;
  projectId: string;
  eventHash: string;
  windowHours: number; // 24 for materials, 72 for payments
}): Promise<string | null> // returns existing record ID or null
```

### 4b. Modify Material Agent (`material-agent.ts`)

Before inserting into `material_specs`:
1. Compute `source_event_hash` = hash(projectId + normalized material name + today's date + quantity bucket)
2. Query `material_specs` for same `source_event_hash` created in last 24h
3. If match found: set `possible_duplicate_of` = existing record ID
4. Check completeness: if quantity or vendor is null, set `completeness_status = 'incomplete'`, `missing_fields = ['quantity', 'vendor']`
5. Insert record with all dedup/completeness metadata

### 4c. Modify Finance Agent (`finance-agent.ts`)

Before inserting payments/invoices:
1. Compute `source_event_hash` = hash(projectId + normalized vendor + date + amount bucket rounded to nearest 1000)
2. Query for same hash in last 72h
3. If match: set `possible_duplicate_of`
4. Check completeness: if amount is null or vendor is missing

### 4d. Modify Project State Agent (`project-state-agent.ts`)

Before updating milestones:
1. Check if `last_updated_by_voice_note` was set within last 24h for the same milestone + same status transition
2. If so, skip the update and log as 'skipped' with reason 'duplicate_milestone_update'

---

## Part 5: Manager Review Queue (Flutter)

The review queue lives as a **4th tab inside the existing Insights screen** (`lib/features/insights/screens/insights_screen.dart`), which currently has 3 tabs: PROJECT HEALTH, FINANCES, MATERIALS. Adding a "REVIEW" tab keeps all AI-generated intelligence in one place.

### 5a. Modify Insights screen to add Review tab
**File:** `lib/features/insights/screens/insights_screen.dart`

- Change `TabController(length: 3, ...)` → `TabController(length: 4, ...)`
- Add 4th tab: `Tab(text: 'REVIEW')` with a badge count overlay
- Add 4th `TabBarView` child: `_buildReviewTab()`
- Lazy-load review data when tab is selected (same pattern as other tabs)

### 5b. New widget: `lib/features/insights/widgets/review_tab_content.dart`

Content for the REVIEW tab. Internally has 3 filter chips: **All | Materials | Payments | Progress**

Queries records where `needs_confirmation = true` OR `possible_duplicate_of IS NOT NULL`, ordered by `created_at DESC`.

### 5c. New widget: `lib/features/insights/widgets/review_card.dart`

Each card shows:
- **Badge:** "AI Created" (blue) or "Possible Duplicate" (amber) or "Incomplete" (red)
- **Extracted data:** material/amount/vendor/milestone details
- **Source:** Playable voice note audio + transcript snippet
- **Confidence:** Score bar (green >0.8, yellow 0.6-0.8, red <0.6)
- **If duplicate:** Side-by-side comparison with suspected original
- **Actions:**
  - **Confirm** → sets `needs_confirmation = false`, clears `possible_duplicate_of`
  - **Edit & Confirm** → opens edit form, then confirms
  - **Merge** (duplicates only) → keeps original, deletes this record, logs correction
  - **Dismiss** → deletes record, creates `ai_corrections` entry for feedback

### 5d. Badge count on Insights icon (manager dashboard)
**File:** `lib/features/dashboard/screens/manager_dashboard_classic.dart`

- The existing Insights icon in the AppBar (line 331-340) gets a badge overlay showing total unreviewed count
- Tapping still opens InsightsScreen, but now with the Review tab available

### 5e. New service: `lib/features/insights/services/review_queue_service.dart`

Methods:
- `getUnreviewedCount(accountId)` → int (for badge on Insights icon)
- `getItemsForReview(accountId, {domain?, projectId?})` → List (combined query across tables)
- `confirmRecord(table, id)` → void
- `dismissRecord(table, id, correctionType)` → void (+ ai_corrections insert)
- `mergeRecords(table, keepId, deleteId)` → void

---

## Part 6: Files to Modify (Summary)

| File | Change |
|------|--------|
| `supabase/Migrations/20260220_hybrid_capture_dedup.sql` | **NEW** - All schema changes |
| `lib/core/services/audio_recorder_service.dart` | Return voice note ID from `uploadAudio` |
| `lib/features/voice_notes/widgets/quick_tag_overlay.dart` | **NEW** - Quick-tag UI widget |
| `lib/features/dashboard/screens/manager_dashboard_classic.dart` | Show quick-tag conditionally after recording; add badge to Insights icon |
| `lib/features/worker/screens/construction_home_screen.dart` | Show quick-tag conditionally after recording |
| `lib/features/dashboard/tabs/team_tab.dart` | Add per-user quick-tag toggle for admin/manager |
| `sitevoice-agents/src/lib/agents/types.ts` | Add `userDeclaredIntent` to AgentInput |
| `sitevoice-agents/src/lib/utils/domain-router.ts` | Accept and apply user intent boost |
| `sitevoice-agents/src/lib/agents/orchestrator.ts` | Fetch and pass user_declared_intent |
| `sitevoice-agents/src/lib/utils/dedup.ts` | **NEW** - Shared dedup utilities |
| `sitevoice-agents/src/lib/agents/material-agent.ts` | Add dedup + completeness checks before insert |
| `sitevoice-agents/src/lib/agents/finance-agent.ts` | Add dedup + completeness checks before insert |
| `sitevoice-agents/src/lib/agents/project-state-agent.ts` | Add milestone dedup check |
| `lib/features/insights/screens/insights_screen.dart` | Add 4th "REVIEW" tab |
| `lib/features/insights/widgets/review_tab_content.dart` | **NEW** - Review tab content with domain filters |
| `lib/features/insights/widgets/review_card.dart` | **NEW** - Review card widget |
| `lib/features/insights/services/review_queue_service.dart` | **NEW** - Review queue data service |

---

## Verification Plan

1. **Migration:** Run `20260220_hybrid_capture_dedup.sql` against Supabase, verify columns added (including `quick_tag_enabled` on users, `quick_tag_default` on accounts)
2. **Quick-tag (enabled user):** Log in as a user with quick_tag_enabled=true → record a voice note → verify quick-tag overlay appears → tap "Material Received" → verify `user_declared_intent` is set in DB
3. **Quick-tag (disabled user):** Log in as a user with quick_tag_enabled=false → record a voice note → verify quick-tag does NOT appear, only the normal snackbar shows
4. **Quick-tag (admin toggle):** Log in as manager → go to Team tab → toggle quick-tag off for a user → verify `users.quick_tag_enabled` updated in DB
5. **Intent boost:** Send a voice note with "payment_made" tag but ambiguous content → verify finance agent runs with boosted confidence
4. **Dedup:** Send two voice notes from different users about the same cement delivery → verify second creates `material_specs` with `possible_duplicate_of` pointing to first
5. **Incomplete records:** Send a voice note "cement came today" (no quantity) → verify `completeness_status = 'incomplete'` and `missing_fields = ['quantity', 'vendor']`
6. **Review queue:** Open Insights screen → go to REVIEW tab → verify items listed with correct badges → confirm/dismiss/merge and verify DB updates. Also verify badge count on Insights icon in manager dashboard AppBar.
7. **Feedback loop:** Dismiss a record → verify `ai_corrections` entry created with appropriate type
8. **Idempotency:** Reprocess same voice note → verify no duplicate agent_processing_log entries

---

## Rollout Approach

1. **Phase A (Migration + Agent changes):** Deploy DB migration and agent dedup logic. Existing pipeline works unchanged — dedup columns are all optional/nullable.
2. **Phase B (Quick-tag UI):** Deploy Flutter changes. Quick-tag is optional — users who ignore it get the same experience as before.
3. **Phase C (Review queue):** Deploy review queue screen. Start surfacing unreviewed records to managers.

Each phase is independently deployable and backward-compatible.
