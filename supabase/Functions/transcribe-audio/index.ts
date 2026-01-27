import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

serve(async (req) => {
  try {
    const { voice_note_id } = await req.json();
    if (!voice_note_id) {
      return new Response("voice_note_id required", { status: 400 });
    }

    /* --------------------------------------------------
       1. LOAD VOICE NOTE + CONTEXT
    -------------------------------------------------- */
    const { data: voiceNote, error: vnErr } = await supabase
      .from("voice_notes")
      .select(`
        id,
        audio_url,
        transcript_raw,
        transcription,
        account_id,
        project_id,
        user_id,
        accounts(transcription_provider)
      `)
      .eq("id", voice_note_id)
      .single();

    if (vnErr || !voiceNote) throw vnErr;

    const provider = voiceNote.accounts.transcription_provider;

    /* --------------------------------------------------
       2. FETCH PROMPTS FROM REGISTRY
    -------------------------------------------------- */
    const { data: promptRow, error: promptErr } = await supabase
      .from("ai_prompts")
      .select("*")
      .eq("provider", provider)
      .eq("purpose", "voice_note_analysis")
      .eq("is_active", true)
      .order("version", { ascending: false })
      .limit(1)
      .single();

    if (promptErr || !promptRow) throw promptErr;

    /* --------------------------------------------------
       3. TRANSCRIPTION (ONLY IF NOT DONE)
    -------------------------------------------------- */
    let transcriptRaw = voiceNote.transcript_raw;

    if (!transcriptRaw) {
      transcriptRaw = await transcribeAudio(
        provider,
        voiceNote.audio_url
      );

      await supabase
        .from("voice_notes")
        .update({
          transcript_raw: transcriptRaw.raw_text,
          detected_language: transcriptRaw.language,
          detected_language_code: transcriptRaw.language_code
        })
        .eq("id", voice_note_id);
    }

    /* --------------------------------------------------
       4. AI INTERPRETATION (STRICT JSON)
    -------------------------------------------------- */
    const aiResponse = await runLLM(provider, {
      system_prompt: promptRow.system_prompt,
      user_prompt: promptRow.user_prompt_template
        .replace("{{TRANSCRIPT}}", transcriptRaw.raw_text)
        .replace("{{LANGUAGE}}", transcriptRaw.language),
      output_schema: promptRow.output_schema
    });

    /* --------------------------------------------------
       5. STORE AI OUTPUT (IMMUTABLE)
    -------------------------------------------------- */
    await supabase.from("voice_note_ai_outputs").insert({
      voice_note_id,
      provider,
      prompt_version: promptRow.version,
      ai_output: aiResponse,
      confidence_score: aiResponse.confidence_score,
      explanation: aiResponse.reasoning
    });

    /* --------------------------------------------------
       6. MATERIAL / LABOUR EXTRACTION
    -------------------------------------------------- */
    if (aiResponse.procurement_intent?.detected) {
      await supabase.from("material_requests").insert({
        voice_note_id,
        project_id: voiceNote.project_id,
        account_id: voiceNote.account_id,
        items: aiResponse.procurement_intent.items,
        urgency: aiResponse.procurement_intent.urgency,
        confidence: aiResponse.procurement_intent.confidence
      });
    }

    /* --------------------------------------------------
       7. ACTION ITEMS
    -------------------------------------------------- */
    if (aiResponse.action_required) {
      await supabase.from("action_items").insert({
        voice_note_id,
        project_id: voiceNote.project_id,
        account_id: voiceNote.account_id,
        category: aiResponse.category,
        summary: aiResponse.summary,
        priority: aiResponse.priority,
        ai_analysis: aiResponse.reasoning
      });
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500 }
    );
  }
});

/* ======================================================
   PROVIDER ABSTRACTIONS
====================================================== */

async function transcribeAudio(provider: string, audioUrl: string) {
  // Placeholder — provider-specific SDK call
  return {
    raw_text: "...native language transcript...",
    language: "Hindi",
    language_code: "hi"
  };
}

async function runLLM(provider: string, payload: any) {
  // Placeholder — provider-specific LLM call
  // MUST return JSON matching output_schema
  return JSON.parse("{}");
}
