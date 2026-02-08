import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model representing a user's association with a company.
class CompanyAssociation {
  final String associationId;
  final String accountId;
  final String companyName;
  final String role;
  final String status;
  final bool isPrimary;
  final DateTime? joinedAt;

  CompanyAssociation({
    required this.associationId,
    required this.accountId,
    required this.companyName,
    required this.role,
    required this.status,
    required this.isPrimary,
    this.joinedAt,
  });

  factory CompanyAssociation.fromMap(Map<String, dynamic> map) {
    return CompanyAssociation(
      associationId: map['id']?.toString() ?? '',
      accountId: map['account_id']?.toString() ?? '',
      companyName: map['company_name']?.toString() ?? 'Unknown Company',
      role: map['role']?.toString() ?? 'worker',
      status: map['status']?.toString() ?? 'active',
      isPrimary: map['is_primary'] == true,
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'].toString())
          : null,
    );
  }
}

/// Singleton service managing the user's active company context.
/// Follows the same pattern as DashboardSettingsService.
///
/// Handles:
/// - Fetching all company associations for the current user
/// - Tracking the currently active company
/// - Company switching (updates users table for backward compat)
/// - Persisting last selected company via SharedPreferences
class CompanyContextService extends ChangeNotifier {
  static final CompanyContextService _instance =
      CompanyContextService._internal();
  factory CompanyContextService() => _instance;
  CompanyContextService._internal();

  static const String _keyActiveAccount = 'active_account_id';

  final _supabase = Supabase.instance.client;

  String? _userId;
  String? _activeAccountId;
  String? _activeRole;
  String? _activeCompanyName;
  List<CompanyAssociation> _companies = [];
  bool _isInitialized = false;
  bool _isLoading = false;

  // Getters
  String? get userId => _userId;
  String? get activeAccountId => _activeAccountId;
  String? get activeRole => _activeRole;
  String? get activeCompanyName => _activeCompanyName;
  List<CompanyAssociation> get companies => _companies;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// Returns only active company associations.
  List<CompanyAssociation> get activeCompanies =>
      _companies.where((c) => c.status == 'active').toList();

  /// Whether the user belongs to more than one active company.
  bool get hasMultipleCompanies => activeCompanies.length > 1;

  /// Whether a company is currently selected.
  bool get hasActiveCompany => _activeAccountId != null;

  /// Initialize service for the given user ID.
  /// Fetches all company associations and determines active context.
  Future<void> initialize(String userId) async {
    if (_isInitialized && _userId == userId) return;

    _isLoading = true;
    _userId = userId;

    try {
      // Fetch all associations with company names
      final response = await _supabase
          .from('user_company_associations')
          .select('id, account_id, role, status, is_primary, joined_at, accounts!inner(company_name)')
          .eq('user_id', userId)
          .neq('status', 'removed')
          .order('is_primary', ascending: false);

      _companies = (response as List).map((row) {
        final map = Map<String, dynamic>.from(row);
        // Flatten the accounts join
        if (map['accounts'] != null) {
          map['company_name'] = map['accounts']['company_name'];
        }
        return CompanyAssociation.fromMap(map);
      }).toList();

      // Determine which company to activate
      await _resolveActiveCompany();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing CompanyContextService: $e');
      // Fallback: try to get from users table directly
      await _fallbackInitialize(userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fallback initialization using the legacy users table.
  /// Ensures backward compatibility if user_company_associations doesn't exist yet.
  Future<void> _fallbackInitialize(String userId) async {
    try {
      final userData = await _supabase
          .from('users')
          .select('account_id, role')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null) {
        _activeAccountId = userData['account_id']?.toString();
        _activeRole = userData['role']?.toString();

        // Fetch company name
        if (_activeAccountId != null) {
          final account = await _supabase
              .from('accounts')
              .select('company_name')
              .eq('id', _activeAccountId!)
              .maybeSingle();
          _activeCompanyName = account?['company_name']?.toString();
        }

        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('Error in fallback initialization: $e');
    }
  }

  /// Resolves which company should be the active context.
  /// Priority: saved preference > primary company > first active company.
  Future<void> _resolveActiveCompany() async {
    if (activeCompanies.isEmpty) {
      _activeAccountId = null;
      _activeRole = null;
      _activeCompanyName = null;
      return;
    }

    // Check for saved preference
    final prefs = await SharedPreferences.getInstance();
    final savedAccountId = prefs.getString(_keyActiveAccount);

    if (savedAccountId != null) {
      // Verify saved account is still valid and active
      final saved = activeCompanies
          .where((c) => c.accountId == savedAccountId)
          .toList();
      if (saved.isNotEmpty) {
        _setActiveContext(saved.first);
        return;
      }
    }

    // Use primary company
    final primary = activeCompanies.where((c) => c.isPrimary).toList();
    if (primary.isNotEmpty) {
      _setActiveContext(primary.first);
      return;
    }

    // Fall back to first active company
    _setActiveContext(activeCompanies.first);
  }

  void _setActiveContext(CompanyAssociation company) {
    _activeAccountId = company.accountId;
    _activeRole = company.role;
    _activeCompanyName = company.companyName;
  }

  /// Switch to a different company.
  /// Updates users table (backward compat) and saves preference.
  Future<void> switchCompany(String accountId) async {
    final target =
        activeCompanies.where((c) => c.accountId == accountId).toList();
    if (target.isEmpty) {
      debugPrint('Cannot switch to company $accountId - not found in active companies');
      return;
    }

    final company = target.first;
    _setActiveContext(company);

    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveAccount, accountId);
    } catch (e) {
      debugPrint('Error saving company preference: $e');
    }

    // Update users table for backward compatibility
    // This ensures all existing queries (.eq('account_id', ...)) work correctly
    if (_userId != null) {
      try {
        await _supabase.from('users').update({
          'account_id': accountId,
          'role': company.role,
        }).eq('id', _userId!);
      } catch (e) {
        debugPrint('Error updating users table context: $e');
      }
    }

    notifyListeners();
  }

  /// Check if saved selection exists (for auth wrapper routing).
  Future<bool> hasSavedSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyActiveAccount);
      if (saved == null) return false;

      // Verify it's still valid
      return activeCompanies.any((c) => c.accountId == saved);
    } catch (e) {
      return false;
    }
  }

  /// Reset service state (call on logout).
  Future<void> reset() async {
    _userId = null;
    _activeAccountId = null;
    _activeRole = null;
    _activeCompanyName = null;
    _companies = [];
    _isInitialized = false;
    _isLoading = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveAccount);
    } catch (e) {
      debugPrint('Error clearing company preference: $e');
    }

    notifyListeners();
  }

  /// Refresh company list (call after invite/remove operations).
  Future<void> refresh() async {
    if (_userId != null) {
      _isInitialized = false;
      await initialize(_userId!);
    }
  }
}
