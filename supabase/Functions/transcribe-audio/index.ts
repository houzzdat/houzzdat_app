import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const LANGUAGE_NAMES: { [key: string]: string } = {
  'en': 'English', 'hi': 'Hindi', 'te': 'Telugu', 'ta': 'Tamil', 'kn': 'Kannada',
  'mr': 'Marathi', 'gu': 'Gujarati', 'pa': 'Punjabi', 'ml': 'Malayalam',
  'bn': 'Bengali', 'ur': 'Urdu'
}

/**
 * Critical/safety keywords that trigger Red Alert Banner on manager dashboard.
 * If any keyword is detected in the transcript (at ANY confidence level),
 * an action_item is force-created with is_critical_flag = true.
 */
const CRITICAL_KEYWORDS = [
  'injury', 'injured', 'hurt', 'accident', 'collapse', 'collapsed',
  'falling', 'fell', 'fire', 'smoke', 'gas', 'leak', 'leaking',
  'flood', 'flooding', 'electrocution', 'emergency', 'unsafe',
  'danger', 'dangerous', 'hazard', 'crack', 'structural'
];

function detectCriticalKeywords(transcript: string): boolean {
  const lower = transcript.toLowerCase();
  return CRITICAL_KEYWORDS.some(kw => lower.includes(kw));
}

/**
 * Maps AI-generated intents to DB CHECK constraint values
 */
function mapAiIntent(intent: string): string {
  const normalized = (intent || '').toLowerCase().trim();
  
  if (['update', 'approval', 'action_required', 'information'].includes(normalized)) {
    return normalized;
  }

  const mapping: Record<string, string> = {
    'material_request': 'action_required',
    'labour_request': 'action_required',
    'approval_request': 'approval',
    'project_update': 'update',
    'general_communication': 'information',
    'instruction': 'action_required',
    'issue_reported': 'action_required'
  };

  return mapping[normalized] || 'information';
}

/**
 * Maps priority to DB CHECK constraint values
 */
function mapAiPriority(priority: string): string {
  const normalized = (priority || 'Med').trim();
  const allowed = ['Low', 'Med', 'High', 'Critical'];
  return allowed.includes(normalized) ? normalized : 'Med';
}

/**
 * Maps intent to action item category (only actionable intents)
 */
