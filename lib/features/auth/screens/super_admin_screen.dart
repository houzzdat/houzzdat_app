import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/super_admin/tabs/companies_tab.dart';
import 'package:houzzdat_app/features/dashboard/widgets/team_dialogs.dart'
    show kAvailableLanguages;

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _companiesTabKey = GlobalKey<CompaniesTabState>();

  final _companyNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  String _selectedProvider = 'groq';
  List<String> _selectedLanguages = ['en'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onboardCompany() async {
    if (_companyNameController.text.isEmpty ||
        _adminEmailController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final body = <String, dynamic>{
        'company_name': _companyNameController.text.trim(),
        'admin_email': _adminEmailController.text.trim(),
        'admin_password': _adminPasswordController.text.trim(),
        'transcription_provider': _selectedProvider,
      };
      if (_adminNameController.text.trim().isNotEmpty) {
        body['admin_name'] = _adminNameController.text.trim();
      }
      body['admin_languages'] = _selectedLanguages;

      final response = await Supabase.instance.client.functions.invoke(
        'create-account-admin',
        body: body,
      );

      if (response.status == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account & Admin created successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _companyNameController.clear();
        _adminNameController.clear();
        _adminEmailController.clear();
        _adminPasswordController.clear();
        setState(() => _selectedLanguages = ['en']);

        // Refresh and switch to Companies tab to show the new company
        _companiesTabKey.currentState?.refresh();
        _tabController.animateTo(0);
      } else if (mounted) {
        final error = response.data?['error'] ?? 'Failed to create account';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error onboarding company: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('SUPER ADMIN PANEL'),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentAmber,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 18),
                  SizedBox(width: 6),
                  Text('Companies'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_business, size: 18),
                  SizedBox(width: 6),
                  Text('Onboard'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Companies listing
          CompaniesTab(key: _companiesTabKey),

          // Tab 1: Onboard new company form
          _buildOnboardTab(),
        ],
      ),
    );
  }

  Widget _buildOnboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ONBOARD NEW COMPANY',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                children: [
                  _buildTextField(
                      _companyNameController, 'Company Name', Icons.business),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildTextField(
                      _adminNameController, 'Admin Name', Icons.person),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildTextField(
                      _adminEmailController, 'Admin Email', Icons.email),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildTextField(
                      _adminPasswordController, 'Admin Password', Icons.lock,
                      obscure: true),
                  const SizedBox(height: AppTheme.spacingL),
                  const Divider(),
                  const SizedBox(height: AppTheme.spacingM),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Admin Language Preferences',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'English + up to 2 Indian languages',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: kAvailableLanguages.entries.map((entry) {
                      final code = entry.key;
                      final name = entry.value;
                      final isSelected = _selectedLanguages.contains(code);
                      final isEnglish = code == 'en';
                      final atMax =
                          _selectedLanguages.length >= 3 && !isSelected;

                      return FilterChip(
                        label: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : atMax
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryIndigo,
                        checkmarkColor: Colors.white,
                        backgroundColor:
                            atMax ? AppTheme.backgroundGrey : null,
                        onSelected: _isLoading || isEnglish
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected && !atMax) {
                                    _selectedLanguages.add(code);
                                  } else if (!selected) {
                                    _selectedLanguages.remove(code);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  const Divider(),
                  const SizedBox(height: AppTheme.spacingM),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Transcription Settings',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvider,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.record_voice_over),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'groq', child: Text('Free (Groq Whisper)')),
                      DropdownMenuItem(
                          value: 'openai',
                          child: Text('Paid (OpenAI Whisper)')),
                      DropdownMenuItem(
                          value: 'gemini',
                          child: Text('Gemini 1.5 Flash (Google)')),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedProvider = val!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                ),
              ),
              onPressed: _isLoading ? null : _onboardCompany,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('INITIALIZE ACCOUNT',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
