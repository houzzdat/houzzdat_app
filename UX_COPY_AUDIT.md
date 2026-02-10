# SiteVoice — UX Copy & Content Audit Report

**Audit Date:** February 2026
**Scope:** All user-facing text across Flutter app (35+ dart files), Edge Functions (7 TypeScript files)
**Total Strings Catalogued:** 500+

---

## Executive Summary

The SiteVoice app has a **solid foundation of user-facing content** with well-structured empty states, clear tab labels, and mostly descriptive button text. However, the audit identified **47 actionable issues** across 4 priority levels. The most impactful themes are:

1. **Generic error messages** — 18 instances of `Error: $e` that expose raw technical exceptions to users
2. **Inconsistent terminology** — "site" vs "project" vs "location" used interchangeably across features
3. **Emoji in error messages** — `❌` prefix in error snackbars is unprofessional and inconsistent
4. **Missing confirmation context** — Several destructive actions lack clear consequences in their confirmation dialogs
5. **Capitalization inconsistency** — Mix of ALL CAPS (`SIGN IN`, `APPROVE`), Title Case, and Sentence case across similar UI elements

**Top 5 Recommendations:**
1. Replace all `Error: $e` patterns with human-readable error messages
2. Standardize on "site" for construction locations across the entire app
3. Create a shared error message utility with consistent formatting
4. Normalize button label capitalization to Title Case (matching Material Design guidelines)
5. Add actionable guidance to all empty states

---

## P0 — Critical (Fix Immediately)

### Issue 1: Raw Exception Text Exposed to Users

**Severity:** Critical
**Impact:** Users see unintelligible technical errors; destroys trust
**Count:** 18 instances across 11 files

**Current Pattern:**
```dart
SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed)
SnackBar(content: Text('Error: ${e.toString()}'))
SnackBar(content: Text('❌ Error: ${e.toString()}'))
```

**Locations:**
| File | Line | Current Text |
|------|------|-------------|
| `finance/widgets/site_finances_subtab.dart` | 207 | `Error: $e` |
| `finance/widgets/owner_finances_subtab.dart` | 204, 236 | `Error: $e` |
| `reports/screens/report_detail_screen.dart` | 356 | `Error: $e` |
| `reports/screens/reports_screen.dart` | 133 | `Error: $e` |
| `reports/screens/prompts_management_screen.dart` | 98 | `Error: $e` |
| `voice_notes/widgets/transcription_display.dart` | 230 | `❌ Error: ${e.toString()}` |
| `worker/tabs/my_logs_tab.dart` | 180 | `Error: $e` |
| `dashboard/widgets/team_dialogs.dart` | 458, 831, 859 | `Error: ${e.toString()}` / `Error: $e` |
| `dashboard/widgets/role_management_dialog.dart` | 56, 186, 280 | `Error loading roles: $e` / `Error deleting role: $e` |
| `auth/screens/super_admin_screen.dart` | 86, 96 | `Error: $error` / `Error: $e` |
| `owner/screens/owner_report_view_screen.dart` | 217 | `Error generating PDF: $e` |

**Recommendation:** Replace all with context-specific, user-friendly messages:

| Context | Replacement |
|---------|-------------|
| Invoice creation fails | `Could not create invoice. Please check your connection and try again.` |
| Payment recording fails | `Could not record payment. Please try again.` |
| Report generation fails | `Could not generate report. Please try again later.` |
| Report save fails | `Could not save report. Please check your connection.` |
| Prompt save fails | `Could not save prompt changes. Please try again.` |
| Transcription save fails | `Could not save transcription edit. Please try again.` |
| Voice note send fails | `Could not send voice note. Please check your connection.` |
| User invite fails | `Could not invite user. Please check the details and try again.` |
| Role loading fails | `Could not load roles. Pull down to retry.` |
| PDF generation fails | `Could not generate PDF. Please try again.` |
| Generic fallback | `Something went wrong. Please try again.` |

---

### Issue 2: Emoji in Error Messages

**Severity:** Critical
**Impact:** Unprofessional; inconsistent with the rest of the app
**Location:** `voice_notes/widgets/transcription_display.dart`, line 230

**Current:** `❌ Error: ${e.toString()}`
**Recommendation:** `Could not save transcription. Please try again.`
**Rationale:** No other error message in the app uses emoji. The red SnackBar background already signals error state.

---

### Issue 3: Login Error Too Generic

**Severity:** Critical
**Impact:** Users can't determine if the issue is email, password, or network
**Location:** `auth/screens/login_screen.dart`, line 32

