# Houzzapp UX Audit: Workflows, Friction Points & Solutions

## Context
Full audit of the Houzzapp (Sitevoice) Flutter application covering all user workflows across 4 roles (Super Admin, Manager, Owner, Worker), 105+ Dart files, and 9 feature modules. Each friction point includes a concrete solution.

---

## 1. AUTHENTICATION & ONBOARDING

### 1A. Login (`lib/features/auth/screens/login_screen.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 1 | No email format validation — accepts `abc`, `test@` | HIGH | Add regex validator: `RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')` in the `TextFormField.validator`. Also set `keyboardType: TextInputType.emailAddress`. |
| 2 | Generic error messages — all failures show same text | HIGH | Parse Supabase `AuthException.message` and map to user-friendly strings: `"Invalid login credentials"` → "Incorrect email or password", `"User not found"` → "No account with this email", network errors → "Check your internet connection". |
| 3 | No "Forgot Password" link | HIGH | Add `TextButton("Forgot password?")` below password field that calls `supabase.auth.resetPasswordForEmail(email)` and shows confirmation dialog. Requires adding a password reset confirmation screen. |
| 4 | No password visibility toggle | MEDIUM | Add `suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility))` to password `TextFormField` with `_obscure` state toggle. |
| 5 | No sign-up flow for new users | HIGH | This is intentional (admin-managed accounts), but add a helper text: "Don't have an account? Contact your company administrator" with the admin's email if available. |

### 1B. Auth Wrapper (`lib/features/auth/screens/auth_wrapper.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 6 | No loading text on spinner | MEDIUM | Replace bare `CircularProgressIndicator` with `Column(children: [spinner, SizedBox(h:16), Text("Setting up your workspace...")])`. Add stage-specific messages: "Checking permissions...", "Loading companies...". |
| 7 | Raw error messages shown | MEDIUM | Wrap error display in a user-friendly card: catch errors and show "Something went wrong. Please try again." with a "Retry" button + "Show details" expandable for the technical error. |
| 8 | No retry button on error states | MEDIUM | Add `ElevatedButton.icon(icon: Icon(Icons.refresh), label: Text('Retry'), onPressed: () => setState(() {}))` to the error widget to re-trigger the FutureBuilder. |
| 9 | Auto-selection of single company not explained | LOW | Show a brief toast: `ScaffoldMessenger.showSnackBar(SnackBar(content: Text("Signed in to $companyName")))` when auto-selecting the only company. |

### 1C. Company Selector (`lib/features/auth/screens/company_selector_screen.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 10 | `pushNamedAndRemoveUntil('/')` may fail (no named route) | HIGH | Replace with `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthWrapper()), (_) => false)` for reliable navigation. |
| 11 | No logout confirmation | MEDIUM | Wrap logout `IconButton.onPressed` in `showDialog(builder: (_) => LogoutDialog())` — the `LogoutDialog` widget already exists in the codebase (`lib/features/auth/widgets/logout_dialog.dart`). |
| 12 | Role badge colors unexplained | LOW | Add a small "?" icon next to role badges that shows a tooltip: "Admin manages users & settings. Owner views reports. Worker records notes." |

### 1D. Super Admin Onboarding (`lib/features/auth/screens/super_admin_screen.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 13 | No email format validation | HIGH | Convert `TextField` to `TextFormField` with email validator. Set `keyboardType: TextInputType.emailAddress` and `autovalidateMode: AutovalidateMode.onUserInteraction`. |
| 14 | No password strength requirements shown | HIGH | Add `helperText: 'Min 8 chars, include a number and symbol'` to password field. Add real-time strength indicator widget (colored bar: red/orange/green) below the field. Validate before submission. |
| 15 | Provider descriptions use technical jargon | MEDIUM | Rewrite labels: "Groq (Free, Fast)" → "Fast & Free — Best for English", "OpenAI (Paid)" → "High Accuracy — Best quality, costs per use", "Sarvam" → "Indian Languages — 22+ languages with native transcription". Add a `?` icon linking to a comparison tooltip. |
| 16 | Sarvam pipeline mode labels confusing | MEDIUM | Rename: "Two-step (ASR + Translate)" → "Full Pipeline — Get original transcript + English translation (2 API calls, preserves original language)", "Single call" → "Quick Translate — Get English translation directly (1 API call, faster)". |
| 17 | Form doesn't disable during submission | MEDIUM | Set `AbsorbPointer(absorbing: _isLoading, child: formContent)` to disable all form fields during submission. Also disable the provider dropdown during loading. |
| 18 | Success doesn't show created credentials | LOW | Show a success dialog with the admin email: "Account created! The admin can sign in with: $email". Don't show password (security), but confirm the email was set. |

