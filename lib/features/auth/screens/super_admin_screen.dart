import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _companyNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  String _selectedProvider = 'groq';
  bool _isLoading = false;

  Future<void> _onboardCompany() async {
    if (_companyNameController.text.isEmpty || _adminEmailController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-account-admin',
        body: {
          'company_name': _companyNameController.text.trim(),
          'admin_email': _adminEmailController.text.trim(),
          'admin_password': _adminPasswordController.text.trim(),
          'transcription_provider': _selectedProvider,
        },
      );

      if (response.status == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account & Admin created successfully')),
        );
        _companyNameController.clear();
        _adminEmailController.clear();
        _adminPasswordController.clear();
      }
    } catch (e) {
      debugPrint('Error onboarding company: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create account. Please try again.'),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ONBOARD NEW COMPANY',
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  children: [
                    _buildTextField(_companyNameController, 'Company Name', Icons.business),
                    const SizedBox(height: AppTheme.spacingM),
                    _buildTextField(_adminEmailController, 'Admin Email', Icons.email),
                    const SizedBox(height: AppTheme.spacingM),
                    _buildTextField(_adminPasswordController, 'Admin Password', Icons.lock, obscure: true),
                    const SizedBox(height: AppTheme.spacingL),
                    const Divider(),
                    const SizedBox(height: AppTheme.spacingM),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Transcription Settings', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        DropdownMenuItem(value: 'groq', child: Text('Free (Groq Whisper)')),
                        DropdownMenuItem(value: 'openai', child: Text('Paid (OpenAI Whisper)')),
                        DropdownMenuItem(value: 'gemini', child: Text('Gemini 1.5 Flash (Google)')),
                      ],
                      onChanged: (val) => setState(() => _selectedProvider = val!),
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
                  : const Text('INITIALIZE ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
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
