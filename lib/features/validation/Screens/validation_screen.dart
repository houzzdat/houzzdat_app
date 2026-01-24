import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class ValidationScreen extends StatefulWidget {
  final String audioUrl;
  final String projectId;
  final String userId;
  final String accountId;
  final String? parentId;
  final String? recipientId;

  const ValidationScreen({
    super.key,
    required this.audioUrl,
    required this.projectId,
    required this.userId,
    required this.accountId,
    this.parentId,
    this.recipientId,
  });

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  final _supabase = Supabase.instance.client;
  final _summaryController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _transcriptRaw;
  String? _aiSummary;
  String? _noteId;
  bool _hasEdited = false;

  @override
  void initState() {
    super.initState();
    _initializeValidation();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _initializeValidation() async {
    try {
      // 1. Create the voice note record in pending state
      final noteData = {
        'user_id': widget.userId,
        'project_id': widget.projectId,
        'account_id': widget.accountId,
        'audio_url': widget.audioUrl,
        'parent_id': widget.parentId,
        'recipient_id': widget.recipientId,
        'status': 'validating', // New status for validation phase
      };

      final insertedNote = await _supabase
          .from('voice_notes')
          .insert(noteData)
          .select()
          .single();

      setState(() {
        _noteId = insertedNote['id'];
      });

      // 2. Trigger transcription
      await _supabase.functions.invoke('transcribe-audio', body: {
        'record': insertedNote,
      });

      // 3. Poll for transcription completion
      await _pollForTranscription();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing validation: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pollForTranscription() async {
    int attempts = 0;
    const maxAttempts = 30; // 30 seconds max wait
    
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 1));
      
      final note = await _supabase
          .from('voice_notes')
          .select('transcription, status')
          .eq('id', _noteId!)
          .single();

      if (note['status'] == 'completed' && note['transcription'] != null) {
        // Parse the transcription
        final transcription = note['transcription'] as String;
        
        setState(() {
          _transcriptRaw = transcription;
          _aiSummary = _extractSummary(transcription);
          _summaryController.text = _aiSummary ?? '';
          _isLoading = false;
        });
        return;
      }
      
      attempts++;
    }

    // Timeout
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcription timed out. Please try again.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _extractSummary(String transcription) {
    // If it's a translated transcription, extract the English version
    if (transcription.contains('[English]')) {
      final parts = transcription.split('[English]');
      if (parts.length > 1) {
        return parts[1].trim();
      }
    }
    
    // Otherwise, just use the full transcription
    // You can enhance this to create a true summary using AI
    return transcription.trim();
  }

  void _onSummaryChanged(String value) {
    if (!_hasEdited && value != _aiSummary) {
      setState(() => _hasEdited = true);
    }
  }

  Future<void> _handleQuickApprove() async {
    await _submitValidation(useAiSummary: true);
  }

  Future<void> _handleConfirm() async {
    if (_summaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Summary cannot be empty'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    
    await _submitValidation(useAiSummary: false);
  }

  Future<void> _submitValidation({required bool useAiSummary}) async {
    setState(() => _isSubmitting = true);

    try {
      final finalText = useAiSummary ? _aiSummary! : _summaryController.text.trim();
      final isEdited = useAiSummary ? false : (_aiSummary != finalText);

      // Update the voice note with validated data
      await _supabase
          .from('voice_notes')
          .update({
            'transcript_final': finalText,
            'is_edited': isEdited,
            'status': 'processing', // Now ready for full processing
          })
          .eq('id', _noteId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              useAiSummary 
                ? '✅ Voice note approved and submitted!'
                : '✅ Voice note validated and submitted!',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        
        // Return to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting validation: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        appBar: AppBar(
          title: const Text('Processing Voice Note'),
          backgroundColor: AppTheme.primaryIndigo,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryIndigo),
              SizedBox(height: AppTheme.spacingL),
              Text(
                'Transcribing and analyzing...',
                style: AppTheme.bodyLarge,
              ),
              SizedBox(height: AppTheme.spacingS),
              Text(
                'This may take a few seconds',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Verify Your Voice Note'),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.infoBlue),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Text(
                      'Review and verify the AI-generated summary. You can edit it or approve it as-is.',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.infoBlue),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Original Transcript
            Text(
              'ORIGINAL TRANSCRIPT',
              style: AppTheme.headingSmall,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
              ),
              child: Text(
                _transcriptRaw ?? '',
                style: AppTheme.bodyMedium.copyWith(height: 1.5),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Editable Summary
            Text(
              'AI SUMMARY',
              style: AppTheme.headingSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              _hasEdited ? 'Edited by you' : 'Generated by AI',
              style: AppTheme.caption.copyWith(
                color: _hasEdited ? AppTheme.warningOrange : AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: _summaryController,
              maxLines: 5,
              onChanged: _onSummaryChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Enter your summary here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2),
                ),
              ),
              style: AppTheme.bodyMedium,
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Action Buttons
            Column(
              children: [
                // Quick Approve Button
                if (!_hasEdited)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        'QUICK APPROVE',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _handleQuickApprove,
                    ),
                  ),
                
                if (!_hasEdited) const SizedBox(height: AppTheme.spacingM),
                
                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _hasEdited ? Icons.save : Icons.verified,
                      size: 24,
                    ),
                    label: Text(
                      _hasEdited ? 'SAVE & SUBMIT' : 'CONFIRM SUMMARY',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentAmber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleConfirm,
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                // Cancel Button
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Discard Voice Note?'),
                              content: const Text(
                                'This voice note will not be saved. Are you sure?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    // Delete the voice note
                                    await _supabase
                                        .from('voice_notes')
                                        .delete()
                                        .eq('id', _noteId!);
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context); // Close dialog
                                      Navigator.pop(context); // Close validation screen
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorRed,
                                  ),
                                  child: const Text('Discard'),
                                ),
                              ],
                            ),
                          );
                        },
                  child: const Text('Cancel & Discard'),
                ),
              ],
            ),
            
            if (_isSubmitting)
              const Padding(
                padding: EdgeInsets.only(top: AppTheme.spacingM),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
                ),
              ),
          ],
        ),
      ),
    );
  }
}