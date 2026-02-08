import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Expanded language names covering all 22 scheduled Indian languages + common ones
const LANGUAGE_NAMES: { [key: string]: string } = {
  'en': 'English', 'hi': 'Hindi', 'te': 'Telugu', 'ta': 'Tamil', 'kn': 'Kannada',
  'mr': 'Marathi', 'gu': 'Gujarati', 'pa': 'Punjabi', 'ml': 'Malayalam',
  'bn': 'Bengali', 'ur': 'Urdu', 'as': 'Assamese', 'or': 'Odia',
  'kok': 'Konkani', 'mai': 'Maithili', 'sd': 'Sindhi', 'ne': 'Nepali',
  'sa': 'Sanskrit', 'doi': 'Dogri', 'mni': 'Manipuri', 'sat': 'Santali',
  'ks': 'Kashmiri', 'bo': 'Bodo'
}

// Construction domain context prompt for Whisper ASR
const CONSTRUCTION_CONTEXT_PROMPT =
  'Construction site voice note. Common terms: concrete, scaffolding, rebar, foundation, ' +
  'excavation, slab, formwork, shuttering, plaster, aggregate, cement, TMT bar, centering, ' +
  'curing, waterproofing, RCC, PCC, lintel, beam, column, footing, pile, grout, mortar, ' +
  'brick, block, tile, paint, primer, putty, sand, gravel, crusher, mixer, vibrator, ' +
  'labour, supervisor, contractor, architect, engineer, foreman, mason, carpenter, plumber, ' +
  'electrician, welder, fitter, helper, daily wages, piecework, overtime.'

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
  if (normalized === 'information' || normalized === 'update') {
    return null;
  }

  if (['approval', 'action_required'].includes(normalized)) {
    return normalized as 'approval' | 'action_required';
  }

  return null;
}

/**
 * Fallback keyword-based classifier when AI classification fails.
 * Returns a classification with low confidence (0.3).
 */
function fallbackClassify(transcript: string): any {
  const lowerText = transcript.toLowerCase();

  const approvalKeywords = [
    'please approve', 'approve', 'shall we', 'can we', 'should we',
    'may we', 'permission', 'authorize', 'thinking of', 'planning to',
    'want to', 'would like to', 'requesting', 'need approval'
  ];

  const problemKeywords = [
    'problem', 'issue', 'urgent', 'danger', 'weak', 'broken',
    'collapsed', 'unsafe', 'fix', 'help', 'emergency', 'leak',
    'crack', 'damage', 'delayed', 'shortage', 'missing'
  ];

  const hasApprovalRequest = approvalKeywords.some(kw => lowerText.includes(kw));
  const hasProblem = problemKeywords.some(kw => lowerText.includes(kw));

  if (hasApprovalRequest) {
    return {
      intent: 'approval',
      priority: 'Med',
      short_summary: transcript.substring(0, 100),
      detailed_summary: transcript,
      confidence_score: 0.3,
      materials: [],
      labor: [],
      approvals: [],
      project_events: []
    };
  } else if (hasProblem) {
    return {
      intent: 'action_required',
      priority: 'High',
      short_summary: transcript.substring(0, 100),
      detailed_summary: transcript,
      confidence_score: 0.3,
      materials: [],
      labor: [],
      approvals: [],
      project_events: []
    };
  } else {
    return {
      intent: 'update',
      priority: 'Low',
      short_summary: transcript.substring(0, 100),
      detailed_summary: transcript,
      confidence_score: 0.3,
      materials: [],
      labor: [],
      approvals: [],
      project_events: []
    };
  }
}

/* ============================================================
   RETRY UTILITY
============================================================ */

