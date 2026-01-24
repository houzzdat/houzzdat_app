import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';

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
  final _transcriptionController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPlaying = false;
  String? _originalTranscription;
  String? _detectedLanguage;
  String? _noteId;
  bool _hasEdited = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeValidation();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _transcriptionController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint("Playback Error: $e");
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _initializeValidation() async {
    try {
      // 1. Create the voice note record in validating state
      final noteData = {
        'user_id': widget.userId,
        'project_id': widget.projectId,
        'account_id': widget.accountId,
        'audio_url': widget.audioUrl,
        'parent_id': widget.parentId,
        'recipient_id': widget.recipientId,
        'status': 'validating',
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
    const maxAttempts = 30;
    
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 1));
      
      final note = await _supabase
          .from('voice_notes')
          .select('transcription, detected_language, status')
          .eq('id', _noteId!)
          .single();

      if (note['status'] == 'completed' && note['transcription'] != null) {
        final transcription = note['transcription'] as String;
        final language = note['detected_language'] ?? 'en';
        
        // Extract the original language text (before [English] tag)
        String displayText = _extractOriginalText(transcription, language);
        
        setState(() {
          _originalTranscription = transcription;
          _detectedLanguage = language;
          _transcriptionController.text = displayText;
          _isLoading = false;
        });
        return;
      }
      
      attempts++;
    }

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

  String _extractOriginalText(String transcription, String language) {
    // If it's English, just return the text
    if (language == 'en' || language.toLowerCase() == 'english') {
      return transcription
          .replaceAll('[ENGLISH]', '')
          .replaceAll('[English]', '')
          .trim();
    }
    
    // For non-English, extract the original language text
    if (transcription.contains('[English]')) {
      final parts = transcription.split('[English]');
      if (parts.isNotEmpty) {
        // Remove language tag like [URDU], [Hindi], etc.
        String original = parts[0];
        if (original.contains(']')) {
          final firstBracket = original.indexOf(']');
          if (firstBracket != -1) {
            original = original.substring(firstBracket + 1);
          }
        }
        return original.trim();
      }
    }
    
    return transcription.trim();
  }

  void _onTranscriptionChanged(String value) {
    if (!_hasEdited) {
      setState(() => _hasEdited = true);
    }
  }

  Future<void> _handleQuickApprove() async {
    await _submitValidation(useOriginal: true);
  }

  Future<void> _handleConfirm() async {
    if (_transcriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcription cannot be empty'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    
    await _submitValidation(useOriginal: false);
  }

  Future<void> _submitValidation({required bool useOriginal}) async {
    setState(() => _isSubmitting = true);

    try {
      final originalText = _extractOriginalText(_originalTranscription!, _detectedLanguage!);
      final finalText = useOriginal ? originalText : _transcriptionController.text.trim();
      final isEdited = !useOriginal && (originalText != finalText);

      // Update the voice note with validated data
      await _supabase
          .from('voice_notes')
          .update({
            'transcript_final': finalText,
            'is_edited': isEdited,
            'status': 'processing', // Ready for AI processing
          })
          .eq('id', _noteId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              useOriginal 
                ? '✅ Transcription approved!'
                : '✅ Transcription saved!',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting: $e'),
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
                'Transcribing your voice note...',
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
        title: const Text('Verify Transcription'),
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
                      'Listen and verify the transcription is accurate. Edit if needed.',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.infoBlue),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Audio Player
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      size: 48,
                    ),
                    color: AppTheme.primaryIndigo,
                    onPressed: _togglePlayback,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                          ),
                          child: Slider(
                            value: _position.inSeconds.toDouble(),
                            max: _duration.inSeconds.toDouble() > 0
                                ? _duration.inSeconds.toDouble()
                                : 1.0,
                            onChanged: (value) async {
                              await _audioPlayer.seek(Duration(seconds: value.toInt()));
                            },
                            activeColor: AppTheme.primaryIndigo,
                            inactiveColor: AppTheme.textSecondary.withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(_position), style: AppTheme.caption),
                              Text(_formatDuration(_duration), style: AppTheme.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Transcription Field
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TRANSCRIPTION',
                  style: AppTheme.headingSmall,
                ),
                if (_detectedLanguage != null && _detectedLanguage != 'en')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      _detectedLanguage!.toUpperCase(),
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.warningOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              _hasEdited ? 'Edited by you' : 'AI transcription',
              style: AppTheme.caption.copyWith(
                color: _hasEdited ? AppTheme.warningOrange : AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: _transcriptionController,
              maxLines: 8,
              onChanged: _onTranscriptionChanged,
              style: AppTheme.bodyLarge.copyWith(height: 1.6),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Transcription will appear here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2),
                ),
                contentPadding: const EdgeInsets.all(AppTheme.spacingL),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Action Buttons
            Column(
              children: [
                // Quick Approve (only if not edited)
                if (!_hasEdited)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        'LOOKS GOOD - APPROVE',
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
                
                // Save Changes
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _hasEdited ? Icons.save : Icons.verified,
                      size: 24,
                    ),
                    label: Text(
                      _hasEdited ? 'SAVE CHANGES' : 'CONFIRM',
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
                
                // Cancel
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
                                    await _supabase
                                        .from('voice_notes')
                                        .delete()
                                        .eq('id', _noteId!);
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      Navigator.pop(context);
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