import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

/// Admin screen for viewing and editing AI report prompts.
class PromptsManagementScreen extends StatefulWidget {
  final String accountId;
  const PromptsManagementScreen({super.key, required this.accountId});

  @override
  State<PromptsManagementScreen> createState() => _PromptsManagementScreenState();
}

class _PromptsManagementScreenState extends State<PromptsManagementScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _prompts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    try {
      final data = await _supabase
          .from('ai_prompts')
          .select('*')
          .or('purpose.eq.manager_report_generation,purpose.eq.owner_report_generation')
          .order('purpose')
          .order('provider');

      if (mounted) {
        setState(() {
          _prompts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading prompts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editPrompt(Map<String, dynamic> prompt) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditPromptDialog(prompt: prompt),
    );

    if (result != null) {
      try {
        final saveAsNew = result['save_as_new'] == true;
        final newPromptText = result['prompt_text']?.toString() ?? '';

        if (saveAsNew) {
          // Deactivate old version
          await _supabase
              .from('ai_prompts')
              .update({'is_active': false})
              .eq('id', prompt['id']);

          // Insert new version
          await _supabase.from('ai_prompts').insert({
            'name': prompt['name'],
            'provider': prompt['provider'],
            'purpose': prompt['purpose'],
            'prompt': newPromptText,
            'version': (prompt['version'] as int? ?? 1) + 1,
            'is_active': true,
            'output_schema': prompt['output_schema'],
          });
        } else {
          // Update in place
          await _supabase.from('ai_prompts').update({
            'prompt': newPromptText,
          }).eq('id', prompt['id']);
        }

        await _loadPrompts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(saveAsNew ? 'New version saved' : 'Prompt updated'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error saving prompt: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save prompt changes. Please try again.'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  String _purposeLabel(String purpose) {
    switch (purpose) {
      case 'manager_report_generation':
        return 'Manager Report';
      case 'owner_report_generation':
        return 'Owner Report';
      default:
        return purpose;
    }
  }

  Color _providerColor(String provider) {
    switch (provider) {
      case 'groq':
        return AppTheme.warningOrange;
      case 'openai':
        return AppTheme.successGreen;
      case 'gemini':
        return AppTheme.infoBlue;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('AI Report Prompts', style: TextStyle(fontSize: 16)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading prompts...')
          : _prompts.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.text_snippet_outlined,
                  title: 'No report prompts found',
                  subtitle: 'Report AI prompts will appear here once seeded in the database',
                )
              : RefreshIndicator(
                  onRefresh: _loadPrompts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    itemCount: _prompts.length,
                    itemBuilder: (context, i) {
                      final prompt = _prompts[i];
                      final name = prompt['name']?.toString() ?? 'Unnamed';
                      final provider = prompt['provider']?.toString() ?? 'unknown';
                      final purpose = prompt['purpose']?.toString() ?? '';
                      final version = prompt['version'] as int? ?? 1;
                      final isActive = prompt['is_active'] == true;
                      final promptText = prompt['prompt']?.toString() ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusL),
                          border: Border.all(
                            color: isActive
                                ? AppTheme.successGreen.withValues(alpha: 0.3)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingXS,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _purposeLabel(purpose),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              CategoryBadge(
                                text: provider.toUpperCase(),
                                color: _providerColor(provider),
                              ),
                              const SizedBox(width: 6),
                              if (isActive)
                                const CategoryBadge(
                                  text: 'Active',
                                  color: AppTheme.successGreen,
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                name,
                                style: AppTheme.caption,
                              ),
                              Text(
                                'Version $version \u2022 ${promptText.length} chars',
                                style: AppTheme.caption,
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: AppTheme.primaryIndigo),
                            onPressed: () => _editPrompt(prompt),
                          ),
                          onTap: () => _editPrompt(prompt),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Dialog for editing an AI prompt.
class _EditPromptDialog extends StatefulWidget {
  final Map<String, dynamic> prompt;
  const _EditPromptDialog({required this.prompt});

  @override
  State<_EditPromptDialog> createState() => _EditPromptDialogState();
}

class _EditPromptDialogState extends State<_EditPromptDialog> {
  late TextEditingController _controller;
  bool _saveAsNew = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.prompt['prompt']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.prompt['name']?.toString() ?? 'Prompt';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.text_snippet, color: AppTheme.primaryIndigo),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    'Edit: $name',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Prompt text editor
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryIndigo,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(AppTheme.spacingS),
                    hintText: 'Enter prompt text...',
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Save as new version toggle
            CheckboxListTile(
              value: _saveAsNew,
              onChanged: (v) => setState(() => _saveAsNew = v ?? true),
              title: const Text(
                'Save as new version (keeps history)',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppTheme.primaryIndigo,
            ),

            const SizedBox(height: AppTheme.spacingS),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'prompt_text': _controller.text.trim(),
                        'save_as_new': _saveAsNew,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryIndigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
