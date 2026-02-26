/// UX-audit #25: Centralized string constants for future localization.
///
/// All user-facing strings should be referenced from this class.
/// When l10n is integrated (flutter_localizations + ARB files),
/// these will be replaced with `AppLocalizations.of(context).xxx`.
///
/// Usage:
/// ```dart
/// Text(AppStrings.loginTitle)
/// ```
class AppStrings {
  AppStrings._();

  // ── Auth ──────────────────────────────────────────────────────
  static const loginTitle = 'Welcome to SiteVoice';
  static const loginSubtitle = 'Sign in to continue';
  static const loginEmail = 'Email';
  static const loginPassword = 'Password';
  static const loginButton = 'Sign In';
  static const loginForgotPassword = 'Forgot Password?';
  static const setPasswordTitle = 'Set Password';
  static const setPasswordSubtitle = 'Create a secure password for your account';
  static const logoutConfirmTitle = 'Log Out';
  static const logoutConfirmMessage = 'Are you sure you want to log out?';

  // ── Common ────────────────────────────────────────────────────
  static const appName = 'SiteVoice';
  static const ok = 'OK';
  static const cancel = 'Cancel';
  static const save = 'Save';
  static const delete = 'Delete';
  static const edit = 'Edit';
  static const submit = 'Submit';
  static const retry = 'Retry';
  static const loading = 'Loading...';
  static const noData = 'No data available';
  static const required = 'Required';
  static const invalidAmount = 'Invalid amount';
  static const amountMustBePositive = 'Amount must be greater than zero';
  static const selectSite = 'Please select a site';
  static const selectOwner = 'Please select an owner';
  static const settings = 'Settings';
  static const search = 'Search...';
  static const noResults = 'No results';

  // ── Navigation ────────────────────────────────────────────────
  static const tabActions = 'Actions';
  static const tabSites = 'Sites';
  static const tabTeam = 'Team';
  static const tabFinance = 'Finance';
  static const tabMyLogs = 'My Logs';
  static const tabTasks = 'Tasks';
  static const tabAttendance = 'Attendance';
  static const tabProgress = 'Progress';
  static const tabProjects = 'Projects';
  static const tabApprovals = 'Approvals';
  static const tabMessages = 'Messages';
  static const tabReports = 'Reports';

  // ── Voice Recording ───────────────────────────────────────────
  static const micPermissionRequired = 'Microphone permission required';
  static const noProjectAssigned = 'No project assigned. Please contact your manager.';
  static const voiceNoteSent = 'Sent!';
  static const voiceNoteFailed = 'Could not send voice note. Please try again.';
  static const tapToRecord = 'Tap to record';
  static const recording = 'Recording...';
  static const uploading = 'Uploading...';

  // ── Manager Dashboard ─────────────────────────────────────────
  static const managerTitle = 'Dashboard';
  static const insights = 'Insights';
  static const reports = 'Reports';
  static const switchCompany = 'Switch Company';

  // ── Finance ───────────────────────────────────────────────────
  static const newFundRequest = 'New Fund Request';
  static const newInvoice = 'New Invoice';
  static const addPayment = 'Add Payment';
  static const recordOwnerPayment = 'Record Owner Payment';
  static const submitRequest = 'Submit Request';
  static const saveAsDraft = 'Save as Draft';
  static const createAndSubmit = 'Create & Submit';
  static const invoiceNumber = 'Invoice Number';
  static const vendorSupplier = 'Vendor / Supplier';
  static const amount = 'Amount';
  static const dueDate = 'Due Date';
  static const paymentMethod = 'Payment Method';
  static const referenceNumber = 'Reference Number';
  static const paidTo = 'Paid To';
  static const paymentDate = 'Payment Date';
  static const description = 'Description';
  static const notes = 'Notes';
  static const title = 'Title';
  static const urgency = 'Urgency';
  static const urgencyLow = 'Low';
  static const urgencyNormal = 'Normal';
  static const urgencyHigh = 'High';
  static const urgencyCritical = 'Critical';
  static const submitForApproval = 'Submit for approval immediately';

  // ── Approvals ─────────────────────────────────────────────────
  static const approve = 'APPROVE';
  static const deny = 'DENY';
  static const addNote = 'ADD NOTE';
  static const swipeApprove = 'Approve';
  static const swipeDeny = 'Deny';
  static const approvalRequest = 'Approval Request';
  static const partialApproval = 'Partial Approval';

  // ── Sites / Projects ──────────────────────────────────────────
  static const siteManagement = 'Site Management';
  static const newSite = 'New Site';
  static const createFirstSite = 'Create First Site';
  static const noSitesYet = 'No sites yet';
  static const noSitesSubtitle = 'Create your first construction site to get started';
  static const assignUsers = 'Assign Users';
  static const assignOwner = 'Assign Owner';
  static const deleteSiteConfirm = 'Delete Site?';

  // ── Reports ───────────────────────────────────────────────────
  static const savedReports = 'Saved Reports';
  static const dailyReports = 'Daily Reports';
  static const generateNewReport = 'Generate New Report';
  static const noReportsYet = 'No reports yet';
  static const noReportsSubtitle = 'Tap "Generate New Report" to create your first AI-powered report';
  static const manageAIPrompts = 'Manage AI Prompts';

  // ── Empty States ──────────────────────────────────────────────
  static const noInvoices = 'No invoices yet';
  static const noPayments = 'No payments yet';
  static const noFundRequests = 'No fund requests yet';
  static const noTeamMembers = 'No team members';
  static const noMessages = 'No messages yet';
  static const noAttendanceRecords = 'No attendance records';

  // ── Onboarding Coach Marks ────────────────────────────────────
  static const onboardingRecordTitle = 'Record Voice Notes';
  static const onboardingRecordSubtitle = 'Tap the mic button to record updates. Long press to broadcast to your team.';
  static const onboardingTriageTitle = 'Triage Actions';
  static const onboardingTriageSubtitle = 'Review and assign actions from the Actions tab. Approve, reassign, or escalate.';
  static const onboardingTrackTitle = 'Track Progress';
  static const onboardingTrackSubtitle = 'Monitor site KPIs, finances, and team attendance from the dashboard.';
  static const onboardingReportsTitle = 'Generate Reports';
  static const onboardingReportsSubtitle = 'Create AI-powered reports from your voice notes and site data.';
  static const gotIt = 'Got it!';
  static const next = 'Next';
  static const skip = 'Skip';

  // ── Errors ────────────────────────────────────────────────────
  static const genericError = 'Something went wrong. Please try again.';
  static const networkError = 'Please check your internet connection.';
  static const imageUnavailable = 'Image unavailable';
  static const couldNotCreateSite = 'Could not create site. Please try again.';
  static const failedToBroadcast = 'Failed to send broadcast';

  // ── Payment Methods ───────────────────────────────────────────
  static const cash = 'Cash';
  static const bankTransfer = 'Bank Transfer';
  static const upi = 'UPI';
  static const cheque = 'Cheque';
  static const other = 'Other';

  // ── Attendance ────────────────────────────────────────────────
  static const checkIn = 'Check In';
  static const checkOut = 'Check Out';
  static const onSite = 'ON SITE';
  static const checkedOut = 'CHECKED OUT';
  static const allSites = 'All Sites';
  static const today = 'Today';
  static const workers = 'workers';
  static const checkIns = 'check-ins';
}
