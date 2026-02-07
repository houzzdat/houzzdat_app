What's Built: A Complete Snapshot
Houzzdat (SiteVoice) is a voice-first construction site communication platform with two user roles — Workers on-site and Managers in the office — connected through voice notes that get AI-transcribed, translated, classified, and turned into actionable items. Here's every layer, in detail.

1. Authentication & Multi-Tenant Onboarding
The app has a three-tier identity system. AuthWrapper listens reactively to Supabase's onAuthStateChange stream and routes to one of three screens based on the user's identity. It first checks super_admins — if the logged-in user exists there, they land on SuperAdminScreen. Otherwise it checks public.users for a role field: manager/admin goes to ManagerDashboard, anything else goes to the worker screen.
SuperAdminScreen is the company onboarding tool. It collects a company name, an admin email/password, and a transcription provider choice (Groq, OpenAI, or Gemini). It invokes the create-account-admin Edge Function, which creates an accounts row, a Supabase Auth user with email_confirm: true, and links them in public.users with role admin. The provider choice is stored on the accounts table and used later to route all transcription for that company.
LoginScreen is a minimal email/password form. It calls signInWithPassword and relies entirely on AuthWrapper to react — no manual navigation.

2. Database Schema (Baseline + Migration)
The baseline migration (0000_baseline.sql) defines six tables:

super_admins — references auth.users, stores the platform-level admins.
accounts — one row per company. Has transcription_provider with a CHECK constraint limiting it to groq, openai, or gemini.
projects — construction sites, each tied to an account.
users — the app's user table. Has role, account_id, current_project_id (which site they're currently assigned to), preferred_language, reports_to (for future hierarchy), and department.
voice_notes — the core entity. Stores audio URL, transcription fields (both raw and display), language detection, edit tracking (is_edited, edit_history JSONB), parent threading (parent_id), recipient targeting, and AI classification metadata (category, processed_json).
action_items — auto-generated from voice notes after AI classification. Has category (update/approval/action_required), priority, status workflow (pending → approved/rejected/in_progress/completed), and fields for future Proof-of-Work (proof_photo_url, parent_action_id, is_dependency_locked).
voice_note_forwards — tracks when a voice note is forwarded between users, with slots for the original note, the forwarded note, and an instruction note.

A second migration (20260124122559_add_edit_history_system.sql) added transcript_raw, detected_language_code, and edit_history JSONB to voice_notes, backfilled existing data, added column comments documenting the immutability contract, and created indexes on is_edited, detected_language_code, and a GIN index on edit_history.

3. AI Transcription Pipeline (Edge Function)
transcribe-audio/index.ts is the most complex piece of backend logic. It's a provider-agnostic pipeline with three interchangeable implementations:
GroqProvider uses Whisper-large-v3 for transcription and translation (via the audio endpoints), Llama-3.3-70b for text translation and classification. GeminiProvider sends base64-encoded audio directly to gemini-1.5-flash for both transcription and translation in a single multimodal call, and uses the same model for classification with responseMimeType: "application/json". OpenAIProvider mirrors Groq's structure but uses Whisper-1 and GPT-4o-mini.
The pipeline flow is: fetch the account's provider preference → download the audio from Supabase Storage → transcribe in original language → if not English, translate to English via the audio translation endpoint → translate to any other languages needed by team members (based on their preferred_language) → classify the note using a carefully prompted LLM call → create an action_items row → format and update the voice_notes row with the display transcription, language, translations JSON, and category.
Classification uses a detailed prompt that enforces active-voice, verb-first summaries capped at 15 words. There's a fallbackClassify function using keyword matching for when the LLM call fails — it looks for approval keywords, problem keywords, and defaults to update.

4. Audio Recording & Upload Service
AudioRecorderService handles both web and native platforms. On web it uses the MediaRecorder API via dart:js_interop, collecting BlobEvent chunks and assembling them into a Uint8List on stop. On native it uses the record package with AAC-LC encoding. The uploadAudio method uploads to a Supabase Storage bucket called voice-notes, inserts a voice_notes row with status: 'processing', then manually invokes the transcribe-audio Edge Function passing the new record. It supports optional parentId (for threaded replies) and recipientId (for direct messages).

5. Worker Screen (ConstructionHomeScreen)
The worker's interface is intentionally simple for field use. On init it fetches the user's account_id, current_project_id, and preferred_language. The hero section is a large tap target — a 100px-diameter circle that toggles recording on/off with clear state feedback (yellow mic → red stop, with "Processing..." state while uploading). Below that is a live StreamBuilder feed of all voice notes in their account, ordered by created_at descending, limited to 20 items. Each note renders as a VoiceNoteCard.

6. Voice Note Card System
This is a three-widget composition. VoiceNoteCard is the orchestrator — it fetches the user email and project name, formats the timestamp to IST, and assembles the card from sub-components. It passes isEdited down from the note data. The header shows the sender, a REPLY badge if it's a threaded reply, an EDITED badge if the transcription was modified, and a timestamp.
VoiceNoteAudioPlayer is a self-contained audio player with play/pause, a slider for seeking, and formatted duration counters. It manages its own AudioPlayer lifecycle.
TranscriptionDisplay handles the transcription rendering and editing logic. It parses the [Language] text\n\n[English] translation format using a regex. It renders a language badge with flag emojis for non-English notes. It delegates to EditableTranscriptionBox for each language block.
EditableTranscriptionBox is the actual editable UI. When tapped, it switches from read-only text to a TextField. It enforces a one-time edit lock: if isLocked is true (derived from is_edited), tapping the edit button shows a snackbar warning and refuses to open the editor. The save button is labeled "Save (One-Time Only)" to make the constraint explicit.
There's also a legacy VoiceNotePlayerCard (in voice_note_player_card.dart) that appears to be an older, self-contained version of the card that does its own parsing and rendering inline — it's not currently wired into the main flow based on the imports in the active screens.

