# SiteVoice/Houzzdat — Complete End-to-End Testing Workflows

This document lists every user-facing workflow in the app, organized by role, with step-by-step testing instructions.

---

## AUTHENTICATION & SETUP (All Roles)

### Workflow 1: Login
1. Open app → Login screen appears with "HOUZZDAT" branding
2. Enter email + password
3. Tap "Sign In"
4. **Expected:** User authenticated → routed to company selector or role dashboard
5. **Error case:** Wrong credentials → SnackBar: "Sign in failed. Please check your email and password."

### Workflow 2: Company Selection (Multi-Company Users)
1. After login (if user belongs to multiple companies) → Company Selector screen
2. See list of companies with role badges (Admin/Manager/Owner/Worker)
3. Tap a company card
4. **Expected:** Dashboard loads for that company context
5. **Error case:** SnackBar: "Could not switch company. Please try again."

### Workflow 3: Logout
1. Tap logout icon in AppBar (top-right)
2. **Expected:** Session ends → redirected to Login screen

---

## SUPER ADMIN WORKFLOWS

### Workflow 4: View All Companies
1. Login as Super Admin → Super Admin Panel opens
2. Companies tab shows grid of company cards
3. Each card: company name, user count, project count, status badge
4. **Expected:** All companies visible with correct statuses (active/deactivated/archived)

### Workflow 5: Onboard New Company
1. Super Admin Panel → "Onboard" tab
2. Enter: Company Name, Admin Email, Admin Password, Admin Name (optional)
3. Select transcription provider (Groq/Google Cloud)
4. Select languages
5. Tap "Initialize Account"
6. **Expected:** SnackBar "Account and admin created" → form clears → company appears in Companies tab
7. **Error case:** SnackBar: "Could not create account. Please check the details and try again."

### Workflow 6: Deactivate/Archive/Reactivate Company
1. Companies tab → tap a company card → Company Detail screen
2. Use action menu to change status (Deactivate, Archive, Reactivate)
3. **Expected:** SnackBar "Company status updated" → status badge changes
4. **Error case:** SnackBar: "Could not update company status. Please try again."

### Workflow 7: View Company Details
1. Companies tab → tap company card
2. **Expected:** Company Detail screen shows: company info, stats (users/projects/voice notes/action items), user list with roles, project list, transcription provider

### Workflow 8: Change Company Transcription Provider
1. Company Detail screen → tap provider setting
2. Select new provider from dropdown
3. **Expected:** SnackBar "Provider changed to {provider}"
4. **Error case:** SnackBar: "Could not update provider. Please try again."

---

## MANAGER/ADMIN WORKFLOWS

### Workflow 9: Record Voice Note (Manager Dashboard)
1. Manager Dashboard → tap center microphone button
2. Button animates (recording indicator)
3. Speak note/instruction
4. Tap button again to stop
5. **Expected:** SnackBar "Voice note submitted" → audio uploaded → Edge Function processes:
   - Status progression: processing → transcribed → translated → completed
   - Action items created from content
6. **Error case:** SnackBar: "Could not send voice note. Please check your connection and try again."

### Workflow 10: View & Manage Action Items (Actions Tab)
1. Manager Dashboard → Actions tab (bottom nav)
2. View list of action items with stats bar (Pending / In Progress / Completed)
3. Filter by: status, category, search text, sort order
4. Tap card to expand → see: audio player, transcript, AI analysis, confidence score
5. **Actions available:**
   - Approve action → status changes
   - Reject action → enter reason
   - Mark Complete
   - Add proof image
   - Calibrate confidence (thumbs up/down for AI improvement)
6. **Expected:** Real-time updates when action items change

### Workflow 11: Send Instruction to Worker (via Voice Note)
1. Actions tab → expand an action card
2. Tap "Instruct" button
3. Record voice instruction or type text
4. **Expected:** SnackBar "Instruction sent" → worker receives voice note as task

### Workflow 12: Forward Action Item
1. Actions tab → expand action card → tap "Forward"
2. Select recipient user
3. **Expected:** SnackBar "Action forwarded" → action reassigned

### Workflow 13: Create New Site
1. Manager Dashboard → Projects tab → Sites sub-tab
2. Tap "+" button
3. "Create New Site" dialog:
   - Enter site name, location (optional)
   - Optional: Enable geofence → "Use Current Location" → set radius
   - Optional: Onboard owner (search existing by email/phone, or create new)
