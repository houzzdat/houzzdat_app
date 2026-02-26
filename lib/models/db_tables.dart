/// CI-10: Centralised database table and column name constants.
///
/// Prevents hardcoded string literals scattered across 60+ files.
/// Renaming a table or column now requires a single change here.
class DbTables {
  DbTables._();

  static const String users = 'users';
  static const String accounts = 'accounts';
  static const String projects = 'projects';
  static const String actionItems = 'action_items';
  static const String voiceNotes = 'voice_notes';
  static const String voiceNoteEdits = 'voice_note_edits';
  static const String voiceNoteForwards = 'voice_note_forwards';
  static const String attendance = 'attendance';
  static const String reports = 'reports';
  static const String ownerApprovals = 'owner_approvals';
  static const String ownerPayments = 'owner_payments';
  static const String fundRequests = 'fund_requests';
  static const String payments = 'payments';
  static const String invoices = 'invoices';
  static const String financeTransactions = 'finance_transactions';
  static const String notifications = 'notifications';
  static const String projectOwners = 'project_owners';
  static const String projectMembers = 'project_members';
  static const String projectMilestones = 'project_milestones';
  static const String projectBudgets = 'project_budgets';
  static const String projectPlans = 'project_plans';
  static const String boqItems = 'boq_items';
  static const String superAdmins = 'super_admins';
  static const String userCompanyAssociations = 'user_company_associations';
  static const String aiPrompts = 'ai_prompts';
  static const String aiCorrections = 'ai_corrections';
  static const String materialRequests = 'material_requests';
}

/// Common column names used across multiple tables.
class DbColumns {
  DbColumns._();

  // Shared columns
  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String accountId = 'account_id';
  static const String projectId = 'project_id';
  static const String userId = 'user_id';
  static const String status = 'status';

  // Users
  static const String email = 'email';
  static const String fullName = 'full_name';
  static const String phoneNumber = 'phone_number';
  static const String role = 'role';
  static const String currentProjectId = 'current_project_id';
  static const String quickTagEnabled = 'quick_tag_enabled';
  static const String geofenceExempt = 'geofence_exempt';

  // Projects
  static const String name = 'name';
  static const String location = 'location';
  static const String siteLatitude = 'site_latitude';
  static const String siteLongitude = 'site_longitude';
  static const String geofenceRadiusM = 'geofence_radius_m';

  // Action Items
  static const String summary = 'summary';
  static const String priority = 'priority';
  static const String category = 'category';
  static const String voiceNoteId = 'voice_note_id';
  static const String confidenceScore = 'confidence_score';
  static const String needsReview = 'needs_review';
  static const String isCriticalFlag = 'is_critical_flag';
  static const String correctionType = 'correction_type';
  static const String assignedTo = 'assigned_to';
  static const String proofPhotoUrl = 'proof_photo_url';
  static const String interactionHistory = 'interaction_history';

  // Voice Notes
  static const String audioUrl = 'audio_url';
  static const String transcription = 'transcription';
  static const String transcriptFinal = 'transcript_final';
  static const String transcriptEnCurrent = 'transcript_en_current';
  static const String transcriptRawCurrent = 'transcript_raw_current';
  static const String transcriptRaw = 'transcript_raw';
  static const String detectedLanguageCode = 'detected_language_code';
  static const String isEdited = 'is_edited';
  static const String reportVoiceNoteId = 'report_voice_note_id';

  // Finance
  static const String amount = 'amount';
  static const String currency = 'currency';
  static const String approvedAmount = 'approved_amount';
  static const String confirmedBy = 'confirmed_by';
  static const String confirmedAt = 'confirmed_at';
  static const String receivedDate = 'received_date';
  static const String paymentDate = 'payment_date';

  // Owner Approvals
  static const String ownerId = 'owner_id';
  static const String requestedBy = 'requested_by';
  static const String ownerResponse = 'owner_response';
  static const String respondedAt = 'responded_at';
  static const String actionItemId = 'action_item_id';

  // Attendance
  static const String checkInAt = 'check_in_at';
  static const String checkOutAt = 'check_out_at';
  static const String reportType = 'report_type';

  // Reports
  static const String title = 'title';
  static const String content = 'content';
  static const String createdBy = 'created_by';
  static const String reportTypeCol = 'report_type';
  static const String periodStart = 'period_start';
  static const String periodEnd = 'period_end';
  static const String sentAt = 'sent_at';
}