function getActionCategory(intent: string): 'approval' | 'action_required' | null {
  const normalized = intent.toLowerCase().trim();

  // Updates and information do NOT create action items (Ambient Updates).
  // Updates appear only in the Feed tab; information is purely FYI.
  if (normalized === 'information' || normalized === 'update') {
    return null;
  }

  if (['approval', 'action_required'].includes(normalized)) {
    return normalized as 'approval' | 'action_required';
  }

  return null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  console.log("=== Voice Note Processing Started ===");

  try {
    const payload = await req.json()
    const voiceNoteId = payload.voice_note_id || payload.record?.id
    if (!voiceNoteId) throw new Error("voice_note_id required")

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    /* --------------------------------------------------
       PHASE 1: FETCH VOICE NOTE & VALIDATE STATE
    -------------------------------------------------- */
    console.log(`[1] Fetching voice note ${voiceNoteId}...`);
    
    const { data: voiceNote, error: vnErr } = await supabase
      .from("voice_notes")
      .select(`
        *,
        accounts(transcription_provider),
        users!voice_notes_user_id_fkey(id, role, account_id, reports_to),
        projects(id, name, account_id)
      `)
      .eq("id", voiceNoteId)
      .single();

    if (vnErr || !voiceNote) {
      throw new Error(`Voice note not found: ${vnErr?.message}`);
    }

    if (voiceNote.status === 'completed') {
      console.log("Already completed. Early exit.");
      return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
    }

    const providerName = voiceNote.accounts?.transcription_provider || 'groq';
    const apiKey = Deno.env.get(`${providerName.toUpperCase()}_API_KEY`);
    if (!apiKey) throw new Error(`API Key for ${providerName} not found`);

    /* --------------------------------------------------
       PHASE 2: AUTOMATIC SPEECH RECOGNITION (ASR)
    -------------------------------------------------- */
    let transcriptRaw = voiceNote.transcript_raw_original;
    let detectedLangCode = voiceNote.detected_language_code;
    let asrConfidence: number | undefined; // FIXED: Capture ASR confidence

    if (!transcriptRaw) {
      console.log("[2] Running ASR (Whisper)...");
      const asr = await performASR(providerName, apiKey, voiceNote.audio_url);
      transcriptRaw = asr.text;
      detectedLangCode = asr.language;
      asrConfidence = asr.confidence; // FIXED: Store confidence score

      // Check if original is already set (race condition safety)
      const { data: currentVN } = await supabase
        .from("voice_notes")
        .select("transcript_raw_original")
        .eq("id", voiceNoteId)
        .single();
      
      const updatePayload: any = {
        transcript_raw_current: transcriptRaw,
        detected_language_code: detectedLangCode,
        detected_language: LANGUAGE_NAMES[detectedLangCode] || detectedLangCode,
        asr_confidence: asrConfidence, // FIXED: Save ASR confidence
        status: 'processing'
      };

      // Only set original if not already present (idempotency)
      if (!currentVN?.transcript_raw_original) {
        updatePayload.transcript_raw_original = transcriptRaw;
      }

      await supabase.from("voice_notes").update(updatePayload).eq("id", voiceNoteId);
      console.log("✓ ASR completed and synced");
    } else {
      console.log("[2] ASR already completed, skipping...");
      asrConfidence = voiceNote.asr_confidence; // Use existing confidence
    }

    /* --------------------------------------------------
       PHASE 3: TRANSLATION TO ENGLISH
    -------------------------------------------------- */
    let transcriptEn = voiceNote.transcript_en_original;
    
    if (!transcriptEn) {
      console.log("[3] Running translation...");
      
      if (detectedLangCode === 'en') {
        transcriptEn = transcriptRaw;
        console.log("✓ Transcript already in English");
      } else {
        // Fetch active translation prompt from ai_prompts table
        const { data: transPrompt } = await supabase
          .from("ai_prompts")
          .select("*")
          .eq("provider", providerName)
          .eq("purpose", "translation_normalization")
          .eq("is_active", true)
          .limit(1)
          .maybeSingle();

        if (transPrompt) {
          const finalPrompt = transPrompt.prompt
            .replace('{{LANGUAGE}}', LANGUAGE_NAMES[detectedLangCode] || detectedLangCode)
            .replace('{{TRANSCRIPT}}', transcriptRaw);

          const translationResponse = await callRegistryLLM(providerName, apiKey, {
            prompt: finalPrompt,
            isJson: true 
          });
          
          // FIXED: Extract English translation correctly
          transcriptEn = translationResponse.translated_text 
            || translationResponse.english_translation 
            || translationResponse.translation
            || transcriptRaw;
          
          console.log("✓ Translation completed");
        } else {
          console.warn("No translation prompt found, using raw transcript");
          transcriptEn = transcriptRaw;
        }
      }

      // Atomic update with race condition check
      const { data: currentVNEn } = await supabase
        .from("voice_notes")
        .select("transcript_en_original")
        .eq("id", voiceNoteId)
        .single();
      
      const updateEnPayload: any = { transcript_en_current: transcriptEn };
      
      if (!currentVNEn?.transcript_en_original) {
        updateEnPayload.transcript_en_original = transcriptEn;
      }

      await supabase.from("voice_notes").update(updateEnPayload).eq("id", voiceNoteId);
      console.log("✓ Translation synced");
    } else {
      console.log("[3] Translation already completed, skipping...");
    }

    /* --------------------------------------------------
       PHASE 4: AI INTELLIGENCE & CLASSIFICATION
    -------------------------------------------------- */
    console.log("[4] Running AI analysis...");
    
    const { data: analysisPrompt } = await supabase
      .from("ai_prompts")
      .select("*")
      .eq("provider", providerName)
      .eq("purpose", "voice_note_analysis")
      .eq("is_active", true)
      .order("version", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!analysisPrompt) {
      throw new Error("No active analysis prompt found");
    }

    // Build contextual prompt by injecting transcript directly
    const contextualPrompt = `${analysisPrompt.prompt}

PROJECT CONTEXT:
- Project Name: ${voiceNote.projects?.name || 'Unknown Project'}
- Speaker Role: ${voiceNote.users?.role || 'Unknown Role'}

TRANSCRIPT TO ANALYZE:
"${transcriptEn}"

Analyze the above transcript and return ONLY valid JSON matching the required schema.`;

    const ai = await callRegistryLLM(providerName, apiKey, {
      prompt: contextualPrompt,
      context: null, // Context already injected above
      isJson: true
    });

    // CRITICAL VALIDATION: Ensure AI provided required fields
    if (!ai.short_summary || ai.short_summary.trim() === '') {
      console.warn("AI did not provide short_summary, generating from transcript");
      ai.short_summary = transcriptEn.length > 100 
        ? transcriptEn.substring(0, 97) + '...'
        : transcriptEn;
    }

    if (!ai.detailed_summary || ai.detailed_summary.trim() === '') {
      console.warn("AI did not provide detailed_summary, using short_summary");
      ai.detailed_summary = ai.short_summary;
    }

    // Validate and map intent
    const rawIntent = ai.intent || 'information';
    const finalIntent = mapAiIntent(rawIntent);
    
    // Validate and map priority
    const rawPriority = ai.priority || 'Med';
    const finalPriority = mapAiPriority(rawPriority);
    
    // Determine action category
    const actionCategory = getActionCategory(finalIntent);

    console.log(`✓ AI Analysis: Intent=${finalIntent}, Priority=${finalPriority}, Category=${actionCategory || 'none'}`);

    /* --------------------------------------------------
       PHASE 5: STRUCTURED DATA EXTRACTION
    -------------------------------------------------- */
    const dbOperations: Promise<any>[] = [];

    // 5.1: Store comprehensive AI analysis
    dbOperations.push(
      supabase.from("voice_note_ai_analysis").insert({
        voice_note_id: voiceNoteId,
        source_transcript: 'original',
        edit_version: 0,
        intent: finalIntent,
        priority: finalPriority,
        short_summary: ai.short_summary,
        detailed_summary: ai.detailed_summary,
        confidence_score: ai.confidence_score || 0.5,
        ai_model: providerName === 'groq' ? 'llama-3.3-70b' : 'gpt-4o-mini',
        prompt_version: analysisPrompt.version.toString()
      })
    );

    // 5.2: Extract structured entities
    if (ai.materials && ai.materials.length > 0) {
      const materialInserts = ai.materials.map((m: any) => ({
        voice_note_id: voiceNoteId,
        material_category: m.category || 'General',
        material_name: m.name,
        quantity: m.quantity || null,
        unit: m.unit || null,
        brand_preference: m.brand_preference || null,
        delivery_date: m.delivery_date || null,
        urgency: m.urgency || 'normal',
        extracted_from: m.explicit ? 'explicit' : 'implicit',
        confidence_score: m.confidence || 0.7
      }));
      dbOperations.push(...materialInserts.map(m => 
        supabase.from("voice_note_material_requests").insert(m)
      ));
    }

    if (ai.labor && ai.labor.length > 0) {
      const laborInserts = ai.labor.map((l: any) => ({
        voice_note_id: voiceNoteId,
        labor_type: l.type || 'General Labor',
        headcount: l.headcount || 1,
        duration_days: l.duration_days || null,
        start_date: l.start_date || null,
        urgency: l.urgency || 'normal',
        confidence_score: l.confidence || 0.7
      }));
      dbOperations.push(...laborInserts.map(l => 
        supabase.from("voice_note_labor_requests").insert(l)
      ));
    }

    if (ai.approvals && ai.approvals.length > 0) {
      const approvalInserts = ai.approvals.map((a: any) => ({
        voice_note_id: voiceNoteId,
        approval_type: a.type || 'General Approval',
        amount: a.amount || null,
        currency: a.currency || 'INR',
        due_date: a.due_date || null,
        requires_manager: a.requires_manager !== false,
        confidence_score: a.confidence || 0.7
      }));
      dbOperations.push(...approvalInserts.map(a => 
        supabase.from("voice_note_approvals").insert(a)
      ));
    }

    if (ai.project_events && ai.project_events.length > 0) {
      const eventInserts = ai.project_events.map((e: any) => ({
        voice_note_id: voiceNoteId,
        event_type: e.type || 'information',
        title: e.title || ai.short_summary,
        description: e.description || ai.detailed_summary,
        requires_followup: e.requires_followup || false,
        suggested_due_date: e.suggested_due_date || null,
        suggested_assignee: e.suggested_assignee || null,
        confidence_score: e.confidence || 0.7
      }));
      dbOperations.push(...eventInserts.map(e => 
        supabase.from("voice_note_project_events").insert(e)
      ));
    }

    /* --------------------------------------------------
       PHASE 6: CREATE ACTION ITEM (IF ACTIONABLE)
       Implements confidence routing + critical keyword
       detection per DECISIONS_AND_REQUIREMENTS.md §7.2
    -------------------------------------------------- */
    console.log("[6] Evaluating action item creation...");

    const isCritical = detectCriticalKeywords(transcriptEn);
    const confidenceScore: number = ai.confidence_score ?? 0.5;
    const shouldCreateAction = actionCategory || isCritical;

    if (shouldCreateAction) {
      const finalShortSummary = ai.short_summary || transcriptEn.substring(0, 100);
      const finalDetailedSummary = ai.detailed_summary || transcriptEn;

      // Find manager for auto-assignment
      let managerId = null;
      if (voiceNote.users?.reports_to) {
        managerId = voiceNote.users.reports_to;
      } else {
        const { data: managers } = await supabase
          .from("users")
          .select("id")
          .eq("account_id", voiceNote.account_id)
          .in("role", ['manager', 'admin'])
          .limit(1);

        if (managers && managers.length > 0) {
          managerId = managers[0].id;
        }
      }

      const initialInteraction = {
        timestamp: new Date().toISOString(),
        action: 'created',
        actor_id: voiceNote.user_id,
        actor_role: voiceNote.users?.role || 'worker',
        details: isCritical
          ? 'Action item auto-created from voice note (CRITICAL — safety keyword detected)'
          : 'Action item auto-created from voice note'
      };

      // Determine confidence tier and review flags
      let needsReview = false;
      let reviewStatus: string | null = null;

      if (isCritical) {
        // Critical override: always needs review, force high priority
        needsReview = true;
        reviewStatus = 'pending_review';
        console.log("[6] CRITICAL keywords detected — forcing action item creation");
      } else if (confidenceScore >= 0.85) {
        needsReview = false;
        reviewStatus = null;
      } else if (confidenceScore >= 0.70) {
        needsReview = true;
        reviewStatus = 'pending_review';
      } else {
        needsReview = true;
        reviewStatus = 'flagged';
      }

      dbOperations.push(
        supabase.from("action_items").insert({
          voice_note_id: voiceNoteId,
          // Critical override: force 'action_required' if original intent was update/information
          category: actionCategory || 'action_required',
          summary: finalShortSummary,
          details: finalDetailedSummary,
          priority: isCritical ? 'High' : finalPriority,
          status: 'pending',
          project_id: voiceNote.project_id,
          account_id: voiceNote.account_id,
          user_id: voiceNote.user_id,
          assigned_to: managerId,
          // New confidence/review columns
          confidence_score: confidenceScore,
          needs_review: needsReview,
          review_status: reviewStatus,
          is_critical_flag: isCritical,
          ai_analysis: JSON.stringify({
            intent: finalIntent,
            confidence_score: confidenceScore,
            prompt_version: analysisPrompt.version,
            model: providerName === 'groq' ? 'llama-3.3-70b' : 'gpt-4o-mini',
            extracted_items: {
              materials: ai.materials?.length || 0,
              labor: ai.labor?.length || 0,
              approvals: ai.approvals?.length || 0,
              events: ai.project_events?.length || 0
            }
          }),
          interaction_history: [initialInteraction],
          manager_approval: false,
          is_dependency_locked: false
        })
      );

      // Create urgent notification for critical items
      if (isCritical && managerId) {
        dbOperations.push(
          supabase.from("notifications").insert({
            user_id: managerId,
            account_id: voiceNote.account_id,
            project_id: voiceNote.project_id,
            type: 'critical_detected',
            title: 'CRITICAL: Safety issue reported',
            body: finalShortSummary,
            reference_id: voiceNoteId,
            reference_type: 'voice_note',
          })
        );
        console.log("✓ Critical notification created for manager");
      }

      console.log(`✓ Action item created (critical=${isCritical}, confidence=${confidenceScore}, needs_review=${needsReview})`);
    } else {
      console.log(`[6] No action item needed (intent=${finalIntent}, ambient update or information)`);
    }

    // 5.3: Update voice note to completed status
    // FIXED: Build proper format for all transcript fields
    const languageName = LANGUAGE_NAMES[detectedLangCode] || detectedLangCode.toUpperCase();
    
    // Build legacy 'transcription' field for compatibility
    let legacyTranscription = '';
    if (detectedLangCode === 'en') {
      legacyTranscription = transcriptEn;
    } else {
      legacyTranscription = `[${languageName}] ${transcriptRaw}\n\n[English] ${transcriptEn}`;
    }

    // FIXED: Build translated_transcription JSONB correctly
    // This should store English translation, not all languages
    const translatedTranscriptions: { [key: string]: string } = {
      'en': transcriptEn  // FIXED: English translation is stored here
    };

    // CRITICAL FIX: Check if original fields are already set to avoid modification error
    const { data: currentVoiceNote } = await supabase
      .from("voice_notes")
      .select("transcript_raw_original, transcript_en_original")
      .eq("id", voiceNoteId)
      .single();

    // Build update payload - only include original fields if they're not set
    const finalUpdatePayload: any = {
      status: 'completed',
      category: finalIntent,
      
      // Always update current and final fields
      transcript_raw_current: transcriptRaw,   // Current native (no edits yet)
      transcript_en_current: transcriptEn,     // Current English (no edits yet)
      transcript_final: transcriptEn,          // Final approved text (English)
      
      // Legacy fields for backward compatibility
      transcription: legacyTranscription,      // Formatted for UI display
      transcript_raw: transcriptRaw,           // Legacy raw field
      
      // FIXED: translated_transcription should be English only
      translated_transcription: translatedTranscriptions,
      
      // Language detection fields
      detected_language: languageName,         // Human-readable
      detected_language_code: detectedLangCode, // ISO code
      
      // FIXED: ASR confidence now populated
      asr_confidence: asrConfidence || null
    };

    // CRITICAL: Only set original fields if they don't exist (immutable)
    if (!currentVoiceNote?.transcript_raw_original) {
      finalUpdatePayload.transcript_raw_original = transcriptRaw;
    }
    if (!currentVoiceNote?.transcript_en_original) {
      finalUpdatePayload.transcript_en_original = transcriptEn;
    }

    dbOperations.push(
      supabase.from("voice_notes").update(finalUpdatePayload).eq("id", voiceNoteId)
    );

    /* --------------------------------------------------
       PHASE 7: EXECUTE ALL WRITES ATOMICALLY
    -------------------------------------------------- */
    console.log("[7] Executing batch write...");
    
    const results = await Promise.all(dbOperations);
    const firstError = results.find(r => r.error);
    
    if (firstError) {
      throw new Error(`Database operation failed: ${firstError.error.message}`);
    }

    console.log("✓ All data written successfully");
    console.log(`✓ Fields populated: transcript_raw_original=${!!transcriptRaw}, transcript_en_original=${!!transcriptEn}, asr_confidence=${asrConfidence}`);
    console.log("=== Processing Complete ===");

    return new Response(
      JSON.stringify({ 
        success: true,
        voice_note_id: voiceNoteId,
        intent: finalIntent,
        priority: finalPriority,
        action_created: !!actionCategory,
        asr_confidence: asrConfidence
      }), 
      { status: 200, headers: corsHeaders }
    );

  } catch (err: any) {
    console.error("❌ FATAL ERROR:", err.message);
    console.error(err.stack);
    
    return new Response(
      JSON.stringify({ 
        error: err.message,
        stack: err.stack 
      }), 
      { status: 500, headers: corsHeaders }
    );
  }
});