4. Tap "Create"
5. **Expected:** Site appears in grid → real-time update

### Workflow 14: View Site Detail (Manager)
1. Projects tab → Sites sub-tab → tap a site card
2. **Expected:** Manager Site Detail screen with 2 tabs:
   - **Summary tab:** Status overview, worker count, today's reports, completion bar, blockers, recent actions
   - **Daily Reports tab:** Voice notes for this site filtered by date range, grouped by date

### Workflow 15: View Attendance (Manager)
1. Projects tab → Attendance sub-tab
2. **Expected:** Attendance records for all workers across sites
3. Filter by site or date range

### Workflow 16: Delete Site
1. Projects tab → Sites sub-tab → long-press or swipe site card → "Delete"
2. Confirm in dialog
3. **Expected:** SnackBar "Site deleted"

### Workflow 17: Invite Staff Member
1. Manager Dashboard → Team tab → tap "Invite Staff"
2. Invite dialog:
   - Enter Full Name, Email
   - Email auto-checks if user already exists (shows green checkmark if found)
   - If new user: enter temporary password
   - If existing user: password field hidden, info banner shown
   - Select role from dropdown
   - Select preferred languages (English always included, up to 2 more)
3. Tap "Send Invite" (or "Add to Company" for existing users)
4. **Expected:** SnackBar "User invited" → user appears in Active team list
5. **Error case:** SnackBar: "Could not invite user. Please check the details and try again."

### Workflow 18: Edit User
1. Team tab → Active sub-tab → tap user card
2. Edit User dialog:
   - Change name, role, project assignment
   - Toggle geofence exemption
   - Update language preferences
3. Tap "Save"
4. **Expected:** SnackBar "User updated"
5. **Error case:** SnackBar: "Could not update user. Please try again."

### Workflow 19: Deactivate User
1. Team tab → Active sub-tab → user action menu → "Deactivate"
2. Confirmation dialog: shows consequences (data preserved, can be reactivated, user unassigned)
3. Tap "Deactivate User"
4. **Expected:** SnackBar "{name} has been deactivated" → user moves to Inactive tab

### Workflow 20: Reactivate User
1. Team tab → Inactive sub-tab → tap user → "Reactivate"
2. Confirmation dialog
3. Tap "Reactivate User"
4. **Expected:** SnackBar "{name} has been reactivated" → user moves to Active tab

### Workflow 21: Remove User from Company
1. Team tab → user action menu → "Remove"
2. Confirmation dialog: shows warning (cannot be undone, historical data preserved)
3. Tap "Remove User"
4. **Expected:** SnackBar "{name} has been removed from the company"

### Workflow 22: Send Voice Note to Specific User
1. Team tab → tap "Send Voice Note" on a user card
2. Record voice note
3. **Expected:** SnackBar "Voice note sent to {name}" → user receives voice note

### Workflow 23: Manage Roles
1. Team tab → "Manage Roles" button
2. Role Management dialog:
   - View existing roles (admin, manager, worker, owner)
   - Add new custom role → SnackBar "Role added"
   - Delete role → SnackBar "Role deleted"
   - Initialize default roles (if none exist) → SnackBar "{N} default roles added"
3. **Error cases:** "Could not load/add/delete roles. Please try again."

### Workflow 24: Create Invoice
1. Manager Dashboard → Finance tab → Site Finances sub-tab
2. Tap "+" → select "New Invoice"
3. Bottom sheet: enter vendor, description, amount, project, due date
4. Tap "Submit"
5. **Expected:** SnackBar "Invoice created" → invoice appears in list with "submitted" status
6. **Error case:** SnackBar: "Could not create invoice. Please check your connection and try again."

### Workflow 25: Approve/Reject Invoice
1. Finance tab → tap a "submitted" invoice
2. **Approve:** Tap approve button → SnackBar "Invoice approved"
3. **Reject:** Tap reject button → enter reason → SnackBar "Invoice rejected"

### Workflow 26: Record Payment
1. Finance tab → tap "+" → select "Add Payment"
2. Bottom sheet: select invoice, enter amount, date, method
3. Tap "Submit"
4. **Expected:** SnackBar "Payment recorded" → if fully paid, invoice status → "paid"