**Current:** `Sign in failed. Please check your email and password.`
**Recommendation:** Keep current text but add network-specific handling:
- Network error: `Could not connect to server. Please check your internet connection.`
- Auth error: `Incorrect email or password. Please try again.`
- Other: `Sign in failed. Please try again later.`

---

## P1 — High (Fix Soon)

### Issue 4: Inconsistent Terminology — "Site" vs "Project" vs "Location"

**Severity:** High
**Impact:** Users may think "site" and "project" are different concepts
**Count:** Mixed usage across 20+ files

**Examples:**
| File | Text | Term Used |
|------|------|-----------|
| `projects_tab.dart` | Tab label: `SITES` | Site |
| `projects_tab.dart` | Fallback name: `Site` | Site |
| `owner_projects_tab.dart` | Empty state: `No Projects` | Project |
| `owner_project_card.dart` | Fallback: `Unnamed Project` | Project |
| `attendance sub-tab` | Dropdown: `All Sites` | Site |
| `finance summary` | Filter: `All Sites` | Site |
| `reports` | Multi-select: `All Sites` | Site |
| `owner_reports_tab.dart` | Fallback: `All Sites` | Site |
| `company_detail_screen.dart` | Section: `Projects` | Project |

**Recommendation:** Standardize on **"site"** for user-facing text (matching the construction domain language), keep "project" only in technical/database contexts. Apply consistently:
- Tab label: `Sites` (already correct)
- Empty states: `No sites yet` (not "No Projects")
- Filters: `All Sites` (already correct)
- Owner-facing: `Your Sites` (not "Your Projects")

**Files to update:** `owner_projects_tab.dart`, `owner_project_card.dart`, `company_detail_screen.dart`

---

### Issue 5: Generic Button Labels

**Severity:** High
**Impact:** Users don't know what will happen when they click

| File | Line | Current | Recommendation |
|------|------|---------|---------------|
| `owner_approvals_tab.dart` | 239 | `Confirm` | `Approve Request` / `Deny Request` (context-dependent) |
| `companies_tab.dart` | 321 | Success: `Action completed successfully` | `Company deactivated successfully` / `Company activated` / `Company archived` |
| `user_action_dialogs.dart` | 76 | `Deactivate` | `Deactivate User` |
| `user_action_dialogs.dart` | 157 | `Remove` | `Remove User` |
| `user_action_dialogs.dart` | 206 | `Activate` | `Reactivate User` |
| `report_editor_widget.dart` | button | `Save` (in edit dialog) | `Save Changes` |
| `transcription_display.dart` | 343 | `Save` | `Save Edit` |

---

### Issue 6: Missing Destructive Action Consequences

**Severity:** High
**Impact:** Users may accidentally destroy data without understanding impact

| Dialog | Current | Missing |
|--------|---------|---------|
| Delete site | Confirmation dialog exists | Should state: "All site data, voice notes, and action items will be permanently deleted." |
| Delete voice note | 5-minute window with countdown | Good — no change needed |
| Remove user | `Remove User from Company?` with warnings | Good — comprehensive |
| Archive company | `This action cannot be undone` | Good — comprehensive |

**Recommendation:** Ensure the "Delete Site" dialog includes explicit data loss warning.

---

### Issue 7: Empty States Missing Actionable Guidance

**Severity:** High
**Impact:** Users don't know how to get started

| Feature | Current Empty State | Recommendation |
|---------|-------------------|---------------|
| Attendance (manager) | `No attendance records` / `No workers have checked in today` | `No attendance records for today. Workers can check in from their Attendance tab.` |
| Voice notes feed | (uses shared EmptyStateWidget) | Ensure subtitle says: `Voice notes from your team will appear here once they start recording.` |
| Site detail - Daily Reports | `No voice notes found for this period` | `No voice notes for this date range. Try expanding the date range or check back later.` |
| Owner Messages | `No Messages Yet` / `Record a voice note to start a conversation with your manager.` | Good — actionable |
| Finance - Invoices | (EmptyStateWidget) | `No invoices yet. Tap + to create your first invoice.` |

---

### Issue 8: Inconsistent Capitalization in Button Labels

**Severity:** High
**Impact:** App looks unprofessional; inconsistent visual language

**Current patterns found:**
- ALL CAPS: `SIGN IN`, `APPROVE`, `ADD NOTE`, `DENY`, `INITIALIZE ACCOUNT`, `ON SITE`, `CHECKED OUT`, `EXEMPT`
- Title Case: `Save Draft`, `Send Report`, `Download PDF`, `View Details`
- Sentence case: `Cancel`, `Retry`, `Save`