---

## 2. VOICE NOTE WORKFLOWS

### 2A. Recording & Submission (`manager_dashboard_classic.dart`, `audio_recorder_service.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 19 | No upload progress indicator after recording | HIGH | Show a modal overlay with `LinearProgressIndicator` and "Uploading voice note..." text. Use `_isUploading` state (already exists at line 38) to control visibility. Disable other interactions during upload. |
| 20 | No recording duration limit | HIGH | Add a 5-minute max timer. Show elapsed time in the FAB area. At 4:30, show orange warning. At 5:00, auto-stop. Use `Timer.periodic(Duration(seconds: 1))` to track. |
| 21 | No undo/delete after accidental upload | HIGH | In the success snackbar, add an `action: SnackBarAction(label: 'UNDO', onPressed: () => deleteVoiceNote(id))`. Keep a 10-second window. The voice note's `id` is returned from `uploadAudio()`. |
| 22 | No recording playback before submit | HIGH | After `stopRecording()` returns bytes, show a preview dialog with audio player (reuse `VoiceNoteAudioPlayer` widget) + "Submit" and "Discard" buttons. Only call `uploadAudio()` on Submit. |
| 23 | Quick-tag auto-dismisses without notification | MEDIUM | After auto-dismiss, show a small persistent snackbar: "Quick tag skipped. Tap to tag now." with action button that reopens the overlay. |
| 24 | Silent mic permission failure | MEDIUM | Replace snackbar with a dialog: "Microphone access needed. Go to Settings to enable it." with a button calling `openAppSettings()` from `permission_handler` package. |
| 25 | No cancel button during upload | MEDIUM | Add "Cancel" button to the upload overlay. On cancel, abort the Supabase storage upload (if possible) or delete the uploaded file + voice_notes record. |
| 26 | No pause/resume recording | MEDIUM | Add `_recorderService.pauseRecording()` and `resumeRecording()` methods. Show a pause/play toggle on the FAB area during recording. The `record` package supports `pause()`. |

### 2B. Voice Note Feed (`lib/features/dashboard/tabs/feed_tab.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 27 | No confirmation before ACK | MEDIUM | Add undo-style: on ACK tap, immediately show "Acknowledged" with `SnackBarAction(label: 'UNDO')`. Write to DB after snackbar closes. If undone, cancel the write. |
| 28 | Search only covers transcripts | MEDIUM | Extend search to include: category (from quick-tag), sender name (join with users table), date. Add filter chips: "Category", "Date Range", "Sender" below the search bar. |
| 29 | Reply flow confusing (in-card toggle) | HIGH | Replace in-card reply with a dedicated `ReplyDialog` that shows: original voice note context (who, when, summary), audio player for original, record button for reply, optional text field. Navigate back to feed on send. |
| 30 | No text reply option | MEDIUM | In the new `ReplyDialog`, add a tab or toggle: "Voice Reply" / "Text Reply". Text replies insert into a `voice_note_replies` table with `reply_type: 'text'`. |
| 31 | Multi-stage progress not shown | MEDIUM | Replace "Transcribing..." with a `StepProgressIndicator` showing 4 dots: Transcribe → Translate → Analyze → Done. Map `status` values ('transcribing', 'translated', 'analyzing', 'completed') to step positions. |

### 2C. Audio Player (`lib/features/voice_notes/widgets/voice_note_audio_player.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 32 | Audio errors show but no recovery guidance | HIGH | Parse error types: network error → "Check your internet and try again", 404 → "Audio file not found — it may have been deleted", format error → "Unsupported audio format". Add a "Retry" button that re-calls `_validateAndInit()`. |
| 33 | No error type differentiation | MEDIUM | Catch specific exception types in the `try/catch`: `SocketException` for network, check HTTP status codes, `PlatformException` for format issues. Display different icons + messages for each. |