/**
 * Fetch with exponential backoff retry for transient failures.
 * Retries on 429 (rate limit), 5xx (server errors), and network timeouts.
 */
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  maxRetries = 3
): Promise<Response> {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const timeoutMs = attempt === 1 ? 30000 : 45000;
      const res = await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(timeoutMs),
      });

      if (res.ok) return res;

      // Retry on rate limit or server errors
      if ((res.status === 429 || res.status >= 500) && attempt < maxRetries) {
        const backoffMs = 1000 * attempt;
        console.warn(`  ⚠ Attempt ${attempt} got ${res.status}, retrying in ${backoffMs}ms...`);
        await new Promise(r => setTimeout(r, backoffMs));
        continue;
      }

      return res; // Non-retryable error, let caller handle
    } catch (e: any) {
      if (attempt < maxRetries && (e.name === 'AbortError' || e.name === 'TypeError' || e.name === 'TimeoutError')) {
        const backoffMs = 1000 * attempt;
        console.warn(`  ⚠ Attempt ${attempt} failed (${e.name}), retrying in ${backoffMs}ms...`);
        await new Promise(r => setTimeout(r, backoffMs));
        continue;
      }
      throw e;
    }
  }
  // Should never reach here, but TypeScript needs it
  throw new Error('fetchWithRetry exhausted all retries');
}

/* ============================================================
   AUDIO DATA INTERFACE — Download Once, Pass Everywhere
============================================================ */

/**
 * Holds downloaded audio data so we never re-download.
 */
interface AudioData {
  blob: Blob;
  base64: string | null;    // Lazily computed for Gemini
  fileName: string;
  mimeType: string;
}

/**
 * Downloads audio from storage URL exactly ONCE and returns AudioData.
 */
async function downloadAudioOnce(audioUrl: string): Promise<AudioData> {
  console.log('  → Downloading audio (single download)...');
  const t0 = performance.now();

  const audioRes = await fetchWithRetry(audioUrl, {});
  if (!audioRes.ok) {
    throw new Error(`Failed to fetch audio: ${audioRes.statusText}`);
  }

  const blob = await audioRes.blob();
  const fileName = audioUrl.split('/').pop() || 'audio.webm';
  const mimeType = fileName.endsWith('.webm') ? 'audio/webm'
    : fileName.endsWith('.m4a') ? 'audio/mp4'
    : 'audio/mpeg';

  console.log(`  ✓ Audio downloaded in ${(performance.now() - t0).toFixed(0)}ms (${(blob.size / 1024).toFixed(1)} KB)`);

  return { blob, base64: null, fileName, mimeType };
}

/**
 * Gets base64 encoding of audio data (lazy — only computed when needed for Gemini).
 */
async function getAudioBase64(audioData: AudioData): Promise<string> {
  if (audioData.base64) return audioData.base64;

  const arrayBuffer = await audioData.blob.arrayBuffer();
  audioData.base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
  return audioData.base64;
}

/* ============================================================
   GEMINI PROVIDER FUNCTIONS (uses AudioData, same pipeline)
============================================================ */

/**
 * Performs ASR using Gemini 1.5 Flash (multimodal audio-to-text).
 */
async function performGeminiASR(key: string, audioData: AudioData, contextPrompt: string) {
  const base64Audio = await getAudioBase64(audioData);

  console.log('  → Calling Gemini 1.5 Flash for transcription...');
  const res = await fetchWithRetry(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${key}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            {
              text: `Transcribe this audio accurately. Context: ${contextPrompt}. ` +
                `The audio may be in English or any Indian language (Hindi, Telugu, Tamil, Kannada, etc.). ` +
                `Return ONLY valid JSON (no markdown): {"text": "transcribed text here", "language": "ISO 639-1 code"}`
            },
            {
              inline_data: {
                mime_type: audioData.mimeType,
                data: base64Audio
              }
            }
          ]
        }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 2000
        }
      })
    }
  );

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Gemini ASR failed: ${data.error?.message || res.status}`);
  }

  const textResponse = data.candidates?.[0]?.content?.parts?.[0]?.text || '{}';

  try {
    // Strip markdown code blocks if present
    const cleaned = textResponse.replace(/```json\n?/g, '').replace(/```/g, '').trim();
    const parsed = JSON.parse(cleaned);
    return {
      text: parsed.text || textResponse,
      language: parsed.language || 'unknown',
      confidence: null // Gemini doesn't provide confidence scores
    };
  } catch {
    return {
      text: textResponse.trim(),
      language: 'unknown',
      confidence: null
    };
  }
}

/**
 * Calls Gemini 1.5 Flash for LLM tasks (translation, classification).
 */
async function callGeminiLLM(key: string, options: { prompt: string, isJson: boolean }) {
  const res = await fetchWithRetry(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${key}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: options.prompt }] }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 2000,
          ...(options.isJson ? { responseMimeType: "application/json" } : {})
        }
      })
    }
  );

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Gemini LLM failed: ${data.error?.message || res.status}`);
  }

  const textResponse = data.candidates?.[0]?.content?.parts?.[0]?.text || '';

  if (options.isJson) {
    try {
      const cleaned = textResponse.replace(/```json\n?/g, '').replace(/```/g, '').trim();
      return JSON.parse(cleaned);
    } catch (e) {
      console.error('Invalid JSON from Gemini:', textResponse);
      throw new Error('Gemini returned invalid JSON');
    }
  }

  return textResponse;
}