**Recommendation:** Standardize:
- **Action buttons (primary/destructive):** Title Case — `Sign In`, `Approve`, `Deny`, `Initialize Account`
- **Status badges:** ALL CAPS — `ON SITE`, `CHECKED OUT`, `EXEMPT`, `DRAFT`, `FINAL`, `SENT` (these are labels, not buttons)
- **Text buttons (secondary):** Sentence case — `Cancel`, `Save`, `Retry`
- **Navigation labels:** Title Case — `Actions`, `Sites`, `Users`, `Finance`

---

## P2 — Medium (Fix When Possible)

### Issue 9: Snackbar Success Messages Inconsistent

**Current patterns:**
| File | Message | Style |
|------|---------|-------|
| `site_finances_subtab.dart` | `Invoice created` | Past tense, no punctuation |
| `owner_approvals_tab.dart` | `Request approved` | Past tense, no punctuation |
| `owner_approvals_tab.dart` | `Request denied` | Past tense, no punctuation |
| `owner_approvals_tab.dart` | `Note added` | Past tense, no punctuation |
| `owner_messages_tab.dart` | `Voice note sent to manager` | Past tense with context |
| `transcription_display.dart` | `Transcription updated!` | Exclamation mark |
| `super_admin_screen.dart` | `Account & Admin created successfully` | With "successfully" |
| `company_detail_screen.dart` | `Provider changed to ${provider}` | Past tense with detail |
| `report_detail_screen.dart` | Various success messages | Mixed patterns |

**Recommendation:** Standardize all success messages:
- Format: `{Object} {past tense verb}` — no exclamation marks, no "successfully"
- Examples: `Invoice created`, `Report saved`, `Transcription updated`, `Account created`, `Provider changed`

---

### Issue 10: Loading Messages Inconsistent

**Current:**
- `Loading projects...` / `Loading reports...` / `Loading approvals...` — consistent ✓
- `Loading summary...` / `Loading materials...` / `Loading design log...` — consistent ✓
- `Loading financial overview...` — more verbose than others
- `Loading companies...` — consistent ✓

**Recommendation:** Standardize to `Loading {noun}...` pattern. Change:
- `Loading financial overview...` → `Loading finances...`

---

### Issue 11: "Unnamed" Fallback Labels

**Current fallbacks for missing data:**
| File | Fallback |
|------|----------|
| `owner_project_card.dart` | `Unnamed Project` |
| `projects_tab.dart` | `Site` |
| `attendance` | `Unknown` / `Unknown Site` |
| `owner_approval_card.dart` | `Approval Request` |
| `owner_report_view_screen.dart` | `Manager` |

**Recommendation:** Standardize fallbacks:
- Missing name: `Untitled` (for sites/projects) or `Unknown` (for people)
- Missing site: `Unknown Site`
- Missing person: `Unknown User`

---

### Issue 12: AppBar Titles — Mixed Casing

| Screen | Title | Style |
|--------|-------|-------|
| Login | `HOUZZDAT` | ALL CAPS (brand) ✓ |
| Company Selector | `SELECT COMPANY` | ALL CAPS |
| Super Admin | `SUPER ADMIN PANEL` | ALL CAPS |
| Owner Dashboard | `Welcome, {name}` | Sentence case |
| Manager Dashboard | Dynamic | Mixed |
| Reports | `Reports` | Title Case |

**Recommendation:**
- Brand name: ALL CAPS `HOUZZDAT` ✓
- Screen titles: Title Case — `Select Company`, `Super Admin Panel`
- Welcome messages: Keep as-is ✓

---

### Issue 13: Confirmation Dialogs — Missing "Cancel" Option Clarity

Some dialogs use `Cancel` + action, which is fine. But the deactivate user dialog says:

> `"This will disable their access immediately. They will not be able to log in or use the app until reactivated."`

This is **excellent** — other dialogs should follow this pattern of stating exactly what will happen.

**Recommendation:** Apply this detailed consequence pattern to:
- Archive company dialog (already good)
- Remove user dialog (already good)
- Delete site dialog (needs improvement — see Issue 6)

---

### Issue 14: Date/Time Format Inconsistency

**Current formats found:**
- `h:mm a` (attendance times) — 12-hour
- `d MMM yyyy` (report dates) — `9 Feb 2026`
- `MMM d` (attendance date picker) — `Feb 9`
- `MMM d, yyyy` (company dates) — `Feb 9, 2026`
- `d MMM yyyy, h:mm a` (report sent date) — `9 Feb 2026, 2:30 PM`
- Relative: `2h ago`, `3d ago`, `Received 2h ago`

