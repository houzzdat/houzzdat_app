import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _companyNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  
  String _selectedProvider = 'groq'; // Default transcription provider
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
          'transcription_provider': _selectedProvider, // Send the choice to your function
        },
      );

      if (response.status == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account & Admin Created!")));
        _companyNameController.clear();
        _adminEmailController.clear();
        _adminPasswordController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4), // Matching Dashboard background
      appBar: AppBar(
        title: const Text("SUPER ADMIN PANEL"),
        backgroundColor: const Color(0xFF1A237E), // Matching Dashboard Indigo
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ONBOARD NEW COMPANY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildTextField(_companyNameController, "Company Name", Icons.business),
                    const SizedBox(height: 16),
                    _buildTextField(_adminEmailController, "Admin Email", Icons.email),
                    const SizedBox(height: 16),
                    _buildTextField(_adminPasswordController, "Admin Password", Icons.lock, obscure: true),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Transcription Settings", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProvider,
                      decoration: const InputDecoration(
                        labelText: "Provider",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.record_voice_over),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'groq', child: Text("Free (Groq Whisper)")),
                        DropdownMenuItem(value: 'openai', child: Text("Paid (OpenAI Whisper)")),
                        DropdownMenuItem(value: 'gemini', child: Text("Gemini 1.5 Flash (Google)")), // NEW OPTION
                      ],
                      onChanged: (val) => setState(() => _selectedProvider = val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107), // Matching Dashboard Amber
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _onboardCompany,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text("INITIALIZE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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