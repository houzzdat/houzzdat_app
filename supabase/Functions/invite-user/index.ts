// Supabase Edge Runtime
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// -----------------------------------------------------------------------------
// SERVE WRAPPER (Supabase standard)
// -----------------------------------------------------------------------------
const serve = (handler: (req: Request) => Promise<Response>) => {
  Deno.serve(handler)
}

// -----------------------------------------------------------------------------
// CORS HEADERS (REQUIRED)
// -----------------------------------------------------------------------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

// -----------------------------------------------------------------------------
// ENVIRONMENT
// -----------------------------------------------------------------------------
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

// Provider keys (must exist even if not all are active yet)
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY")
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

// -----------------------------------------------------------------------------
// MAIN HANDLER
// -----------------------------------------------------------------------------
serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { voice_note_id } = await req.json()

    if (!voice_note_id) {
      return jsonResponse(
        { error: "voice_note_id required" },
        400
      )
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
      .single()

    if (vnErr || !voiceNote) throw vnErr

    const provider: string =
      voiceNote.accounts?.transcription_provider ?? "groq"

    /* --------------------------------------------------
       2. FETCH PROMPT (VERSIONED)
    -------------------------------------------------- */
    const { data: promptRow, error: promptErr } = await supabase
      .from("ai_prompts")
      .select("*")
      .eq("provider", provider)
      .eq("purpose", "voice_note_analysis")
      .eq("is_active", true)
      .order("version", { ascending: false })
      .limit(1)
      .single()

    if (promptErr || !promptRow) throw promptErr

    /* --------------------------------------------------
       3. TRANSCRIPTION (IDEMPOTENT)
    -------------------------------------------------- */
    let transcript = voiceNote.transcript_raw

    if (!transcript) {
      const result = await transcribeAudio(
        provider,
        voiceNote.audio_url
      )

      transcript = result.raw_text

      await supabase
        .from("voice_notes")
        .update({
          transcript_raw: result.raw_text,
          detected_language: result.language,
          detected_language_code: result.language_code,
        })
        .eq("id", voice_note_id)
    }

    /* --------------------------------------------------
       4. AI INTERPRETATION (STRICT JSON)
    -------------------------------------------------- */
    const aiResponse = await runLLM(provider, {
      system_prompt: promptRow.system_prompt,
      user_prompt: promptRow.user_prompt_template
        .replace("{{TRANSCRIPT}}", transcript)
        .replace("{{LANGUAGE}}", voiceNote.detected_language ?? "unknown"),
      output_schema: promptRow.output_schema,
    })

    /* --------------------------------------------------
       5. STORE AI OUTPUT (IMMUTABLE)
    -------------------------------------------------- */
    await supabase.from("voice_note_ai_outputs").insert({
      voice_note_id,
      provider,
      prompt_version: promptRow.version,
      ai_output: aiResponse,
      confidence_score: aiResponse.confidence_score,
      explanation: aiResponse.reasoning,
    })

    /* --------------------------------------------------
       6. PROCUREMENT INTENT
    -------------------------------------------------- */
    if (aiResponse.procurement_intent?.detected) {
      await supabase.from("material_requests").insert({
        voice_note_id,
        project_id: voiceNote.project_id,
        account_id: voiceNote.account_id,
        items: aiResponse.procurement_intent.items,
        urgency: aiResponse.procurement_intent.urgency,
        confidence: aiResponse.procurement_intent.confidence,
      })
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
        ai_analysis: aiResponse.reasoning,
      })
    }

    return jsonResponse({ success: true })

  } catch (err) {
    console.error("Edge Function Error:", err)

    return jsonResponse(
      { error: err?.message ?? "Internal server error" },
      500
    )
  }
})

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------
function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  })
}

/* ======================================================
   PROVIDER ABSTRACTIONS (COMPATIBLE WITH index_0.ts)
====================================================== */

async function transcribeAudio(
  provider: string,
  audioUrl: string
): Promise<{
  raw_text: string
  language: string
  language_code: string
}> {
  switch (provider) {
    case "groq":
      if (!GROQ_API_KEY) throw new Error("GROQ_API_KEY missing")
      // TODO: plug in GroqProvider from index_0.ts
      return {
        raw_text: "...transcribed text...",
        language: "English",
        language_code: "en",
      }

    default:
      throw new Error(`Unsupported transcription provider: ${provider}`)
  }
}

async function runLLM(
  provider: string,
  payload: {
    system_prompt: string
    user_prompt: string
    output_schema: any
  }
): Promise<any> {
  switch (provider) {
    case "groq":
      if (!GROQ_API_KEY) throw new Error("GROQ_API_KEY missing")
      // TODO: plug Groq chat completion logic
      return JSON.parse("{}") // MUST match output_schema

    default:
      throw new Error(`Unsupported LLM provider: ${provider}`)
  }
}