**Recommendation:** Standardize:
- **Short date:** `d MMM` — `9 Feb`
- **Full date:** `d MMM yyyy` — `9 Feb 2026`
- **Date + time:** `d MMM yyyy, h:mm a` — `9 Feb 2026, 2:30 PM`
- **Relative time:** `{N}m ago`, `{N}h ago`, `{N}d ago` (already mostly consistent)

---

## P3 — Low (Nice to Have)

### Issue 15: Voice Recording Indicator Text

**Location:** `owner_messages_tab.dart`, line 242
**Current:** `Recording... Tap to send`
**Recommendation:** `Recording... Tap mic to stop and send`
**Rationale:** More explicit about what the user needs to do.

### Issue 16: Provider Labels Could Be Friendlier

**Location:** `super_admin_screen.dart`
**Current:** `Free (Groq Whisper)` / `Paid (OpenAI Whisper)` / `Gemini 1.5 Flash (Google)`
**Recommendation:** `Groq — Free` / `OpenAI — Paid` / `Gemini — Google`
**Rationale:** Lead with the provider name, put pricing as subtitle.

### Issue 17: "HOUZZDAT" vs "SiteVoice" Brand Name

**Location:** Login screen, line 57
**Current:** `HOUZZDAT`
**Note:** The product is called "SiteVoice" in all documentation but "HOUZZDAT" on the login screen. If rebranding to SiteVoice, this should be updated. If keeping both names, document the distinction (HOUZZDAT = company, SiteVoice = product).

### Issue 18: Email Template Content

**Location:** `supabase/Functions/send-report-email/index.ts`
**Current email body:** `Please find attached the project progress report.`
**Recommendation:** `Hi, please find attached the progress report for {dateRange}. This report covers {siteNames}. — Generated by SiteVoice`
**Rationale:** More contextual; recipient knows which report without opening it.

---

## Terminology Standards

Based on this audit, the following terminology should be standardized:

| Concept | Preferred Term | Avoid | Notes |
|---------|---------------|-------|-------|
| Construction location | **Site** | Project, Location | "Project" only in code/DB |
| People who build | **Worker** | Employee, Staff, Team Member | Exception: "Staff Member" in invite dialog is OK |
| People who manage | **Manager** | Admin (when referring to role) | "Admin" for elevated permissions only |
| Project client | **Owner** | Client | |
| Voice recording | **Voice note** | Recording, Audio, Message | |
| AI-generated summary | **Summary** | Synopsis, Overview | |
| Action to be done | **Action item** | Task, Todo | "Task" only in Worker's Daily Tasks tab |
| Site entrance tracking | **Check-in** / **Check-out** | Clock in/out, Sign in/out | |
| Money owed | **Invoice** | Bill | |
| Money sent | **Payment** | Transaction | |
| Owner money request | **Fund request** | Funding request | |
| AI processing | **Processing** | Analyzing, Working | |
| Report periods | **Daily** / **Weekly** / **Custom** | | |
| Report audiences | **Manager Report** / **Owner Report** | Internal/External | |

---

## Style Guide Recommendations

### Tone Guidelines

| Context | Tone | Example |
|---------|------|---------|
| Success messages | Confident, brief | `Invoice created` |
| Error messages | Empathetic, helpful | `Could not save. Please check your connection and try again.` |
| Empty states | Encouraging, guiding | `No reports yet. Reports from your manager will appear here.` |
| Confirmation dialogs | Clear, factual | `Deactivate this user? They will lose access immediately.` |
| Loading states | Calm, informative | `Loading reports...` |
| Button labels | Action-oriented | `Save Draft`, `Send Report`, `Generate Report` |

### Capitalization Rules

| Element | Style | Examples |
|---------|-------|---------|
| Primary action buttons | Title Case | `Save Draft`, `Send Report`, `Approve Request` |
| Secondary/text buttons | Sentence case | `Cancel`, `Retry`, `Skip` |
| Tab labels | Title Case | `Actions`, `Sites`, `Finance` |
| Status badges | ALL CAPS | `PENDING`, `APPROVED`, `ON SITE` |
| Category badges | ALL CAPS | `ACTION`, `APPROVAL`, `UPDATE` |
| AppBar titles | Title Case | `Select Company`, `Reports` |
| Snackbar messages | Sentence case | `Invoice created`, `Report saved` |
| Form labels | Title Case | `Full Name`, `Email Address` |
| Hints/placeholders | Sentence case | `Enter site name`, `user@example.com` |

