import 'package:flutter/material.dart';
import 'package:houzzdat_app/features/worker/models/voice_note_card_view_model.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/editable_transcription_box.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_audio_player.dart';

class VoiceNoteCard extends StatefulWidget {
  final VoiceNoteCardViewModel viewModel;

  const VoiceNoteCard({
    Key? key,
    required this.viewModel,
  }) : super(key: key);

  @override
  State<VoiceNoteCard> createState() => _VoiceNoteCardState();
}

class _VoiceNoteCardState extends State<VoiceNoteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(),
              const SizedBox(height: 6),
              _LanguageBadge(vm.originalLanguageLabel),
              const SizedBox(height: 8),

              /// Transcript
              EditableTranscriptionBox(
                initialText: vm.transcriptForDisplay(expanded: _expanded),
                canEdit: _expanded && vm.isEditable,
                onSave: (text) {
                  // TODO: Implement save logic
                },
              ),

              /// Audio only when expanded
              if (_expanded) ...[
                const SizedBox(height: 12),
                VoiceNoteAudioPlayer(audioUrl: vm.audioUrl),
              ],

              if (vm.isProcessing) ...[
                const SizedBox(height: 6),
                _StatusIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.mic, size: 18),
        const SizedBox(width: 8),
        Text(
          'Voice Note',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  final String label;
  const _LanguageBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 6),
        Text('Processing...'),
      ],
    );
  }
}