### 2D. Transcription Editing (`lib/features/voice_notes/widgets/transcription_display.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 34 | "One edit only" limit not warned upfront | HIGH | Before opening the edit dialog, show a confirmation: "You can edit this transcript once. After saving, it will be locked. Continue?" with "Edit" and "Cancel" buttons. |
| 35 | Non-English transcripts show raw format | MEDIUM | Parse the `[Language] text ... [English] translation` format and render as two styled containers: a grey box labeled "Original (Hindi)" with original text, and a white box labeled "English Translation" with translated text. The parsing logic already exists at lines 46-101. |
| 36 | Edit reason hardcoded to 'clarification' | LOW | Add a dropdown in the edit dialog: "Reason for edit:" with options: "ASR error", "Grammar fix", "Clarification", "Other". Pass selected value to the `voice_note_edits` insert. |
| 37 | No character count warning | LOW | Add `buildCounter` to the `TextField` that shows `"${text.length}/2000"` and turns red above 2000. Disable save button if exceeded. |

---

## 3. ACTION ITEMS

### 3A. Actions Tab (`lib/features/dashboard/tabs/actions_tab.dart`)

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 38 | No bulk action support | HIGH | Add a "Select" toggle button in the app bar. When active, show checkboxes on each card. Show a floating action bar at bottom: "X selected: [RESOLVE ALL] [ASSIGN ALL]". |
| 39 | AI confidence score unexplained | MEDIUM | Replace raw number with a visual bar + label: 0-0.4 → red "Low Confidence", 0.4-0.7 → orange "Medium", 0.7-1.0 → green "High". Add info icon with tooltip: "Confidence measures how certain the AI is about this classification." |
| 40 | No search/filter in actions tab | HIGH | Add a persistent `SearchBar` at top with auto-complete. Add `FilterChip` row: "High Priority", "Pending Approval", "My Actions", "This Week". Chips compose with search. |
| 41 | Only 1 card expandable at a time | MEDIUM | Add a toggle icon in the header: "Single expand" / "Multi expand". Default to single. In multi mode, remove the `_expandedCardId` exclusion logic so multiple cards can be open. |
| 42 | No pagination | HIGH | Replace `_loadActions()` full-fetch with paginated fetch: `.range(offset, offset + 20)`. Add `ScrollController` listener at 80% scroll to trigger `_loadMoreActions()`. Show `CircularProgressIndicator` at list bottom during load. |

### 3B. Instruct Voice Dialog

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 43 | No voice preview before sending | HIGH | After recording stops, show playback controls (reuse `VoiceNoteAudioPlayer`) with "Re-record" and "Send" buttons. Only upload on "Send". |
| 44 | No recipient name shown | MEDIUM | Add recipient lookup: query `users` table for the original voice note sender's `full_name`. Display "Sending instruction to: **[Name]**" at the top of the dialog. |
| 45 | Upload failure not retryable | MEDIUM | On error, keep the recorded audio in memory. Show "Failed to send. [Retry] [Cancel]" instead of closing the dialog. |
| 46 | No draft saving on re-record | LOW | Before starting re-record, prompt: "Discard current recording?" with "Keep" / "Discard" options. |

### 3C. Needs-Review Queue

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 47 | CONFIRM/EDIT/DISMISS buttons too close | MEDIUM | Add horizontal padding between buttons (SizedBox(width: 12)). For DISMISS, require a confirmation dialog: "Dismiss this action? It won't appear in your queue anymore." |
| 48 | No comparison with original voice note | MEDIUM | Add a "Play Original" button next to the review status badge. On tap, show a mini audio player inline that plays the source voice note. |

---

## 4. BROADCAST

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 49 | No search in recipient selector | MEDIUM | Add `TextField` with `onChanged` filter at top of `RecipientSelectorDialog`. Filter the team member list in real-time by name match. |
| 50 | Recipient list not shown before recording | HIGH | After selection and before recording, show a confirmation screen: "Broadcasting to: [Name1, Name2, Name3] (X members total). [Start Recording] [Back to Edit]". |
| 51 | No undo after broadcast sent | MEDIUM | Use delayed-send pattern: show "Broadcast sent! [UNDO - 10s]" snackbar. Actually insert `voice_note_forwards` records after 10 seconds. If undone, delete the uploaded voice note. |
| 52 | Text note after recording (backwards) | MEDIUM | Move the optional text note field to the recipient confirmation screen (before recording). Label it "Add context for your team (optional)". This way context is set before the voice is recorded. |
| 53 | No draft saving if cancelled | LOW | On cancel during confirmation, prompt: "Save recording as draft? You can resume later." Store audio bytes in local temp storage with SharedPreferences reference. |

---