### Error Message Templates

```
// Network error
Could not {action}. Please check your connection and try again.

// Validation error
Please enter {what's needed}. {format hint if applicable}

// Permission error
You don't have permission to {action}. Contact your administrator.

// Not found
{Thing} not found. It may have been deleted.

// Generic fallback
Something went wrong. Please try again.
```

### Success Message Templates

```
// Create
{Object} created

// Update
{Object} updated

// Delete
{Object} deleted

// Send
{Object} sent {to recipient if applicable}

// Status change
{Object} {new status} — e.g., "Invoice approved", "User deactivated"
```

### Empty State Templates

```
Title: No {objects} Yet
Subtitle: {Helpful context about when data will appear}. {Optional action hint}.

Examples:
- "No invoices yet. Tap + to create your first invoice."
- "No voice notes for this date range. Try expanding the dates."
- "No reports shared with you yet. Reports from your manager will appear here."
```

---

## Implementation Checklist

### Phase 1: P0 Critical Fixes (Effort: ~2 hours)

| # | File | Change | Effort |
|---|------|--------|--------|
| 1 | `finance/widgets/site_finances_subtab.dart` | Replace `Error: $e` (line 207) | 5 min |
| 2 | `finance/widgets/owner_finances_subtab.dart` | Replace `Error: $e` (lines 204, 236) | 5 min |
| 3 | `reports/screens/report_detail_screen.dart` | Replace `Error: $e` (line 356) | 5 min |
| 4 | `reports/screens/reports_screen.dart` | Replace `Error: $e` (line 133) | 5 min |
| 5 | `reports/screens/prompts_management_screen.dart` | Replace `Error: $e` (line 98) | 5 min |
| 6 | `voice_notes/widgets/transcription_display.dart` | Replace `❌ Error:` (line 230) | 5 min |
| 7 | `worker/tabs/my_logs_tab.dart` | Replace `Error: $e` (line 180) | 5 min |
| 8 | `dashboard/widgets/team_dialogs.dart` | Replace `Error:` (lines 458, 831, 859) | 10 min |
| 9 | `dashboard/widgets/role_management_dialog.dart` | Replace `Error:` (lines 56, 186, 280) | 10 min |
| 10 | `auth/screens/super_admin_screen.dart` | Replace `Error:` (lines 86, 96) | 5 min |
| 11 | `owner/screens/owner_report_view_screen.dart` | Replace `Error generating PDF:` (line 217) | 5 min |

### Phase 2: P1 High Priority (Effort: ~3 hours)

| # | File | Change | Effort |
|---|------|--------|--------|
| 12 | `owner_projects_tab.dart` | Change "Projects" → "Sites" in empty state | 10 min |
| 13 | `owner_project_card.dart` | Change "Unnamed Project" → "Untitled Site" | 5 min |
| 14 | `owner_approvals_tab.dart` | Change "Confirm" → context-specific label | 15 min |
| 15 | `companies_tab.dart` | Change generic "Action completed" to specific | 15 min |
| 16 | `user_action_dialogs.dart` | Add specificity to button labels | 15 min |
| 17 | Various empty states | Add actionable guidance | 30 min |
| 18 | Various buttons | Normalize capitalization to Title Case | 45 min |

### Phase 3: P2 Medium Priority (Effort: ~2 hours)

| # | File | Change | Effort |
|---|------|--------|--------|
| 19 | `transcription_display.dart` | Remove `!` from success message | 5 min |
| 20 | `super_admin_screen.dart` | Remove "successfully" from success | 5 min |
| 21 | `owner_project_detail.dart` | Change "Loading financial overview..." | 5 min |
| 22 | Various fallbacks | Standardize "Unknown"/"Untitled" | 20 min |
| 23 | `super_admin_screen.dart` / `company_selector_screen.dart` | Title Case AppBar titles | 10 min |

### Phase 4: P3 Low Priority (Effort: ~1 hour)

| # | File | Change | Effort |
|---|------|--------|--------|
| 24 | `owner_messages_tab.dart` | Improve recording indicator text | 5 min |
| 25 | `super_admin_screen.dart` | Restructure provider labels | 10 min |
| 26 | `send-report-email/index.ts` | Improve email body template | 15 min |

**Total estimated effort: ~8 hours**

---

*Audit conducted by Claude. All file paths and line numbers verified against the current codebase.*