/* ============================================================
   WHISPER ASR (Groq / OpenAI — uses AudioData, no re-download)
============================================================ */

/**
 * Performs ASR using Groq or OpenAI Whisper.
 * Accepts pre-downloaded AudioData — no network fetch needed.
 */
async function performASR(
  provider: string,
  key: string,
  audioData: AudioData,
  preferredLanguage?: string
) {
  const formData = new FormData();
  formData.append('file', new File([audioData.blob], audioData.fileName));
  formData.append(
    'model',
    provider === 'groq' ? 'whisper-large-v3' : 'whisper-1'
  );
  formData.append('response_format', 'verbose_json');

  // Construction domain context prompt for better accuracy
  formData.append('prompt', CONSTRUCTION_CONTEXT_PROMPT);

  // Language hint from user's preferred language
  if (preferredLanguage && preferredLanguage !== 'en') {
    formData.append('language', preferredLanguage);
  }

  // Deterministic output with temperature=0
  formData.append('temperature', '0');

  const endpoint = provider === 'groq'
    ? 'https://api.groq.com/openai/v1/audio/transcriptions'
    : 'https://api.openai.com/v1/audio/transcriptions';

  console.log(`  → Calling ${provider} Whisper ASR...`);
  const t0 = performance.now();

  const res = await fetchWithRetry(endpoint, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${key}` },
    body: formData
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`ASR failed: ${data.error?.message}`);
  }

  console.log(`  ✓ ASR completed in ${(performance.now() - t0).toFixed(0)}ms`);

  // Extract confidence score from segments
  let confidence = null;
  if (data.segments && data.segments.length > 0) {
    const avgConfidence = data.segments.reduce((sum: number, seg: any) => {
      return sum + (seg.avg_logprob || seg.confidence || 0);
    }, 0) / data.segments.length;

    // Convert log probability to 0-1 confidence if needed
    confidence = avgConfidence < 0 ? Math.exp(avgConfidence) : avgConfidence;
  }

  return {
    text: data.text,
    language: data.language,
    confidence: confidence
  };
}

/* ============================================================
   LLM — Translation & Classification (Groq / OpenAI / Gemini)
============================================================ */

/**
 * Calls LLM for translation and classification.
 * Routes to Groq (Llama 3.3), OpenAI (GPT-4o-mini), or Gemini (1.5 Flash)
 * based on account's transcription_provider setting.
 * Uses fetchWithRetry for resilience.
 */
async function callRegistryLLM(
  provider: string,
  key: string,
  options: {
    prompt: string,
    context?: string | null,
    isJson: boolean
  }
) {
  // Route to Gemini if needed
  if (provider === 'gemini') {
    return callGeminiLLM(key, { prompt: options.prompt, isJson: options.isJson });
  }

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

  const messages: any[] = [{ role: 'system', content: systemPrompt }];
  if (options.context) {
    messages.push({ role: 'user', content: options.context });
  }

  console.log(`  → Calling ${provider} LLM (${model})...`);
  const t0 = performance.now();

  const res = await fetchWithRetry(`${baseUrl}/chat/completions`, {
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

  console.log(`  ✓ LLM completed in ${(performance.now() - t0).toFixed(0)}ms`);

  const content = data.choices[0].message.content;

  try {
    return options.isJson ? JSON.parse(content) : content;
  } catch (e) {
    console.error("Invalid JSON from AI:", content);
    throw new Error("AI returned invalid JSON");
  }
}

/* ============================================================
   MAIN HANDLER — Streamlined Pipeline (All Providers)

   Same optimized process for Groq, OpenAI, and Gemini:
   Download audio ONCE → ASR (original lang) →
   LLM text translate → LLM classify → Parallel DB writes

   Provider is selected per-account by super admin via
   accounts.transcription_provider ('groq' | 'openai' | 'gemini')
============================================================ */

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const pipelineStart = performance.now();
  console.log("=== Voice Note Processing Started ===");

  // Track voice note ID for error status updates
  let voiceNoteId: string | null = null;
  let supabase: any = null;

  try {
    const payload = await req.json()
    voiceNoteId = payload.voice_note_id || payload.record?.id
    if (!voiceNoteId) throw new Error("voice_note_id required")

    supabase = createClient(
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
        users!voice_notes_user_id_fkey(id, role, account_id, reports_to, preferred_language, preferred_languages),
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

    // Get user's preferred language for ASR hint
    const userLang = voiceNote.users?.preferred_language || 'en';

    // Capture original field values from Phase 1 fetch (eliminates redundant DB reads)
    const hasOriginalRaw = !!voiceNote.transcript_raw_original;
    const hasOriginalEn = !!voiceNote.transcript_en_original;

    /* --------------------------------------------------
       PHASE 1.5: PARALLEL PREFETCH — Audio + AI Prompts
       Downloads audio ONCE and fetches both AI prompts
       in parallel to minimize wait time.
    -------------------------------------------------- */
    console.log(`[1.5] Prefetching audio + AI prompts in parallel (provider: ${providerName})...`);
    const prefetchStart = performance.now();

    // Only download audio if we need ASR (transcript not already available)
    const needsASR = !voiceNote.transcript_raw_original;
    const needsTranslation = !voiceNote.transcript_en_original;

    const [audioData, translationPromptResult, analysisPromptResult] = await Promise.all([
      // 1. Download audio once (only if needed for ASR)
      needsASR
        ? downloadAudioOnce(voiceNote.audio_url)
        : Promise.resolve(null),

      // 2. Fetch translation prompt (only if translation needed)
      needsTranslation
        ? supabase
            .from("ai_prompts")
            .select("*")
            .eq("provider", providerName)
            .eq("purpose", "translation_normalization")
            .eq("is_active", true)
            .limit(1)
            .maybeSingle()
        : Promise.resolve({ data: null }),

      // 3. Fetch analysis prompt
      supabase
        .from("ai_prompts")
        .select("*")
        .eq("provider", providerName)
        .eq("purpose", "voice_note_analysis")
        .eq("is_active", true)
        .order("version", { ascending: false })
        .limit(1)
        .maybeSingle()
    ]);

    const translationPrompt = translationPromptResult?.data;
    const analysisPrompt = analysisPromptResult?.data;

    console.log(`  ✓ Prefetch completed in ${(performance.now() - prefetchStart).toFixed(0)}ms`);

    /* --------------------------------------------------
       PHASE 2: AUTOMATIC SPEECH RECOGNITION (ASR)
       Transcribes in the ORIGINAL spoken language.
       Audio blob is passed directly — no re-download.
    -------------------------------------------------- */
    let transcriptRaw = voiceNote.transcript_raw_original;
    let detectedLangCode = voiceNote.detected_language_code;
    let asrConfidence: number | undefined;

    if (!transcriptRaw && audioData) {
      console.log("[2] Running ASR (original language)...");

      if (providerName === 'gemini') {
        // Gemini uses multimodal audio transcription
        const asr = await performGeminiASR(apiKey, audioData, CONSTRUCTION_CONTEXT_PROMPT);
        transcriptRaw = asr.text;
        detectedLangCode = asr.language;
        asrConfidence = asr.confidence ?? undefined;
      } else {
        // Groq/OpenAI Whisper — uses pre-downloaded audio blob
        const asr = await performASR(providerName, apiKey, audioData, userLang);
        transcriptRaw = asr.text;
        detectedLangCode = asr.language;
        asrConfidence = asr.confidence ?? undefined;
      }

      // PROGRESSIVE WRITE: ASR result available immediately.
      // Status → 'transcribed' so the client can show the transcript right away.
      // Also write legacy 'transcription' field so cards display text immediately.
      const asrLanguageName = LANGUAGE_NAMES[detectedLangCode] || detectedLangCode;
      const asrUpdatePayload: any = {
        transcript_raw_current: transcriptRaw,
        transcript_raw: transcriptRaw,
        detected_language_code: detectedLangCode,
        detected_language: asrLanguageName,
        asr_confidence: asrConfidence,
        status: 'transcribed',
        // Write to legacy/display fields so card shows text NOW
        transcription: transcriptRaw,
      };

      // For English audio, also populate English fields immediately
      if (detectedLangCode === 'en') {
        asrUpdatePayload.transcript_en_current = transcriptRaw;
        asrUpdatePayload.transcript_final = transcriptRaw;
      }

      // Only set original if not already present (idempotency — checked from Phase 1 data)
      if (!hasOriginalRaw) {
        asrUpdatePayload.transcript_raw_original = transcriptRaw;
      }

      await supabase.from("voice_notes").update(asrUpdatePayload).eq("id", voiceNoteId);
      console.log("✓ ASR completed → status='transcribed' — card shows transcript now");
    } else {
      console.log("[2] ASR already completed, skipping...");
      asrConfidence = voiceNote.asr_confidence;
    }

    /* --------------------------------------------------
       PHASE 3: TRANSLATION TO ENGLISH (Text-based only)
       Uses the original-language transcript from Phase 2.
       Calls the account's LLM to translate TEXT → English.
       NO audio re-download. NO Whisper /translations.
    -------------------------------------------------- */
    let transcriptEn = voiceNote.transcript_en_original;

    if (!transcriptEn) {
      console.log("[3] Running text translation...");

      if (detectedLangCode === 'en') {
        transcriptEn = transcriptRaw;
        console.log("✓ Transcript already in English");
      } else {
        // LLM text translation — translate the original-language transcript to English
        if (translationPrompt) {
          const finalPrompt = translationPrompt.prompt
            .replace('{{LANGUAGE}}', LANGUAGE_NAMES[detectedLangCode] || detectedLangCode)
            .replace('{{TRANSCRIPT}}', transcriptRaw);

          const translationResponse = await callRegistryLLM(providerName, apiKey, {
            prompt: finalPrompt,
            isJson: true
          });

          transcriptEn = translationResponse.translated_text
            || translationResponse.english_translation
            || translationResponse.translation
            || transcriptRaw;

          console.log("✓ LLM text translation completed");
        } else {
          console.warn("No translation prompt found, using raw transcript");
          transcriptEn = transcriptRaw;
        }
      }

      // PROGRESSIVE WRITE: Translation available immediately.
      // Status → 'translated' so the client can show the English translation.
      const transLanguageName = LANGUAGE_NAMES[detectedLangCode] || detectedLangCode;
      const updateEnPayload: any = {
        transcript_en_current: transcriptEn,
        transcript_final: transcriptEn,
        status: 'translated',
        // Update legacy transcription to include both languages
        transcription: detectedLangCode === 'en'
          ? transcriptEn
          : `[${transLanguageName}] ${transcriptRaw}\n\n[English] ${transcriptEn}`,
      };

      if (!hasOriginalEn) {
        updateEnPayload.transcript_en_original = transcriptEn;
      }

      await supabase.from("voice_notes").update(updateEnPayload).eq("id", voiceNoteId);
      console.log("✓ Translation completed → status='translated' — card shows English now");
    } else {
      console.log("[3] Translation already completed, skipping...");
    }

    /* --------------------------------------------------
       PHASE 4: AI INTELLIGENCE & CLASSIFICATION
       Uses the English translation from Phase 3.
       Prompt was pre-fetched in Phase 1.5.
    -------------------------------------------------- */
    console.log("[4] Running AI analysis...");

    let ai: any;
    const aiModelName = providerName === 'groq' ? 'llama-3.3-70b'
      : providerName === 'gemini' ? 'gemini-1.5-flash'
      : 'gpt-4o-mini';

    if (!analysisPrompt) {
      console.warn("No active analysis prompt found, using fallback classifier");
      ai = fallbackClassify(transcriptEn);
    } else {
      // Build contextual prompt with few-shot examples injected
      const contextualPrompt = `${analysisPrompt.prompt}

PROJECT CONTEXT:
- Project Name: ${voiceNote.projects?.name || 'Unknown Project'}
- Speaker Role: ${voiceNote.users?.role || 'Unknown Role'}

CLASSIFICATION EXAMPLES:
- "We need 50 bags of cement and 20 TMT bars delivered by tomorrow" -> intent: action_required, priority: High
- "Can we start the second floor slab work?" -> intent: approval, priority: Med
- "First floor plastering is 80% complete" -> intent: update, priority: Low
- "The scaffolding on the east side is shaking, looks unsafe" -> intent: action_required, priority: Critical
- "Received the steel delivery, all counts verified" -> intent: update, priority: Low
- "Need approval for additional 10 workers for next week" -> intent: approval, priority: Med

TRANSCRIPT TO ANALYZE:
"${transcriptEn}"

Analyze the above transcript and return ONLY valid JSON matching the required schema.`;

      try {
        ai = await callRegistryLLM(providerName, apiKey, {
          prompt: contextualPrompt,
          context: null,
          isJson: true
        });
      } catch (e: any) {
        console.warn(`AI classification failed (${e.message}), using fallback classifier`);
        ai = fallbackClassify(transcriptEn);
      }
    }

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
       Build all DB operations for parallel execution.
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
        ai_model: aiModelName,
        prompt_version: analysisPrompt?.version?.toString() || '0'
      })
    );

    // 5.2: Extract structured entities — batch insert per table
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
      // Single batch insert for all materials
      dbOperations.push(
        supabase.from("voice_note_material_requests").insert(materialInserts)
      );
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
      // Single batch insert for all labor
      dbOperations.push(
        supabase.from("voice_note_labor_requests").insert(laborInserts)
      );
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
      // Single batch insert for all approvals
      dbOperations.push(
        supabase.from("voice_note_approvals").insert(approvalInserts)
      );
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
      // Single batch insert for all events
      dbOperations.push(
        supabase.from("voice_note_project_events").insert(eventInserts)
      );
    }

    /* --------------------------------------------------
       PHASE 6: CREATE ACTION ITEM (IF ACTIONABLE)
       Implements confidence routing + critical keyword
       detection per DECISIONS_AND_REQUIREMENTS.md
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
          category: actionCategory || 'action_required',
          summary: finalShortSummary,
          details: finalDetailedSummary,
          priority: isCritical ? 'High' : finalPriority,
          status: 'pending',
          project_id: voiceNote.project_id,
          account_id: voiceNote.account_id,
          user_id: voiceNote.user_id,
          assigned_to: managerId,
          confidence_score: confidenceScore,
          needs_review: needsReview,
          review_status: reviewStatus,
          is_critical_flag: isCritical,
          ai_analysis: JSON.stringify({
            intent: finalIntent,
            confidence_score: confidenceScore,
            prompt_version: analysisPrompt?.version || 0,
            model: aiModelName,
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
        console.log("✓ Critical notification queued for manager");
      }

      console.log(`✓ Action item queued (critical=${isCritical}, confidence=${confidenceScore}, needs_review=${needsReview})`);
    } else {
      console.log(`[6] No action item needed (intent=${finalIntent}, ambient update or information)`);
    }

    // 5.3: Update voice note to completed status
    const languageName = LANGUAGE_NAMES[detectedLangCode] || detectedLangCode.toUpperCase();

    // Build legacy 'transcription' field for compatibility
    let legacyTranscription = '';
    if (detectedLangCode === 'en') {
      legacyTranscription = transcriptEn;
    } else {
      legacyTranscription = `[${languageName}] ${transcriptRaw}\n\n[English] ${transcriptEn}`;
    }

    // Build translated_transcription JSONB correctly
    const translatedTranscriptions: { [key: string]: string } = {
      'en': transcriptEn
    };

    // Build final update payload — uses in-memory flags from Phase 1 (no extra DB read)
    const finalUpdatePayload: any = {
      status: 'completed',
      category: finalIntent,

      // Always update current and final fields
      transcript_raw_current: transcriptRaw,
      transcript_en_current: transcriptEn,
      transcript_final: transcriptEn,

      // Legacy fields for backward compatibility
      transcription: legacyTranscription,
      transcript_raw: transcriptRaw,

      // Translated transcription
      translated_transcription: translatedTranscriptions,

      // Language detection fields
      detected_language: languageName,
      detected_language_code: detectedLangCode,

      // ASR confidence
      asr_confidence: asrConfidence || null
    };

    // CRITICAL: Only set original fields if they don't exist (immutable — from Phase 1 data)
    if (!hasOriginalRaw) {
      finalUpdatePayload.transcript_raw_original = transcriptRaw;
    }
    if (!hasOriginalEn) {
      finalUpdatePayload.transcript_en_original = transcriptEn;
    }

    dbOperations.push(
      supabase.from("voice_notes").update(finalUpdatePayload).eq("id", voiceNoteId)
    );

    /* --------------------------------------------------
       PHASE 7: EXECUTE ALL DB WRITES IN PARALLEL
       Promise.all for maximum throughput.
       Entity inserts are batched per table (single insert per type).
    -------------------------------------------------- */
    console.log(`[7] Executing ${dbOperations.length} DB writes in parallel...`);
    const writeStart = performance.now();

    const results = await Promise.all(dbOperations);

    // Check for errors in any operation
    for (let i = 0; i < results.length; i++) {
      if (results[i]?.error) {
        console.error(`Database operation ${i + 1} failed: ${results[i].error.message}`);
        throw new Error(`Database operation ${i + 1} failed: ${results[i].error.message}`);
      }
    }

    console.log(`  ✓ All ${dbOperations.length} writes completed in ${(performance.now() - writeStart).toFixed(0)}ms`);

    const totalTime = performance.now() - pipelineStart;
    console.log(`✓ Fields populated: transcript_raw_original=${!!transcriptRaw}, transcript_en_original=${!!transcriptEn}, asr_confidence=${asrConfidence}`);
    console.log(`=== Processing Complete in ${(totalTime / 1000).toFixed(2)}s ===`);

    return new Response(
      JSON.stringify({
        success: true,
        voice_note_id: voiceNoteId,
        provider: providerName,
        intent: finalIntent,
        priority: finalPriority,
        action_created: !!shouldCreateAction,
        asr_confidence: asrConfidence,
        processing_time_ms: Math.round(totalTime)
      }),
      { status: 200, headers: corsHeaders }
    );

  } catch (err: any) {
    const totalTime = performance.now() - pipelineStart;
    console.error(`FATAL ERROR after ${(totalTime / 1000).toFixed(2)}s:`, err.message);
    console.error(err.stack);

    // Try to update voice note status to 'error' so it can be retried
    if (voiceNoteId && supabase) {
      try {
        await supabase.from("voice_notes").update({
          status: 'error',
        }).eq("id", voiceNoteId);
        console.log("Voice note marked as 'error' for retry");
      } catch (_) {
        // Best effort - don't let this secondary failure mask the original
      }
    }

    return new Response(
      JSON.stringify({
        error: err.message
        // Security: No stack trace in response
      }),
      { status: 500, headers: corsHeaders }
    );
  }
});
