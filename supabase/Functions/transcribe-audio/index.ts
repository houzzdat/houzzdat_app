// Enhanced transcription with CORS support and multiple provider options
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const serve = (handler: (req: Request) => Promise<Response>) => {
  Deno.serve(handler)
}

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ============================================================================
// CORS HEADERS - CRITICAL FOR WEB CLIENT
// ============================================================================
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ============================================================================
// PROVIDER INTERFACES
// ============================================================================

interface TranscriptionResult {
  text: string
  language: string
}

interface TranslationResult {
  text: string
}

interface ClassificationResult {
  category: 'update' | 'approval' | 'action_required'
  priority: 'Low' | 'Med' | 'High'
  analysis: string
  summary: string
}

// ============================================================================
// GROQ PROVIDER
// ============================================================================

class GroqProvider {
  private apiKey: string

  constructor(apiKey: string) {
    this.apiKey = apiKey
  }

  async transcribe(audioBlob: Blob, fileName: string, contextPrompt: string): Promise<TranscriptionResult> {
    const formData = new FormData()
    formData.append('file', new File([audioBlob], fileName))
    formData.append('model', 'whisper-large-v3')
    formData.append('prompt', contextPrompt)
    formData.append('response_format', 'verbose_json')
    formData.append('temperature', '0')

    const response = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${this.apiKey}` },
      body: formData,
    })

    if (!response.ok) {
      throw new Error(`Groq transcription failed: ${response.status}`)
    }

    const result = await response.json()
    return {
      text: result.text || "No transcription",
      language: result.language || "unknown"
    }
  }

  async translateToEnglish(audioBlob: Blob, fileName: string, contextPrompt: string): Promise<TranslationResult> {
    const formData = new FormData()
    formData.append('file', new File([audioBlob], fileName))
    formData.append('model', 'whisper-large-v3')
    formData.append('prompt', contextPrompt)
    formData.append('response_format', 'json')

    const response = await fetch('https://api.groq.com/openai/v1/audio/translations', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${this.apiKey}` },
      body: formData,
    })

    if (!response.ok) {
      throw new Error(`Groq translation failed: ${response.status}`)
    }

    const result = await response.json()
    return { text: result.text || "" }
  }

  async translateText(text: string, targetLanguage: string): Promise<string> {
    const languageNames: { [key: string]: string } = {
      'es': 'Spanish', 'fr': 'French', 'de': 'German', 'hi': 'Hindi',
      'te': 'Telugu', 'ta': 'Tamil', 'mr': 'Marathi', 'bn': 'Bengali',
      'kn': 'Kannada', 'ml': 'Malayalam',
      'pt': 'Portuguese', 'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean',
      'ar': 'Arabic', 'ru': 'Russian', 'it': 'Italian'
    }
    
    const targetLanguageName = languageNames[targetLanguage] || targetLanguage.toUpperCase()
    
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [{
          role: 'system',
          content: 'You are a professional translator specializing in construction industry terminology. Translate accurately while keeping technical terms clear.'
        }, {
          role: 'user',
          content: `Translate this construction site message to ${targetLanguageName}. Keep technical construction terms in English if they don't have direct translations. Return ONLY the translation, no explanations:\n\n"${text}"`
        }],
        temperature: 0.3,
        max_tokens: 500
      })
    })

    if (!response.ok) {
      throw new Error(`Groq text translation failed: ${response.status}`)
    }

    const result = await response.json()
    return result.choices[0]?.message?.content?.trim() || text
  }

  async classify(text: string): Promise<ClassificationResult> {
    const classificationPrompt = `You are analyzing a voice note from a construction site.

VOICE NOTE TEXT: "${text}"

Your task: Classify this into EXACTLY ONE category and create a CRISP, DIRECT summary.

CATEGORY DEFINITIONS:

1. "approval" - Requesting permission, approval, or authorization to proceed
2. "action_required" - Problem, concern, or urgent issue needing attention  
3. "update" - Informational update about progress or status

SUMMARY RULES:
- Write in ACTIVE VOICE, starting with a VERB
- Be DIRECT and CONCISE (max 15 words)
- NO phrases like "The speaker", "Someone is", "There is"
- Examples:
  ✓ "Need approval to start foundation work tomorrow"
  ✓ "Railing is weak and requires immediate fixing"
  ✓ "Concrete pouring completed on the north side"
  ✗ "The speaker is requesting approval to start foundation work"
  ✗ "Someone mentioned that the railing is weak"

Respond in EXACT JSON format (no markdown):
{
  "category": "update" OR "approval" OR "action_required",
  "priority": "Low" OR "Med" OR "High",
  "analysis": "Brief 1-sentence analysis",
  "summary": "Direct, crisp summary starting with a verb (max 15 words)"
}`

    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [{
          role: 'system',
          content: 'You are a construction project assistant that classifies voice notes. Always respond with valid JSON only.'
        }, {
          role: 'user',
          content: classificationPrompt
        }],
        temperature: 0.1,
        max_tokens: 300
      })
    })

    if (!response.ok) {
      throw new Error(`Groq classification failed: ${response.status}`)
    }

    const result = await response.json()
    const responseText = result.choices[0]?.message?.content || '{}'
    
    return this.parseClassification(responseText)
  }

  private parseClassification(responseText: string): ClassificationResult {
    let jsonText = responseText.trim()
    
    // Remove markdown code blocks if present
    if (jsonText.startsWith('```json')) {
      jsonText = jsonText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
    } else if (jsonText.startsWith('```')) {
      jsonText = jsonText.replace(/```\n?/g, '').trim()
    }
    
    const jsonMatch = jsonText.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      throw new Error('Could not parse JSON from response')
    }
    
    const classification = JSON.parse(jsonMatch[0])
    return {
      category: classification.category || 'update',
      priority: classification.priority || 'Med',
      analysis: classification.analysis || '',
      summary: classification.summary || ''
    }
  }
}

// ============================================================================
// GEMINI PROVIDER
// ============================================================================

class GeminiProvider {
  private apiKey: string

  constructor(apiKey: string) {
    this.apiKey = apiKey
  }

  async transcribe(audioBlob: Blob, fileName: string, contextPrompt: string): Promise<TranscriptionResult> {
    const arrayBuffer = await audioBlob.arrayBuffer()
    const base64Audio = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)))
    
    const mimeType = fileName.endsWith('.webm') ? 'audio/webm' : 'audio/mpeg'

    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${this.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: `Transcribe this audio. Context: ${contextPrompt}. Return ONLY the transcription text and detected language code (e.g., en, es, hi) in JSON format: {"text": "...", "language": "..."}` },
            {
              inline_data: {
                mime_type: mimeType,
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
    })

    if (!response.ok) {
      throw new Error(`Gemini transcription failed: ${response.status}`)
    }

    const result = await response.json()
    const textResponse = result.candidates?.[0]?.content?.parts?.[0]?.text || '{}'
    
    try {
      const parsed = JSON.parse(textResponse.replace(/```json\n?/g, '').replace(/```/g, '').trim())
      return {
        text: parsed.text || "No transcription",
        language: parsed.language || "unknown"
      }
    } catch {
      return {
        text: textResponse,
        language: "unknown"
      }
    }
  }

  async translateToEnglish(audioBlob: Blob, fileName: string, contextPrompt: string): Promise<TranslationResult> {
    const arrayBuffer = await audioBlob.arrayBuffer()
    const base64Audio = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)))
    
    const mimeType = fileName.endsWith('.webm') ? 'audio/webm' : 'audio/mpeg'

    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${this.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: `Transcribe and translate this audio to English. Context: ${contextPrompt}. Return ONLY the English translation.` },
            {
              inline_data: {
                mime_type: mimeType,
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
    })

    if (!response.ok) {
      throw new Error(`Gemini translation failed: ${response.status}`)
    }

    const result = await response.json()
    const text = result.candidates?.[0]?.content?.parts?.[0]?.text || ""
    
    return { text }
  }

  async translateText(text: string, targetLanguage: string): Promise<string> {
    const languageNames: { [key: string]: string } = {
      'es': 'Spanish', 'fr': 'French', 'de': 'German', 'hi': 'Hindi',
      'te': 'Telugu', 'ta': 'Tamil', 'mr': 'Marathi', 'bn': 'Bengali',
      'kn': 'Kannada', 'ml': 'Malayalam',
      'pt': 'Portuguese', 'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean',
      'ar': 'Arabic', 'ru': 'Russian', 'it': 'Italian'
    }
    
    const targetLanguageName = languageNames[targetLanguage] || targetLanguage.toUpperCase()

    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${this.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [{
            text: `Translate this construction site message to ${targetLanguageName}. Keep technical construction terms in English if they don't have direct translations. Return ONLY the translation:\n\n"${text}"`
          }]
        }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 500
        }
      })
    })

    if (!response.ok) {
      throw new Error(`Gemini text translation failed: ${response.status}`)
    }

    const result = await response.json()
    return result.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || text
  }

  async classify(text: string): Promise<ClassificationResult> {
    const classificationPrompt = `You are analyzing a voice note from a construction site.

VOICE NOTE TEXT: "${text}"

Your task: Classify this into EXACTLY ONE category based on the PRIMARY intent.

CATEGORY DEFINITIONS:

1. "approval" - The speaker is REQUESTING permission, approval, or authorization to proceed
2. "action_required" - There is a PROBLEM, CONCERN, or URGENT issue that needs attention
3. "update" - Simple INFORMATIONAL update about progress or status (no action needed)

Respond in EXACT JSON format:
{
  "category": "update" OR "approval" OR "action_required",
  "priority": "Low" OR "Med" OR "High",
  "analysis": "Brief explanation",
  "summary": "One sentence summary"
}`

    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${this.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [{ text: classificationPrompt }]
        }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 300,
          responseMimeType: "application/json"
        }
      })
    })

    if (!response.ok) {
      throw new Error(`Gemini classification failed: ${response.status}`)
    }

    const result = await response.json()
    const responseText = result.candidates?.[0]?.content?.parts?.[0]?.text || '{}'
    
    const classification = JSON.parse(responseText)
    return {
      category: classification.category || 'update',
      priority: classification.priority || 'Med',
      analysis: classification.analysis || '',
      summary: classification.summary || ''
    }
  }
}

