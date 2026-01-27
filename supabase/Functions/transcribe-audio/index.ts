import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const LANGUAGE_NAMES: { [key: string]: string } = { 
  'en': 'English', 'hi': 'Hindi', 'te': 'Telugu', 'ta': 'Tamil', 'kn': 'Kannada', 'mr': 'Marathi' 
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
function getActionCategory(intent: string): 'update' | 'approval' | 'action_required' | null {
  const normalized = intent.toLowerCase().trim();
  
  // Information category does not create action items
  if (normalized === 'information') {
    return null;
  }
  
  if (['update', 'approval', 'action_required'].includes(normalized)) {
    return normalized as 'update' | 'approval' | 'action_required';
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

    if (!transcriptRaw) {
      console.log("[2] Running ASR (Whisper)...");
      const asr = await performASR(providerName, apiKey, voiceNote.audio_url);
      transcriptRaw = asr.text;
      detectedLangCode = asr.language;

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
        // Fetch active translation prompt
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
          
          transcriptEn = translationResponse.translated_text || transcriptRaw;
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
    const finalIntent = mapAiIntent(ai.intent);
    const finalPriority = mapAiPriority(ai.priority);
    const finalShortSummary = ai.short_summary || "Voice note recorded";
    const finalDetailedSummary = ai.detailed_summary || ai.short_summary || "No details available";
    const actionCategory = getActionCategory(finalIntent);

    console.log(`✓ AI Analysis Complete: intent=${finalIntent}, priority=${finalPriority}, confidence=${ai.confidence_score || 0.5}`);

    /* --------------------------------------------------
       PHASE 5: WRITE AI INTELLIGENCE TO NORMALIZED TABLES
    -------------------------------------------------- */
    console.log("[5] Writing AI outputs...");
    
    const dbOperations: Promise<any>[] = [];

    // 5.1: Write AI Analysis Summary
    dbOperations.push(
      supabase.from("voice_note_ai_analysis").insert({
        voice_note_id: voiceNoteId,
        source_transcript: 'original',
        intent: finalIntent,
        priority: finalPriority,
        short_summary: finalShortSummary,
        detailed_summary: finalDetailedSummary,
        confidence_score: ai.confidence_score || 0.5,
        ai_model: providerName === 'groq' ? 'llama-3.3-70b' : 'gpt-4o-mini',
        prompt_version: `${analysisPrompt.version}`
      })
    );

    // 5.2: Write Transactional Intelligence
    if (ai.materials?.length > 0) {
      dbOperations.push(
        supabase.from("voice_note_material_requests").insert(
          ai.materials.map((m: any) => ({
            voice_note_id: voiceNoteId,
            material_category: m.material_category || m.category,
            material_name: m.material_name || m.name,
            quantity: m.quantity,
            unit: m.unit,
            brand_preference: m.brand_preference,
            delivery_date: m.delivery_date,
            urgency: m.urgency || 'normal',
            extracted_from: m.extracted_from || 'explicit',
            confidence_score: m.confidence_score || ai.confidence_score || 0.5
          }))
        )
      );
    }

    if (ai.labor?.length > 0) {
      dbOperations.push(
        supabase.from("voice_note_labor_requests").insert(
          ai.labor.map((l: any) => ({
            voice_note_id: voiceNoteId,
            labor_type: l.labor_type,
            headcount: l.headcount,
            duration_days: l.duration_days,
            start_date: l.start_date,
            urgency: l.urgency || 'normal',
            confidence_score: l.confidence_score || ai.confidence_score || 0.5
          }))
        )
      );
    }

    if (ai.approvals?.length > 0) {
      dbOperations.push(
        supabase.from("voice_note_approvals").insert(
          ai.approvals.map((a: any) => ({
            voice_note_id: voiceNoteId,
            approval_type: a.approval_type,
            amount: a.amount,
            currency: a.currency || 'INR',
            due_date: a.due_date,
            requires_manager: a.requires_manager !== false, // Default true
            confidence_score: a.confidence_score || ai.confidence_score || 0.5
          }))
        )
      );
    }

    if (ai.project_events?.length > 0) {
      dbOperations.push(
        supabase.from("voice_note_project_events").insert(
          ai.project_events.map((e: any) => ({
            voice_note_id: voiceNoteId,
            event_type: e.event_type,
            title: e.title,
            description: e.description,
            requires_followup: e.requires_followup || false,
            suggested_due_date: e.suggested_due_date,
            confidence_score: e.confidence_score || ai.confidence_score || 0.5
          }))
        )
      );
    }

    /* --------------------------------------------------
       PHASE 6: CREATE ACTION ITEM (IF ACTIONABLE)
    -------------------------------------------------- */
    if (actionCategory) {
      console.log(`[6] Creating action item (category: ${actionCategory})...`);

      const managerId = voiceNote.users?.reports_to || null;

      const initialInteraction = {
        timestamp: new Date().toISOString(),
        action: 'created',
        actor_id: voiceNote.user_id,
        actor_role: voiceNote.users?.role || 'unknown',
        details: {
          source: 'voice_note',
          voice_note_id: voiceNoteId,
          ai_intent: finalIntent,
          ai_priority: finalPriority,
          ai_confidence: ai.confidence_score || 0.5
        }
      };

      dbOperations.push(
        supabase.from("action_items").insert({
          voice_note_id: voiceNoteId,
          category: actionCategory,
          summary: finalShortSummary,
          details: finalDetailedSummary,
          priority: finalPriority,
          status: 'pending',
          project_id: voiceNote.project_id,
          account_id: voiceNote.account_id,
          user_id: voiceNote.user_id,
          assigned_to: managerId,
          ai_analysis: JSON.stringify({
            intent: finalIntent,
            confidence_score: ai.confidence_score,
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

      console.log("✓ Action item created");
    } else {
      console.log("[6] No action item needed (information category)");
    }

    // CRITICAL FIX: Update voice note with ALL transcript fields for compatibility
    const legacyTranscription = detectedLangCode === 'en' 
      ? transcriptEn 
      : `[${LANGUAGE_NAMES[detectedLangCode] || detectedLangCode}] ${transcriptRaw}\n\n[English] ${transcriptEn}`;

    dbOperations.push(
      supabase.from("voice_notes").update({
        status: 'completed',
        category: finalIntent,
        
        // NEW ARCHITECTURE (canonical fields)
        transcript_raw_current: transcriptRaw,
        transcript_en_current: transcriptEn,
        transcript_final: transcriptEn,
        
        // LEGACY COMPATIBILITY (for existing cards)
        transcription: legacyTranscription,
        
        // Language metadata
        detected_language: LANGUAGE_NAMES[detectedLangCode] || detectedLangCode,
        detected_language_code: detectedLangCode,
        
      }).eq("id", voiceNoteId)
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
    console.log("=== Processing Complete ===");

    return new Response(
      JSON.stringify({ 
        success: true,
        voice_note_id: voiceNoteId,
        intent: finalIntent,
        priority: finalPriority,
        action_created: !!actionCategory
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

  return { 
    text: data.text, 
    language: data.language 
  };
}

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