## 5. REPORTS

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 54 | No bulk delete for drafts | MEDIUM | Add "Select" mode toggle (same pattern as actions tab). Show checkboxes on draft report cards. "Delete selected" button with confirmation dialog. |
| 55 | Manual date navigation in daily reports | MEDIUM | Replace `TextField`-based date picker with a `TableCalendar` widget (add `table_calendar` package) or use `showDateRangePicker()` which provides a calendar grid. Add "Last 7 days" / "Last 30 days" / "This month" quick-pick chips. |
| 56 | No export/archive functionality | MEDIUM | Add `PopupMenuButton` on each report card: "Export as PDF", "Archive". Archive moves report to an "Archived" status filter tab. Export reuses existing `PdfGeneratorService`. |
| 57 | "Regenerate" is destructive | HIGH | Replace alert with a two-step confirmation: "This will replace your current report with a new AI-generated version. Your current draft will be lost. [Cancel] [Regenerate]". Also save the previous version in a `report_versions` table for undo. |
| 58 | No conflict resolution for simultaneous edits | HIGH | Add optimistic locking: store `updated_at` timestamp. Before save, check if `updated_at` changed. If yes, show: "This report was modified by [other user] at [time]. [View their changes] [Overwrite] [Cancel]". |
| 59 | No auto-save for drafts | MEDIUM | Add `Timer.periodic(Duration(seconds: 30))` that calls a debounced save function when content changes. Show "Auto-saved" indicator in the toolbar. Track changes with a `_hasUnsavedChanges` flag. |
| 60 | No email validation before sending | MEDIUM | Validate email in `SendReportDialog` with the same regex as login. Show inline error below the field. Disable "Send" button until valid. |
| 61 | Custom Base64 encoder | LOW | Replace lines 525-537 with `import 'dart:convert'; base64Encode(bytes)`. Remove the custom implementation. |

---

## 6. INSIGHTS & ANALYTICS

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 62 | All projects loaded at once | MEDIUM | Implement lazy loading: only compute health for visible projects. Use `ListView.builder` with `itemCount` and fetch data on-demand per project card. |
| 63 | No caching between tab switches | MEDIUM | Cache computed results in a `Map<String, ProjectHealth>` keyed by project ID. Invalidate on pull-to-refresh. Set cache TTL of 5 minutes. |
| 64 | Trend detection not implemented (TODO) | LOW | For now, add a placeholder message: "Trend analysis coming soon. Currently showing latest snapshot." Remove TODO and create a GitHub issue for tracking. |
| 65 | Health score opaque to user | MEDIUM | Add "How is this calculated?" link that opens a dialog showing score breakdown: "Voice notes this week: 8/10 (80%) + Action items resolved: 5/7 (71%) + Attendance rate: 90% = Health Score: 80". |

---

## 7. FINANCE

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 66 | No loading states on form submissions | MEDIUM | Add `_isSaving` state to each bottom sheet. Show `CircularProgressIndicator` on the save button. Disable all fields with `AbsorbPointer` during save. Close sheet on success with snackbar confirmation. |
| 67 | No validation on currency fields | HIGH | Add validator: `if (amount <= 0) return 'Amount must be positive'`. Set `keyboardType: TextInputType.numberWithOptions(decimal: true)`. Use `TextInputFormatter` to allow only digits and one decimal point. |
| 68 | No receipt/attachment support | MEDIUM | Add "Attach Receipt" button that opens `FilePicker` (already in pubspec). Upload to Supabase Storage under `receipts/{account_id}/`. Store URL in invoice/payment record. Show thumbnail preview. |
| 69 | No recurring payments | LOW | Add "Recurring" toggle in invoice form. Fields: frequency (weekly/monthly), end date. Create `recurring_invoices` table with cron-like scheduling. For now, show as feature placeholder. |

---