/* ============================================================
   HELPER FUNCTIONS
============================================================ */

/**
 * Performs ASR using Groq or OpenAI Whisper
 * FIXED: Now returns confidence score
 */
async function performASR(provider: string, key: string, audioUrl: string) {
  console.log(`  → Fetching audio from storage...`);
  const audioRes = await fetch(audioUrl);
  if (!audioRes.ok) {
    throw new Error(`Failed to fetch audio: ${audioRes.statusText}`);
  }

  const audioBlob = await audioRes.blob();
  const formData = new FormData();
  formData.append('file', new File([audioBlob], 'audio.webm'));
  formData.append(
    'model', 
    provider === 'groq' ? 'whisper-large-v3' : 'whisper-1'
  );
  formData.append('response_format', 'verbose_json');

  const endpoint = provider === 'groq' 
    ? 'https://api.groq.com/openai/v1/audio/transcriptions'
    : 'https://api.openai.com/v1/audio/transcriptions';

  console.log(`  → Calling ${provider} Whisper API...`);
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${key}` },
    body: formData
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`ASR failed: ${data.error?.message}`);
  }

  // FIXED: Extract confidence score from segments
  let confidence = null;
  if (data.segments && data.segments.length > 0) {
    // Calculate average confidence across all segments
    const avgConfidence = data.segments.reduce((sum: number, seg: any) => {
      return sum + (seg.avg_logprob || seg.confidence || 0);
    }, 0) / data.segments.length;
    
    // Convert log probability to 0-1 confidence if needed
    confidence = avgConfidence < 0 ? Math.exp(avgConfidence) : avgConfidence;
  }

  return { 
    text: data.text, 
    language: data.language,
    confidence: confidence  // FIXED: Return confidence score
  };
}

/**
 * Calls LLM with registry-based prompts
 */
async function callRegistryLLM(
  provider: string, 
  key: string, 
  options: { 
    prompt: string, 
    context?: string, 
    isJson: boolean 
  }
) {
  const baseUrl = provider === 'groq' 
    ? 'https://api.groq.com/openai/v1'
    : 'https://api.openai.com/v1';
  
  const model = provider === 'groq' 
    ? 'llama-3.3-70b-versatile'
    : 'gpt-4o-mini';

  let systemPrompt = options.prompt;
  
  // Ensure JSON mode is explicit
  if (options.isJson && !systemPrompt.toLowerCase().includes('json')) {
    systemPrompt += "\n\nReturn the output in valid JSON format.";
  }

  const messages = [{ role: 'system', content: systemPrompt }];
  if (options.context) {
    messages.push({ role: 'user', content: options.context });
  }

  console.log(`  → Calling ${provider} LLM (${model})...`);
  const res = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: { 
      'Authorization': `Bearer ${key}`, 
      'Content-Type': 'application/json' 
    },
    body: JSON.stringify({ 
      model, 
      messages, 
      response_format: options.isJson ? { type: "json_object" } : undefined,
      temperature: 0.1 
    })
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`LLM call failed: ${data.error?.message}`);
  }

  const content = data.choices[0].message.content;
  
  try {
    return options.isJson ? JSON.parse(content) : content;
  } catch (e) {
    console.error("Invalid JSON from AI:", content);
    throw new Error("AI returned invalid JSON");
  }
}