7. Manager Dashboard — Dual Layout System
The manager experience has a sophisticated layout-switching architecture. ManagerDashboard is a thin router that checks DashboardSettingsService (a singleton ChangeNotifier backed by SharedPreferences) and renders either ManagerDashboardClassic or ManagerDashboardKanban.
Classic layout is a standard Flutter DefaultTabController with four tabs: Actions, Sites, Team, and Feed. Each tab receives the accountId as a parameter.
Kanban layout uses a custom CustomBottomNav with a raised central FAB for recording. It has five index slots (0: Actions, 1: Sites, 2: placeholder for the FAB, 3: Users, 4: Feed) and uses IndexedStack so tabs don't rebuild on switch. The kanban layout also has its own logout confirmation dialog (LogoutDialog) and a central mic recording flow built directly into the screen.
The layout toggle is available in both layouts via LayoutToggleButton in the AppBar, which opens LayoutSettingsDialog — a card-based picker with radio indicators and an APPLY button.

8. Manager Tabs — Detail
ActionsTab (Classic): Streams action_items filtered by account, groups them into three categories with colored headers (🔴 Action Required, 🟡 Pending Approval, 🟢 Updates), and renders each as an ActionCardWidget. Each card has Approve, Instruct, and Forward actions.
ActionsKanbanTab: Same data source but filtered by a three-stage Kanban workflow: Queue (pending/validating), Active (approved/in_progress), Logs (completed/verified). Uses KanbanStageToggle — a segmented control styled to match the indigo AppBar.
ActionCardWidget: The most feature-rich card in the app. It's expandable — tapping loads the associated voice note lazily. When expanded it shows the audio player and TranscriptionDisplay inline. It has a three-button action bar (Approve, Instruct, Forward) visible when status is pending. There's also a secondary actions bottom sheet triggered by a menu icon, which can set priority or mark items as completed. The Forward button is polymorphic — it checks if onForward is a VoidCallback or a Function(String) and routes accordingly, using a ForwardSelectionSheet bottom sheet to pick a user.
ProjectsTab / SitesManagementTab: CRUD for construction sites. ProjectDialogs provides reusable Add/Edit dialogs and an assign-users dialog with checkboxes. The kanban variant (SitesManagementTab) has a simpler card that fetches and displays the user count per site.
TeamTab / UsersManagementTab: Team member management. TeamDialogs.showInviteStaffDialog invokes the invite-user Edge Function. The edit dialog lets you reassign a user's project. The kanban variant adds a "Send Voice Note" button directly on each user card, with recording state managed per-user.
FeedTab: The full voice note feed with filtering. FeedFiltersWidget provides dropdowns for site and user, plus a date picker chip. Filtering is done client-side on the streamed data. Each note has a "Record Reply" button that starts a threaded reply (sets parentId on the new note).

9. Edit History System of Record
The design is documented in edit_history_flow.md. The contract is: transcript_raw is immutable (set once by AI, never changed). All edits append to the edit_history JSONB array with version numbers, edited_by, edited_at, the text content, and a retranslated flag. The current UI implementation enforces a one-edit-only policy via the is_edited boolean — once you save, the edit buttons lock. The design document describes a future multi-version system with rollback and re-translation, but the current code caps it at one edit.
The transcribe-audio function does not yet write to transcript_raw or detected_language_code — it still writes to transcription and detected_language. The migration and schema are ready, but the Edge Function update described in implementation_summary.md Step 2 has not been applied to the actual function code.

10. Edge Functions — Invite User
invite-user/index.ts handles staff invitation. It checks for duplicate emails by listing all auth users (not ideal at scale, but functional), creates the auth user with user_metadata containing role and account_id (intended to feed a DB trigger), then does a manual insert into public.users as a fallback. It has rollback logic — if the users insert fails with anything other than a duplicate key error (23505), it deletes the auth user to prevent ghost accounts.

11. Core Theme & Shared Widgets
AppTheme centralizes all colors, typography, spacing, radii, and elevation into static constants. It defines a full ThemeData with card styling, button styling, and input decoration. shared_widgets.dart provides: EmptyStateWidget, LoadingWidget, SectionHeader, CategoryBadge, PriorityIndicator (with emoji rendering), ActionButton, and ErrorStateWidget — all used consistently throughout.

Key Gaps / Things Not Yet Wired Up

The transcribe-audio Edge Function hasn't been updated to write transcript_raw and detected_language_code (the migration is there, the function isn't).
The edit_history JSONB append logic isn't in the Flutter code — TranscriptionDisplay sets is_edited: true but doesn't build or append an edit_history entry.
Proof-of-Work (proof_photo_url) columns exist in the schema but have no UI.
The reports_to hierarchy and department fields are in the schema but unused.
VoiceNotePlayerCard (the legacy card) is not referenced by any active screen.
The roles table is referenced in showInviteStaffDialog but not defined in the baseline migration.