// ============================================================================
// OPENAI PROVIDER
// ============================================================================

class OpenAIProvider {
  private apiKey: string

  constructor(apiKey: string) {
    this.apiKey = apiKey
  }

  async transcribe(audioBlob: Blob, fileName: string, contextPrompt: string): Promise<TranscriptionResult> {
    const formData = new FormData()
    formData.append('file', new File([audioBlob], fileName))
    formData.append('model', 'whisper-1')
    formData.append('prompt', contextPrompt)
    formData.append('response_format', 'verbose_json')
    formData.append('temperature', '0')

    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${this.apiKey}` },
      body: formData,
    })

    if (!response.ok) {
      throw new Error(`OpenAI transcription failed: ${response.status}`)
    }

    const result = await response.json()
    return {
      text: result.text || "No transcription",
      language: result.language || "unknown"
    }
  }

  async translateToEnglish(audioBlob: Blob, fileName: string, contextPrompt: string): Promise<TranslationResult> {
    const formData = new FormData()
    formData.append('file', new File([audioBlob], fileName))
    formData.append('model', 'whisper-1')
    formData.append('prompt', contextPrompt)
    formData.append('response_format', 'json')

    const response = await fetch('https://api.openai.com/v1/audio/translations', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${this.apiKey}` },
      body: formData,
    })

    if (!response.ok) {
      throw new Error(`OpenAI translation failed: ${response.status}`)
    }

    const result = await response.json()
    return { text: result.text || "" }
  }

  async translateText(text: string, targetLanguage: string): Promise<string> {
    const languageNames: { [key: string]: string } = {
      'es': 'Spanish', 'fr': 'French', 'de': 'German', 'hi': 'Hindi',
      'te': 'Telugu', 'ta': 'Tamil', 'mr': 'Marathi', 'bn': 'Bengali',
      'kn': 'Kannada', 'ml': 'Malayalam',
      'pt': 'Portuguese', 'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean',
      'ar': 'Arabic', 'ru': 'Russian', 'it': 'Italian'
    }
    
    const targetLanguageName = languageNames[targetLanguage] || targetLanguage.toUpperCase()

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [{
          role: 'system',
          content: 'You are a professional translator specializing in construction industry terminology.'
        }, {
          role: 'user',
          content: `Translate this construction site message to ${targetLanguageName}. Keep technical construction terms in English if they don't have direct translations. Return ONLY the translation:\n\n"${text}"`
        }],
        temperature: 0.3,
        max_tokens: 500
      })
    })

    if (!response.ok) {
      throw new Error(`OpenAI text translation failed: ${response.status}`)
    }

    const result = await response.json()
    return result.choices[0]?.message?.content?.trim() || text
  }

  async classify(text: string): Promise<ClassificationResult> {
    const classificationPrompt = `You are analyzing a voice note from a construction site.

VOICE NOTE TEXT: "${text}"

Your task: Classify this into EXACTLY ONE category based on the PRIMARY intent.

CATEGORY DEFINITIONS:

1. "approval" - The speaker is REQUESTING permission, approval, or authorization to proceed
2. "action_required" - There is a PROBLEM, CONCERN, or URGENT issue that needs attention
3. "update" - Simple INFORMATIONAL update about progress or status (no action needed)

Respond in EXACT JSON format:
{
  "category": "update" OR "approval" OR "action_required",
  "priority": "Low" OR "Med" OR "High",
  "analysis": "Brief explanation",
  "summary": "One sentence summary"
}`

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [{
          role: 'system',
          content: 'You are a construction project assistant that classifies voice notes. Always respond with valid JSON only.'
        }, {
          role: 'user',
          content: classificationPrompt
        }],
        temperature: 0.1,
        max_tokens: 300,
        response_format: { type: "json_object" }
      })
    })

    if (!response.ok) {
      throw new Error(`OpenAI classification failed: ${response.status}`)
    }

    const result = await response.json()
    const classification = JSON.parse(result.choices[0]?.message?.content || '{}')
    
    return {
      category: classification.category || 'update',
      priority: classification.priority || 'Med',
      analysis: classification.analysis || '',
      summary: classification.summary || ''
    }
  }
}