### Workflow 27: Submit Invoice for Approval
1. Finance tab → find a "draft" invoice → tap "Submit"
2. **Expected:** SnackBar "Invoice submitted for approval" → status → "submitted"

### Workflow 28: Record Owner Payment
1. Finance tab → Owner Finances sub-tab → "Record" button
2. Bottom sheet: select owner, project, enter amount, date
3. Tap "Submit"
4. **Expected:** SnackBar "Owner payment recorded"
5. **Error case:** SnackBar: "Could not record payment. Please check your connection and try again."

### Workflow 29: Create Fund Request
1. Finance tab → Owner Finances sub-tab → "New Request" button
2. Bottom sheet: select owner, project, enter amount, description
3. Tap "Submit"
4. **Expected:** SnackBar "Fund request submitted"
5. **Error case:** SnackBar: "Could not submit fund request. Please try again."

### Workflow 30: Confirm Owner Payment
1. Finance tab → Owner Finances → Payments Received section → tap "Confirm" on unconfirmed payment
2. **Expected:** SnackBar "Payment confirmed"

### Workflow 31: Generate AI Report
1. Manager Dashboard → Reports (via AppBar icon or bottom nav)
2. Reports screen → tap "Generate New Report"
3. Generate Report screen:
   - Select report type: Daily / Weekly / Custom date range
   - Select date(s)
   - Select projects: "All Sites" or specific sites
4. Tap "Generate Report"
5. **Expected:** Loading state "Fetching data..." → Edge Function processes → navigates to Report Detail screen
6. **Error case:** SnackBar: "Could not generate report. Please try again later."

### Workflow 32: Edit & Finalize Report
1. Report Detail screen (after generation or from report list)
2. Two tabs: "MANAGER REPORT" and "OWNER REPORT"
3. Each tab shows markdown-rendered content with edit capabilities
4. **Draft state actions:**
   - "Save Draft" → SnackBar "Draft saved"
   - "Finalize" → confirmation dialog → SnackBar "Reports finalized"
   - "Regenerate" (refresh icon) → confirmation → replaces content with new AI generation
5. **Finalized state actions:**
   - "Revert to Draft" → SnackBar "Reverted to draft"
   - "Send to Owner" → opens send dialog

### Workflow 33: Send Report to Owner
1. Report Detail screen (finalized) → tap "Send to Owner"
2. Send Report dialog:
   - Owner email (auto-populated from project owners)
   - Subject line
   - Optional message
3. Tap "Send"
4. **Expected:** SnackBar "Generating PDF and sending..." → then "Report sent to owner"
5. **Error case:** SnackBar: "Could not send report. Please check your connection and try again."
6. **Sent state:** Shows "Owner report sent on {date}" with "Resend" option

### Workflow 34: Delete Draft Report
1. Reports screen → swipe/action on draft report → "Delete"
2. Confirmation dialog: "This draft report will be permanently deleted. Continue?"
3. Tap "Delete"
4. **Expected:** SnackBar "Report deleted"
5. **Error case:** SnackBar: "Could not delete report. Please try again."

### Workflow 35: Manage AI Prompts
1. Reports screen → tap settings icon (tune) in AppBar
2. AI Report Prompts screen:
   - List of prompts by purpose (Manager Report / Owner Report) and provider (Groq/OpenAI/Gemini)
   - Each shows: name, version, character count, active badge
3. Tap a prompt → Edit dialog:
   - Modify prompt text (monospace editor)
   - Toggle "Save as new version (keeps history)"
4. Tap "Save"
5. **Expected:** SnackBar "New version saved" or "Prompt updated"
6. **Error case:** SnackBar: "Could not save prompt changes. Please try again."

### Workflow 36: Change Dashboard Layout
1. Manager Dashboard → tap layout toggle in AppBar
2. Layout Settings dialog → select Classic or Kanban
3. **Expected:** SnackBar "Switched to {layout name}" → dashboard rebuilds

### Workflow 37: View Feed
1. Manager Dashboard → Feed tab (bottom nav)
2. **Expected:** Activity feed showing voice notes, project updates, team messages
3. Filter by type, date range, person

---

## WORKER WORKFLOWS

