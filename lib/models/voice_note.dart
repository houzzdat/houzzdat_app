import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `voice_notes` table.
///
/// CI-07: Core entity — SiteVoice's primary data input. Used in
/// voice_note_audio_player.dart, voice_note_card.dart, log_card.dart,
/// action_card_widget.dart, and 10+ other files.
class VoiceNote {
  final String id;
  final String? userId;
  final String? projectId;
  final String? accountId;
  final String? audioUrl;
  final String? transcription;
  final String? transcriptFinal;
  final String? transcriptEnCurrent;
  final String? transcriptRawCurrent;
  final String? transcriptRaw;
  final String? detectedLanguageCode;
  final String? status;
  final bool isEdited;
  final double? duration;
  final int? fileSize;
  final String? quickTag;
  final String? reportVoiceNoteId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VoiceNote({
    required this.id,
    this.userId,
    this.projectId,
    this.accountId,
    this.audioUrl,
    this.transcription,
    this.transcriptFinal,
    this.transcriptEnCurrent,
    this.transcriptRawCurrent,
    this.transcriptRaw,
    this.detectedLanguageCode,
    this.status,
    this.isEdited = false,
    this.duration,
    this.fileSize,
    this.quickTag,
    this.reportVoiceNoteId,
    this.createdAt,
    this.updatedAt,
  });

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    return VoiceNote(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      projectId: json['project_id']?.toString(),
      accountId: json['account_id']?.toString(),
      audioUrl: json['audio_url']?.toString(),
      transcription: json['transcription']?.toString(),
      transcriptFinal: json['transcript_final']?.toString(),
      transcriptEnCurrent: json['transcript_en_current']?.toString(),
      transcriptRawCurrent: json['transcript_raw_current']?.toString(),
      transcriptRaw: json['transcript_raw']?.toString(),
      detectedLanguageCode: json['detected_language_code']?.toString(),
      status: json['status']?.toString(),
      isEdited: JsonHelpers.toBool(json['is_edited']),
      duration: JsonHelpers.toDouble(json['duration']),
      fileSize: JsonHelpers.toInt(json['file_size']),
      quickTag: json['quick_tag']?.toString(),
      reportVoiceNoteId: json['report_voice_note_id']?.toString(),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
      updatedAt: JsonHelpers.tryParseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'project_id': projectId,
    'account_id': accountId,
    'audio_url': audioUrl,
    'transcription': transcription,
    'transcript_final': transcriptFinal,
    'transcript_en_current': transcriptEnCurrent,
    'transcript_raw_current': transcriptRawCurrent,
    'transcript_raw': transcriptRaw,
    'detected_language_code': detectedLanguageCode,
    'status': status,
    'is_edited': isEdited,
    'duration': duration,
    'file_size': fileSize,
    'quick_tag': quickTag,
    'report_voice_note_id': reportVoiceNoteId,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// Best available transcript: final > en_current > raw_current > transcription > raw.
  String get bestTranscript =>
      transcriptFinal ??
      transcriptEnCurrent ??
      transcriptRawCurrent ??
      transcription ??
      transcriptRaw ??
      '';

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasTranscript => bestTranscript.isNotEmpty;

  VoiceNote copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? accountId,
    String? audioUrl,
    String? transcription,
    String? transcriptFinal,
    String? transcriptEnCurrent,
    String? transcriptRawCurrent,
    String? transcriptRaw,
    String? detectedLanguageCode,
    String? status,
    bool? isEdited,
    double? duration,
    int? fileSize,
    String? quickTag,
    String? reportVoiceNoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoiceNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      accountId: accountId ?? this.accountId,
      audioUrl: audioUrl ?? this.audioUrl,
      transcription: transcription ?? this.transcription,
      transcriptFinal: transcriptFinal ?? this.transcriptFinal,
      transcriptEnCurrent: transcriptEnCurrent ?? this.transcriptEnCurrent,
      transcriptRawCurrent: transcriptRawCurrent ?? this.transcriptRawCurrent,
      transcriptRaw: transcriptRaw ?? this.transcriptRaw,
      detectedLanguageCode: detectedLanguageCode ?? this.detectedLanguageCode,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      quickTag: quickTag ?? this.quickTag,
      reportVoiceNoteId: reportVoiceNoteId ?? this.reportVoiceNoteId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VoiceNote && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VoiceNote(id: $id, status: $status, lang: $detectedLanguageCode)';
}