// ============================================================================
// PROVIDER FACTORY
// ============================================================================

function getProvider(providerName: string): GroqProvider | GeminiProvider | OpenAIProvider {
  switch (providerName.toLowerCase()) {
    case 'groq':
      const groqKey = Deno.env.get('GROQ_API_KEY')
      if (!groqKey) throw new Error("GROQ_API_KEY not set")
      return new GroqProvider(groqKey)
    
    case 'gemini':
      const geminiKey = Deno.env.get('GEMINI_API_KEY')
      if (!geminiKey) throw new Error("GEMINI_API_KEY not set")
      return new GeminiProvider(geminiKey)
    
    case 'openai':
      const openaiKey = Deno.env.get('OPENAI_API_KEY')
      if (!openaiKey) throw new Error("OPENAI_API_KEY not set")
      return new OpenAIProvider(openaiKey)
    
    default:
      throw new Error(`Unknown provider: ${providerName}`)
  }
}

// ============================================================================
// FALLBACK CLASSIFICATION
// ============================================================================

function fallbackClassify(text: string): ClassificationResult {
  const lowerText = text.toLowerCase()
  
  const approvalKeywords = [
    'please approve', 'approve', 'shall we', 'can we', 'should we',
    'may we', 'permission', 'authorize', 'thinking of', 'planning to',
    'want to', 'would like to', 'requesting', 'need approval'
  ]
  
  const problemKeywords = [
    'problem', 'issue', 'urgent', 'danger', 'weak', 'broken',
    'collapsed', 'unsafe', 'fix', 'help', 'emergency'
  ]
  
  const hasApprovalRequest = approvalKeywords.some(kw => lowerText.includes(kw))
  const hasProblem = problemKeywords.some(kw => lowerText.includes(kw))
  
  if (hasApprovalRequest) {
    return {
      category: 'approval',
      priority: 'Med',
      analysis: 'Detected approval request (fallback classification)',
      summary: text.substring(0, 200)
    }
  } else if (hasProblem) {
    return {
      category: 'action_required',
      priority: 'High',
      analysis: 'Detected problem or concern (fallback classification)',
      summary: text.substring(0, 200)
    }
  } else {
    return {
      category: 'update',
      priority: 'Low',
      analysis: 'General update (fallback classification)',
      summary: text.substring(0, 200)
    }
  }
}

