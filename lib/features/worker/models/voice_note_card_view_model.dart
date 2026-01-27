class VoiceNoteCardViewModel {
  final String id;

  /// Original language transcript (always shown when collapsed)
  final String originalTranscript;

  /// Optional translated transcript (shown only when expanded)
  final String? translatedTranscript;

  /// Human-readable language label (e.g. "हिंदी", "தமிழ்", "EN")
  final String originalLanguageLabel;

  final String audioUrl;

  final bool isEditable;
  final bool isProcessing;

  VoiceNoteCardViewModel({
    required this.id,
    required this.originalTranscript,
    required this.originalLanguageLabel,
    required this.audioUrl,
    this.translatedTranscript,
    this.isEditable = false,
    this.isProcessing = false,
  });

  /// UI decides which transcript to show
  String transcriptForDisplay({required bool expanded}) {
    if (expanded && translatedTranscript != null) {
      return translatedTranscript!;
    }
    return originalTranscript;
  }
}