### Workflow 38: Record Voice Note (Worker)
1. Worker Home → My Logs tab
2. Tap large microphone button
3. Button changes to red (recording)
4. Speak note
5. Tap button again to stop
6. **Expected:** SnackBar "Voice note submitted" → note appears in list → status updates in real-time (processing → transcribed → completed)
7. **Error case:** SnackBar: "Could not send voice note. Please check your connection and try again."
8. **No project case:** SnackBar: "No project assigned. Please contact your manager."
9. **No mic permission:** SnackBar: "Microphone permission required"

### Workflow 39: View My Logs
1. Worker Home → My Logs tab
2. See list of voice notes (newest first)
3. Each card: timestamp, transcript preview, status badge
4. Tap card to expand → full transcript, audio player, AI analysis, action items
5. **Expected:** Cards update in real-time as Edge Function processes (progressive status)
6. **Empty state:** "No voice notes yet" / "Tap the mic above to create your first note"

### Workflow 40: Delete Voice Note (Worker)
1. My Logs tab → within 5-minute window of creation → tap delete icon
2. Countdown timer shows remaining time
3. Confirm deletion
4. **Expected:** SnackBar "{note deleted}" → note removed from list
5. **Error case:** SnackBar: "Could not delete voice note. Please try again."

### Workflow 41: Reply to Voice Note
1. My Logs tab → expand a note with manager response → tap "Reply"
2. Record voice reply
3. **Expected:** SnackBar "Reply sent" → reply linked to original note

### Workflow 42: View Daily Tasks
1. Worker Home → Daily Tasks tab
2. See list of action items assigned to this worker
3. Each card: priority color, category badge, summary, sender, time
4. Tap to expand → full details, audio player, transcript, AI analysis
5. **Actions available:**
   - Add info (voice): record update
   - Add info (text): type update
   - Mark Complete → status changes
   - Reopen (if completed but not yet approved)
6. **Expected:** Real-time updates when assignments change

### Workflow 43: Check In (Attendance)
1. Worker Home → Attendance tab
2. Current status shown ("Checked Out")
3. Tap "Check In"
4. **If geofenced:** GPS validated against site coordinates
   - Inside radius: check-in succeeds
   - Outside radius: warning shown (proceeds if exempt)
5. **Expected:** Status changes to "Checked In" → elapsed time shown

### Workflow 44: Check Out with Daily Report
1. Attendance tab (while checked in) → tap "Check Out"
2. Optional: record voice daily report or type text
3. GPS validated again if geofenced
4. **Expected:** Check-out timestamp recorded → status changes to "Checked Out" → report saved

### Workflow 45: View Attendance History
1. Attendance tab → scroll down
2. **Expected:** Past records: date, check-in time, check-out time, duration, daily report, geofence status

---

## OWNER WORKFLOWS

### Workflow 46: View Projects (Owner)
1. Owner Dashboard → Projects tab
2. See cards for all linked projects
3. Each card: project name, location, action counts (Pending/Active/Done)
4. **Expected:** Correct counts reflecting real-time data
5. **Empty state:** "No Sites Yet" / "You have no sites linked to your account yet. Ask your manager to add you."

### Workflow 47: View Project Detail (Owner)
1. Projects tab → tap project card
2. **Expected:** Owner Project Detail screen with project info, team list, action item breakdown, financial summary, recent activity

### Workflow 48: Review Approval Requests
1. Owner Dashboard → Approvals tab
2. Filter by: All, Pending, Approved, Denied
3. Each card: type, title, requester, project, amount, status
4. **Expected:** Correct list of approval requests
5. **Empty state:** "No Approvals" / "Approval requests from your manager will appear here."

### Workflow 49: Approve Request
1. Approvals tab → tap pending request → "Approve"
2. Dialog: optional note
3. Tap "Submit"
4. **Expected:** SnackBar "Request approved" → status badge updates → manager notified

### Workflow 50: Deny Request
1. Approvals tab → tap pending request → "Deny"
2. Dialog: reason for denial (required)
3. Tap "Submit"
4. **Expected:** SnackBar "Request denied" → status badge updates → manager notified with reason

### Workflow 51: Add Note to Approval
1. Approvals tab → tap any request → "Add Note"
2. Enter note text
3. Tap "Submit"
4. **Expected:** SnackBar "Note added" → note appended to approval record