## 8. SUPER ADMIN

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 70 | N+1 query for user counts | HIGH | Replace per-company user count queries with a single query: `SELECT account_id, COUNT(*) FROM users GROUP BY account_id`. Fetch once, store in `Map<String, int>`. Lines 50-64 in `companies_tab.dart`. |
| 71 | No search by company name | MEDIUM | Add `TextField` with `_searchController` above the filter chips. Filter `_companies` list with `.where((c) => c['company_name'].toLowerCase().contains(query))`. |
| 72 | "Deactivate" vs "Inactive" mismatch | LOW | Standardize: use "Deactivated" everywhere (button label "Deactivate", status badge "DEACTIVATED", filter chip "Deactivated"). Update filter value from `'inactive'` to `'deactivated'` or update the status column values. |
| 73 | No audit log for status changes | MEDIUM | Create `company_audit_log` table: `(id, account_id, action, actor_id, old_value, new_value, created_at)`. Insert a row in the `manage-company-status` edge function before making the change. Display in company detail screen as a timeline. |
| 74 | No pagination for large teams | MEDIUM | Add `limit: 20` to team member query. Add "Show more" button at bottom. Use offset-based pagination. |
| 75 | Provider change dialog too complex | MEDIUM | Replace the modal dialog with an inline expandable section on the company detail card. Show current provider with "Change" link. On tap, expand to show radio buttons inline (no modal). |
| 76 | No actions on team members | MEDIUM | Add slide-to-reveal actions on team member rows: "Change Role", "Deactivate", "Remove". Or add a `PopupMenuButton` on each row with these options. |
| 77 | Date formatting not locale-aware | LOW | Replace `DateFormat('MMM d, yyyy')` with `DateFormat.yMMMd(Localizations.localeOf(context).toString())` to respect device locale. |

---

## 9. OWNER DASHBOARD

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 78 | N+1 queries for project stats | HIGH | Use a single query with LEFT JOINs: `SELECT p.*, COUNT(ai.id) as action_count FROM projects p LEFT JOIN action_items ai ON p.id = ai.project_id WHERE p.id IN (...) GROUP BY p.id`. |
| 79 | "Messages" tab misleading | MEDIUM | Rename tab to "Voice Notes" or "Updates". Change icon from `Icons.message` to `Icons.mic`. |
| 80 | Messages filtered to 7-day window | MEDIUM | Add date range filter with quick-pick chips: "Last 7 days" (default), "Last 30 days", "All time". Store preference in SharedPreferences. |
| 81 | No project search/filter | MEDIUM | Add search bar at top of projects tab. Filter by project name. Add sort options: "Most Recent", "Most Active", "Alphabetical". |

---

## 10. WORKER INTERFACE

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 82 | No cancel-during-recording | MEDIUM | Add a secondary "Cancel" button (red X icon) next to the recording FAB. On tap, call `_recorderService.cancelRecording()` (add method that calls `stop()` and discards bytes). |
| 83 | No retry if upload fails | MEDIUM | On upload error, show a dialog: "Upload failed. [Retry] [Discard]". Keep audio bytes in memory. On Retry, call `uploadAudio()` again with same bytes. |
| 84 | Onboarding tooltip only 3 times | LOW | Add "Show help tips" toggle in settings/profile. When on, re-enable the onboarding counter. Also add a "?" icon in the app bar that shows the tip on-demand. |
| 85 | Quick-tag is modal-blocking | LOW | Convert QuickTagOverlay from modal to a non-modal overlay (use `OverlayEntry` positioned at bottom, allowing taps on other areas to dismiss it). |

---

## 11. CROSS-CUTTING ISSUES

### 11A. Offline/Connectivity

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 86 | No offline detection | HIGH | Add `connectivity_plus` package. Create `ConnectivityService` singleton with a stream. Show a persistent `MaterialBanner` at top: "You're offline. Changes will sync when connected." Conditionally disable upload buttons. |
| 87 | No offline queueing for voice notes | HIGH | On upload failure due to connectivity, save audio bytes to local file via `path_provider`. Store pending uploads in SharedPreferences as JSON list. Add `_processPendingUploads()` method triggered when connectivity returns. |
| 88 | No local caching | MEDIUM | Add `shared_preferences` or `hive` caching for frequently accessed data (projects list, team members, action items). Set cache TTL of 5 minutes. Load from cache first, then refresh from network. |
| 89 | Notification count drifts | MEDIUM | Add `WidgetsBindingObserver` to detect app resume (`didChangeAppLifecycleState`). On resume, call `_loadUnreadCount(userId)` to re-sync count from server. |