// ============================================================================
// MAIN HANDLER WITH CORS SUPPORT
// ============================================================================

serve(async (req) => {
  // ✅ CRITICAL: Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload = await req.json()
    console.log("Received payload:", JSON.stringify(payload, null, 2))
    
    const record = payload.record
    if (!record) {
      throw new Error("No record in payload")
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // 1. Fetch account provider and user preferences
    const { data: account } = await supabase
      .from('accounts')
      .select('transcription_provider')
      .eq('id', record.account_id)
      .single()

    const { data: recordingUser } = await supabase
      .from('users')
      .select('preferred_language')
      .eq('id', record.user_id)
      .single()

    const providerName = account?.transcription_provider || 'groq'
    const userPreferredLang = recordingUser?.preferred_language || 'en'
    console.log(`Using provider: ${providerName}, User prefers: ${userPreferredLang}`)

    // Get provider instance
    const provider = getProvider(providerName)

    // 2. Get all stakeholders and their languages
    const { data: projectUsers } = await supabase
      .from('users')
      .select('id, preferred_language, email')
      .eq('account_id', record.account_id)

    const recipientLanguages = new Set(projectUsers?.map(u => u.preferred_language) || ['en'])
    console.log(`Recipient languages:`, Array.from(recipientLanguages))

    // 3. Download audio file
    const urlParts = record.audio_url.split('/voice-notes/')
    if (urlParts.length < 2) {
      throw new Error(`Invalid audio URL format: ${record.audio_url}`)
    }
    const storagePath = urlParts[1]

    const { data: audioBlob, error: downloadError } = await supabase
      .storage
      .from('voice-notes')
      .download(storagePath)

    if (downloadError || !audioBlob) {
      throw new Error(`Download failed: ${downloadError?.message}`)
    }

    console.log(`Downloaded audio, size: ${audioBlob.size} bytes`)

    // 4. Transcribe audio
    const fileName = storagePath.split('/').pop() || 'audio.webm'
    const contextPrompt = "This is a voice note from a construction site shared between project stakeholders. It may contain updates, requests for approval, or action items. Common terms: concrete, scaffolding, safety, foundation, rebar, excavation, slab work, formwork. The audio may be in English, Hindi, Telugu, Tamil, Kannada, Malayalam, or other languages."
    
    let originalText = ""
    let detectedLanguage = "unknown"
    const translations: { [key: string]: string } = {}

    // Transcribe in original language
    console.log(`Step 1: Transcribing with ${providerName}...`)
    const transcriptionResult = await provider.transcribe(audioBlob, fileName, contextPrompt)
    originalText = transcriptionResult.text
    detectedLanguage = transcriptionResult.language
    
    console.log(`✅ Detected language: ${detectedLanguage}`)
    console.log(`✅ Original transcription: ${originalText}`)

    // Translate to English if needed
    if (detectedLanguage !== 'en') {
      console.log(`Step 2: Translating to English with ${providerName}...`)
      try {
        const translationResult = await provider.translateToEnglish(audioBlob, fileName, contextPrompt)
        translations['en'] = translationResult.text
        console.log(`✅ English translation: ${translations['en']}`)
      } catch (error) {
        console.error('Translation to English failed, using original text:', error)
        translations['en'] = originalText
      }
    } else {
      translations['en'] = originalText
    }

    // Translate to other required languages
    for (const lang of recipientLanguages) {
      if (lang === 'en' || translations[lang]) {
        continue
      }
      
      if (lang === detectedLanguage) {
        translations[lang] = originalText
        continue
      }
      
      try {
        console.log(`Step 3: Translating to ${lang} with ${providerName}...`)
        translations[lang] = await provider.translateText(translations['en'] || originalText, lang)
        console.log(`✅ Translated to ${lang}`)
      } catch (error) {
        console.error(`Translation to ${lang} failed:`, error)
        translations[lang] = translations['en'] || originalText
      }
    }

    // 5. Classify the voice note
    console.log(`Step 4: Classifying with ${providerName}...`)
    let classification: ClassificationResult
    
    try {
      classification = await provider.classify(translations['en'] || originalText)
      console.log(`✅ Classified as: ${classification.category} (priority: ${classification.priority})`)
    } catch (error) {
      console.error('Classification failed, using fallback:', error)
      classification = fallbackClassify(translations['en'] || originalText)
      console.log(`⚠️ Fallback classified as: ${classification.category}`)
    }

    // 6. Create action item
    await supabase.from('action_items').insert({
      voice_note_id: record.id,
      account_id: record.account_id,
      project_id: record.project_id,
      user_id: record.user_id,
      category: classification.category,
      priority: classification.priority,
      summary: classification.summary || (translations['en'] || originalText).substring(0, 200),
      details: translations['en'] || originalText,
      ai_analysis: classification.analysis,
      status: 'pending'
    })

    console.log(`✅ Created action item: ${classification.category}, priority: ${classification.priority}`)

    // 7. Format transcription for display
    const languageNames: { [key: string]: string } = {
      'es': 'Spanish', 'fr': 'French', 'de': 'German', 'hi': 'Hindi',
      'te': 'Telugu', 'ta': 'Tamil', 'mr': 'Marathi', 'bn': 'Bengali',
      'kn': 'Kannada', 'ml': 'Malayalam',
      'pt': 'Portuguese', 'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean',
      'ar': 'Arabic', 'ru': 'Russian', 'it': 'Italian'
    }
    
    const languageName = languageNames[detectedLanguage] || detectedLanguage.toUpperCase()
    let displayTranscription = ""
    
    if (detectedLanguage === 'en') {
      displayTranscription = originalText
    } else {
      displayTranscription = `[${languageName}] ${originalText}\n\n[English] ${translations['en']}`
    }

    // 8. Update database
    const { error: updateError } = await supabase
      .from('voice_notes')
      .update({ 
        transcription: displayTranscription,
        translated_transcription: translations,
        detected_language: detectedLanguage,
        category: classification.category,
        status: 'completed'
      })
      .eq('id', record.id)

    if (updateError) {
      throw new Error(`Failed to update record: ${updateError.message}`)
    }

    console.log(`✅ Successfully processed record ${record.id}`)
    console.log(`   Provider: ${providerName}`)
    console.log(`   Detected language: ${detectedLanguage}`)
    console.log(`   Category: ${classification.category}, Priority: ${classification.priority}`)
    console.log(`   Translations available:`, Object.keys(translations))

    return new Response(
      JSON.stringify({ 
        success: true,
        provider: providerName,
        transcription: displayTranscription,
        translated_transcription: translations,
        detected_language: detectedLanguage,
        category: classification.category,
        priority: classification.priority,
        ai_analysis: classification.analysis,
        record_id: record.id 
      }), 
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )

  } catch (err: any) {
    console.error("TRANSCRIPTION ERROR:", err)
    return new Response(
      JSON.stringify({ 
        error: err.message,
        stack: err.stack 
      }), 
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})