### Workflow 52: View Messages (Owner)
1. Owner Dashboard → Messages tab
2. If multiple projects: select project from dropdown
3. View voice notes sent to owner
4. Tap message → play audio, read transcript
5. **Expected:** Messages from managers displayed with sender, timestamp, transcript
6. **Empty state:** "No Messages Yet" / "Record a voice note to start a conversation with your manager."

### Workflow 53: Send Voice Note to Manager (Owner)
1. Messages tab → tap mic button at bottom
2. Recording indicator: "Recording... Tap mic to stop and send"
3. Speak message
4. Tap mic again to stop
5. **Expected:** SnackBar "Voice note sent to manager"
6. **Error case:** SnackBar: "Could not send voice note. Please check your connection and try again."
7. **No mic permission:** SnackBar: "Microphone permission required"

### Workflow 54: View Reports (Owner)
1. Owner Dashboard → Reports tab
2. See list of reports sent by managers
3. Each card: date range, manager name, created date, status
4. Tap card → Owner Report View screen (read-only)
5. **Expected:** Full report rendered in markdown, PDF download available

### Workflow 55: Download Report PDF (Owner)
1. Reports tab → tap report → Owner Report View screen
2. Tap "Download PDF" button
3. **Expected:** PDF generated client-side → share/save dialog
4. **Error case:** SnackBar: "Could not generate PDF. Please try again."

---

## VOICE NOTE & TRANSCRIPTION WORKFLOWS

### Workflow 56: Audio Playback
1. Any screen with voice note → tap play button
2. **Expected:** Audio player shows: play/pause, progress slider, duration
3. Platform-specific: native player on iOS/Android, HTML5 on web

### Workflow 57: Edit Transcription (One-Time Edit)
1. View a voice note with transcription → tap edit icon
2. Edit dialog: modify transcript text
3. Tap "Save"
4. **Expected:** SnackBar "Transcription updated" → lock icon appears → "This transcription has been edited. No further changes allowed."
5. **Already edited:** SnackBar: "This transcription has already been edited. Only one edit is allowed."
6. **Error case:** SnackBar: "Could not save transcription. Please try again."

---

## REAL-TIME UPDATE VERIFICATION

### Workflow 58: Voice Note Progressive Updates
1. Record a voice note (any role)
2. Watch the note card in real-time
3. **Expected:** Status badge updates progressively: processing → transcribed → translated → completed
4. No page refresh needed

### Workflow 59: Cross-Role Notification
1. Manager sends report to owner
2. Owner dashboard → Reports tab
3. **Expected:** New report appears in real-time (or on next tab switch)

### Workflow 60: Finance Real-Time Updates
1. Create an invoice (Manager A)
2. Another manager viewing the same finance tab
3. **Expected:** Invoice appears in real-time for both users

---

## EMPTY STATE VERIFICATION

| Screen | Expected Empty State |
|--------|---------------------|
| My Logs (Worker) | "No voice notes yet" / "Tap the mic above to create your first note" |
| Daily Tasks (Worker) | Loading widget or "No tasks assigned" |
| Attendance (Manager) | "No attendance records for today" |
| Owner Projects | "No Sites Yet" / "You have no sites linked..." |
| Owner Approvals | "No Approvals" / "Approval requests from your manager will appear here." |
| Owner Messages | "No Messages Yet" / "Record a voice note to start a conversation..." |
| Reports list | "No reports yet" / "Tap 'Generate New Report' to create your first AI-powered report" |
| Invoices | "No invoices yet" / "Tap + to create your first invoice" |
| Payments | "No payments yet" / "Tap + to record a payment" |
| Owner Payments | "No payments received" / "Record payments from owners here" |
| Fund Requests | "No fund requests" / "Create a request for funds from the owner" |
| AI Prompts | "No report prompts found" / "Report AI prompts will appear here once seeded" |

---

## ERROR MESSAGE CONSISTENCY CHECK

All error SnackBars should follow the pattern:
`Could not {action}. Please {recovery instruction}.`

No raw exception text (`Error: $e`) should appear.
No emoji in SnackBar messages.
No exclamation marks in success messages.
Success messages: `{Object} {past tense verb}` (e.g., "Invoice created", "Report saved").