### 11B. Accessibility

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 90 | No semantic labels | HIGH | Add `semanticsLabel` to all `IconButton` widgets. Examples: `Icon(Icons.mic, semanticsLabel: 'Record voice note')`, `Icon(Icons.logout, semanticsLabel: 'Sign out')`. |
| 91 | Color-only status indicators | HIGH | Add text labels alongside colored dots: "Active" (green dot + text), "Removed" (red dot + text). Use `Row(children: [statusDot, SizedBox(w:4), Text(statusLabel)])` pattern. |
| 92 | Touch targets < 44px | MEDIUM | Set `minimumSize: Size(44, 44)` in `FilterChip` theme data. Ensure all `IconButton` have `constraints: BoxConstraints(minWidth: 44, minHeight: 44)`. |
| 93 | No keyboard navigation | MEDIUM | Add `FocusTraversalGroup` to forms. Use `TextInputAction.next` on all fields with `onFieldSubmitted: (_) => FocusScope.of(context).nextFocus()`. |
| 94 | No dark mode | MEDIUM | Create `AppTheme.darkTheme` with inverted color scheme. Add `ThemeMode` toggle in settings (store in SharedPreferences). Wrap app in `MaterialApp(themeMode: _themeMode, darkTheme: AppTheme.darkTheme)`. |
| 95 | No high-contrast mode | LOW | Add MediaQuery check: `MediaQuery.of(context).highContrast`. If true, increase border widths, use bolder colors. Low priority but easy to implement. |

### 11C. Design System Consistency

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 96 | Mix of AlertDialog vs BottomSheet | MEDIUM | Establish convention: **BottomSheet** for forms/inputs (create, edit), **AlertDialog** for confirmations (delete, deactivate). Document in a `STYLE_GUIDE.md` for the team. Refactor existing screens to match. |
| 97 | Inconsistent empty states | LOW | Create a single `AppEmptyState` widget: `AppEmptyState(icon, title, subtitle, actionLabel?, onAction?)`. Replace all custom empty states with this widget. |
| 98 | Status indicator patterns vary | MEDIUM | Create `StatusBadge` widget that takes `status` string and renders consistently: colored dot + uppercase text label. Use everywhere: company cards, user rows, action cards, reports. |
| 99 | Loading states inconsistent | MEDIUM | Create `AppLoadingState` widget: `AppLoadingState(message: 'Loading projects...')` with spinner + text. Replace all bare `CircularProgressIndicator` instances. |

### 11D. Performance

| # | Friction Point | Severity | Solution |
|---|---------------|----------|----------|
| 100 | No state management (raw setState) | MEDIUM | Long-term: migrate to Riverpod or BLoC for complex screens (dashboard, insights). Short-term: at minimum, extract business logic into service classes and use `ChangeNotifier` + `ListenableBuilder`. |
| 101 | Realtime subscriptions not cleaned up | MEDIUM | Add `.unsubscribe()` calls in every `dispose()` method. Store channel references as class members. Use a mixin `RealtimeSubscriptionMixin` that auto-cleans on dispose. |
| 102 | No async cancellation tokens | LOW | Use `CancelableOperation` from `async` package for long-running operations. Cancel in `dispose()` to prevent `setState` on unmounted widgets. |

---

## 12. PRIORITY IMPLEMENTATION ROADMAP

### Phase 1: Critical Fixes (1-2 weeks)
**Goal:** Fix security, data integrity, and user-blocking issues

1. Add email + password validation to login and onboarding forms (#1, #13, #14)
2. Replace generic errors with specific messages (#2, #7)
3. Fix navigation bug in company selector (#10)
4. Add upload progress indicator + undo for voice notes (#19, #21)
5. Fix N+1 queries in companies tab and owner projects (#70, #78)
6. Add pagination to actions tab (#42)
7. Add currency field validation (#67)

### Phase 2: Core UX Improvements (2-3 weeks)
**Goal:** Reduce friction in daily workflows

8. Add recording playback before submit (#22)
9. Add voice preview before sending instructions (#43)
10. Improve reply flow with dedicated dialog (#29)
11. Add search/filter to actions tab and feed (#40, #28)
12. Show multi-stage transcription progress (#31)
13. Warn about one-edit limit before transcription edit (#34)
14. Show recipient list before broadcast (#50)
15. Add Forgot Password flow (#3)
16. Add offline detection banner (#86)

### Phase 3: Polish & Accessibility (2-3 weeks)
**Goal:** Professional quality and inclusive design

17. Add semantic labels to all buttons (#90)
18. Add text labels alongside status colors (#91)
19. Unify dialog/sheet patterns (#96)
20. Add standard empty state + loading widgets (#97, #99)
21. Add auto-save for report drafts (#59)
22. Add conflict resolution for reports (#58)
23. Add dark mode (#94)
24. Add offline queueing for voice notes (#87)
25. Add bulk actions for action items (#38)

---

## Total Issues: 102 (HIGH: 28, MEDIUM: 52, LOW: 22)
