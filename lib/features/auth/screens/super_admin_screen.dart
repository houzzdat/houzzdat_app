import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/super_admin/tabs/companies_tab.dart';
import 'package:houzzdat_app/features/super_admin/tabs/health_score_config_tab.dart';
import 'package:houzzdat_app/features/super_admin/tabs/ai_evals_tab.dart';
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

  final _formKey = GlobalKey<FormState>();
  String _selectedProvider = 'groq';
  String _sarvamPipelineMode = 'two_step';
  List<String> _selectedLanguages = ['en'];
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final body = <String, dynamic>{
        'company_name': _companyNameController.text.trim(),
        'admin_email': _adminEmailController.text.trim(),
        'admin_password': _adminPasswordController.text.trim(),
        'transcription_provider': _selectedProvider,
        if (_selectedProvider == 'sarvam')
          'sarvam_pipeline_mode': _sarvamPipelineMode,
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
        final createdEmail = _adminEmailController.text.trim();

        _companyNameController.clear();
        _adminNameController.clear();
        _adminEmailController.clear();
        _adminPasswordController.clear();
        setState(() {
          _selectedLanguages = ['en'];
          _selectedProvider = 'groq';
          _sarvamPipelineMode = 'two_step';
        });

        // Show success dialog with created email
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 48),
            title: const Text('Account Created'),
            content: Text(
              'The admin can sign in with:\n$createdEmail',
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );

        // Refresh and switch to Companies tab
        _companiesTabKey.currentState?.refresh();
        _tabController.animateTo(0);
      } else if (mounted) {
        // Try to parse specific error from response
        final errorMsg = response.data?['error']?.toString()
            ?? 'Could not create account. Please check the details and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error onboarding company: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
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
        title: const Text('Super Admin Panel'),
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
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
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune, size: 18),
                  SizedBox(width: 6),
                  Text('Settings'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, size: 18),
                  SizedBox(width: 6),
                  Text('AI Evals'),
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

          // Tab 2: Settings (health score weights, etc.)
          const HealthScoreConfigTab(),

          // Tab 3: AI Evals dashboard links
          const AiEvalsTab(),
        ],
      ),
    );
  }

  Widget _buildOnboardTab() {
    return AbsorbPointer(
      absorbing: _isLoading,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Onboard New Company',
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
                      TextFormField(
                        controller: _companyNameController,
                        decoration: const InputDecoration(
                          labelText: 'Company Name',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Company name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Company name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: _adminNameController,
                        decoration: const InputDecoration(
                          labelText: 'Admin Name (optional)',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: _adminEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Admin Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                          hintText: 'admin@company.com',
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Admin email is required';
                          }
                          final emailRegex =
                              RegExp(r'^[\w\-.+]+@([\w\-]+\.)+[\w\-]{2,}$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: _adminPasswordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          helperText: 'Min 8 chars, include a number and symbol',
                          helperMaxLines: 2,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!RegExp(r'[0-9]').hasMatch(value)) {
                            return 'Password must include at least one number';
                          }
                          if (!RegExp(
                                  r'[!@#\$%\^&\*\(\)_\+\-=\[\]\{\};:,.<>?/\\|`~]')
                              .hasMatch(value)) {
                            return 'Password must include at least one symbol';
                          }
                          return null;
                        },
                      ),
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
                        children:
                            kAvailableLanguages.entries.map((entry) {
                          final code = entry.key;
                          final name = entry.value;
                          final isSelected =
                              _selectedLanguages.contains(code);
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
                              value: 'groq',
                              child: Text('Fast & Free (Groq Whisper)')),
                          DropdownMenuItem(
                              value: 'openai',
                              child: Text('High Accuracy (OpenAI Whisper)')),
                          DropdownMenuItem(
                              value: 'gemini',
                              child: Text('Gemini 1.5 Flash (Google)')),
                          DropdownMenuItem(
                              value: 'sarvam',
                              child:
                                  Text('Indian Languages (Sarvam AI)')),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedProvider = val!),
                      ),
                      if (_selectedProvider == 'sarvam') ...[
                        const SizedBox(height: AppTheme.spacingM),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Sarvam Pipeline Mode',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        RadioListTile<String>(
                          title: const Text(
                              'Full Pipeline (ASR + Translate)',
                              style: TextStyle(fontSize: 13)),
                          subtitle: const Text(
                            'Preserves original-language transcript + English translation. 2 API calls.',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: 'two_step',
                          groupValue: _sarvamPipelineMode,
                          dense: true,
                          onChanged: (val) =>
                              setState(() => _sarvamPipelineMode = val!),
                        ),
                        RadioListTile<String>(
                          title: const Text(
                              'Quick Translate (Direct to English)',
                              style: TextStyle(fontSize: 13)),
                          subtitle: const Text(
                            'English output only, faster. 1 API call.',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: 'single',
                          groupValue: _sarvamPipelineMode,
                          dense: true,
                          onChanged: (val) =>
                              setState(() => _sarvamPipelineMode = val!),
                        ),
                      ],
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
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusL),
                    ),
                  ),
                  onPressed: _isLoading ? null : _onboardCompany,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.black)
                      : const Text('Initialize Account',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
