-- RPC function to update voice note status and category.
-- Bypasses PostgREST schema cache issues with ENUM columns by using
-- explicit type casting (p_status::voice_note_status).
-- Called as a fallback when the standard Supabase client update fails.

CREATE OR REPLACE FUNCTION public.update_voice_note_status(
  p_voice_note_id uuid,
  p_status text,
  p_category text,
  p_transcript_final text DEFAULT NULL,
  p_transcript_raw_current text DEFAULT NULL,
  p_transcript_en_current text DEFAULT NULL,
  p_transcription text DEFAULT NULL,
  p_transcript_raw text DEFAULT NULL,
  p_translated_transcription jsonb DEFAULT NULL,
  p_detected_language text DEFAULT NULL,
  p_detected_language_code text DEFAULT NULL,
  p_asr_confidence numeric DEFAULT NULL,
  p_transcript_raw_original text DEFAULT NULL,
  p_transcript_en_original text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  UPDATE public.voice_notes SET
    status = p_status::voice_note_status,
    category = p_category,
    transcript_final = COALESCE(p_transcript_final, transcript_final),
    transcript_raw_current = COALESCE(p_transcript_raw_current, transcript_raw_current),
    transcript_en_current = COALESCE(p_transcript_en_current, transcript_en_current),
    transcription = COALESCE(p_transcription, transcription),
    transcript_raw = COALESCE(p_transcript_raw, transcript_raw),
    translated_transcription = COALESCE(p_translated_transcription, translated_transcription),
    detected_language = COALESCE(p_detected_language, detected_language),
    detected_language_code = COALESCE(p_detected_language_code, detected_language_code),
    asr_confidence = COALESCE(p_asr_confidence, asr_confidence),
    transcript_raw_original = COALESCE(p_transcript_raw_original, transcript_raw_original),
    transcript_en_original = COALESCE(p_transcript_en_original, transcript_en_original)
  WHERE id = p_voice_note_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
