import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Indian construction module templates for the AI prompt
const MODULE_TEMPLATES = `
CONSTRUCTION PHASE TEMPLATES (Indian Context):
1. Site Clearance & Layout (5 days, structural)
2. Soil Investigation (7 days, structural)
3. Excavation & PCC (8 days, structural) - High monsoon risk
4. Anti-termite Treatment (2 days, specialty) - IS 6313
5. Footings & Foundation (14 days, structural) - M25 min, curing 28 days
6. Damp Proof Course/DPC (3 days, specialty) - IS 3067
7. Plinth Beam & Backfill (7 days, structural)
8. Columns (10 days, structural) - M25 or higher
9. Brick Masonry (14 days, structural) - Red brick/AAC/Fly ash
10. Lintel Beams & Chajjas (5 days, structural)
11. Roof Slab (12 days, structural) - High monsoon risk, M25 vibrator compaction
12. Upper Floors (30 days, structural) - Allow 28 days curing before loading
13. Electrical Conduit Rough-in (7 days, mep) - IS 732
14. Plumbing Rough-in (7 days, mep) - IS 1172, CPVC for hot water
15. Roof Waterproofing (5 days, specialty) - Critical before monsoon, IS 3067
16. External Waterproofing (4 days, specialty)
17. External Plastering (10 days, finishing) - Avoid during monsoon
18. Internal Plastering (12 days, finishing) - Gypsum or cement IS 1661
19. Flooring (14 days, finishing) - Vitrified/granite/marble IS 13630
20. Doors & Windows (7 days, finishing)
21. Painting External (7 days, finishing) - High monsoon risk, avoid during rains
22. Painting Internal (10 days, finishing)
23. Electrical Finishing (5 days, mep) - IS 732, ELCB mandatory
24. Plumbing Finishing (5 days, mep) - IS 1172, pressure test
25. Final Inspection & OC (5 days, legal) - BBMP/Corporation approval

INDIAN CONTEXT RULES:
- Monsoon window: Jun 1 – Sep 30 (Bangalore/South India). Add 20% buffer to exterior phases starting in this period.
- Festival breaks: Diwali (Oct/Nov) +7 days, Pongal/Sankranti (Jan) +3 days, Holi (Mar) +2 days
- IS codes: IS 456 (RCC), IS 1172 (plumbing), IS 732 (electrical), IS 3067 (waterproofing), NBC 2016
- Concrete minimum M25 for structural elements
- Steel TMT Fe500D preferred
- Curing: Concrete 28 days minimum for structural, 7 days for non-structural
- Water quality: TDS < 2000 ppm for construction
- Sand: silt content < 8%
`

const STARTING_POINT_CONTEXT: Record<string, string> = {
  empty_plot: 'Start from scratch. Include all phases from soil investigation through final inspection.',
  existing_structure: 'Existing structure in place. Skip foundation/structural phases unless specifically needed. Focus on renovation, MEP, and finishing.',
  interior_shell: 'Structure complete with external walls. Focus on MEP rough-in, plastering, flooring, fixtures, and painting.',
  occupied_space: 'Site is occupied during construction. Add 30% buffer to all phases for limited working hours. Sequence work room by room.',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { project_id, account_id, q1, q2, q3, language, site_type, area_sqft, number_of_floors, estimated_budget_lakhs } = await req.json()

    if (!project_id || !account_id) {
      return new Response(
        JSON.stringify({ error: 'project_id and account_id are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fetch project info
    const { data: project } = await supabaseClient
      .from('projects')
      .select('name, created_at')
      .eq('id', project_id)
      .single()

    // Fetch relevant module IDs from DB for foreign keys
    const { data: modules } = await supabaseClient
      .from('milestone_modules')
      .select('id, name, sequence_order, typical_duration_days')
      .is('account_id', null)
      .order('sequence_order', { ascending: true })

    const startingContext = STARTING_POINT_CONTEXT[q1] || STARTING_POINT_CONTEXT.empty_plot

    // Build project details context from optional fields
    const projectDetailsLines: string[] = []
    if (site_type) projectDetailsLines.push(`Site type: ${site_type.replace('_', ' ')}`)
    if (area_sqft) projectDetailsLines.push(`Construction area: ${area_sqft} sq ft`)
    if (number_of_floors !== undefined && number_of_floors !== null) {
      projectDetailsLines.push(`Number of floors: ${number_of_floors === 0 ? 'Ground floor only' : number_of_floors}`)
    }
    if (estimated_budget_lakhs) projectDetailsLines.push(`Estimated budget: ₹${estimated_budget_lakhs} Lakhs`)
    const projectDetailsContext = projectDetailsLines.length > 0
      ? `\nPROJECT DETAILS:\n${projectDetailsLines.join('\n')}`
      : ''

    // Build budget instruction outside the template literal to avoid nested backtick issues
    const budgetInstruction = estimated_budget_lakhs
      ? 'The total of all phase budget_allocated values MUST sum exactly to Rs.' + (estimated_budget_lakhs * 100000) + ' (= Rs.' + estimated_budget_lakhs + ' Lakhs). Distribute proportionally based on phase complexity and duration.'
      : 'Provide reasonable budget estimates for each phase in INR.'

    const today = new Date().toISOString().split('T')[0]
    const monsoonBuffer = Math.round(1.2 * 100 - 100)

    const systemPrompt = `You are an expert Indian construction project manager. Generate a realistic milestone plan for a construction project.

${MODULE_TEMPLATES}

STARTING POINT: ${startingContext}
WORK TYPES REQUESTED: ${q2}
TIMELINE & CONSTRAINTS: ${q3}${projectDetailsContext}

OUTPUT REQUIREMENTS:
- Return a JSON array of phases
- Select 8-15 relevant phases from the templates above based on starting point and work types
- For each phase calculate realistic dates considering:
  * Today: ${today}
  * Monsoon buffer (add ${monsoonBuffer}% to exterior phases Jun-Sep)
  * Festival breaks
  * Phase dependencies (each phase starts after previous ends + 1 day buffer)
- Include 3-5 key results per phase
- BUDGET ALLOCATION: ${budgetInstruction}

Return ONLY valid JSON in this exact format:
{
  "phases": [
    {
      "module_name": "Excavation & PCC",
      "phase_order": 1,
      "planned_start": "2026-03-01",
      "planned_end": "2026-03-10",
      "budget_allocated": 45000,
      "key_results": [
        {"title": "Complete excavation to design depth", "metric_type": "boolean", "target_value": 1, "unit": null},
        {"title": "Pour PCC bed", "metric_type": "percentage", "target_value": 100, "unit": "%"},
        {"title": "Anti-termite treatment completed", "metric_type": "boolean", "target_value": 1, "unit": null}
      ]
    }
  ]
}`

    const groqApiKey = Deno.env.get('GROQ_API_KEY')
    if (!groqApiKey) {
      throw new Error('GROQ_API_KEY not configured')
    }

    // Call Groq API
    const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: `Generate the construction milestone plan for project "${project?.name || 'Construction Project'}". Starting point: ${q1}, Work types: ${q2}, Timeline: ${q3}${projectDetailsContext ? '. ' + projectDetailsContext.trim() : ''}` }
        ],
        max_tokens: 4000,
        temperature: 0.3,
        response_format: { type: 'json_object' },
      }),
    })

    if (!groqResponse.ok) {
      throw new Error(`Groq API error: ${groqResponse.status} ${await groqResponse.text()}`)
    }

    const groqData = await groqResponse.json()
    const content = groqData.choices[0]?.message?.content

    let planData: { phases: any[] }
    try {
      planData = JSON.parse(content)
    } catch {
      throw new Error('Failed to parse AI response as JSON')
    }

    if (!planData.phases || !Array.isArray(planData.phases)) {
      throw new Error('Invalid plan structure: missing phases array')
    }

    // Normalize phase budgets so they sum exactly to the total project budget
    const budgetLakhs = Number(estimated_budget_lakhs) || 0
    if (budgetLakhs > 0) {
      const totalBudgetRupees = budgetLakhs * 100000
      const aiSum = planData.phases.reduce((s: number, p: any) => s + (Number(p.budget_allocated) || 0), 0)
      console.log('[budget-normalize] budgetLakhs=' + budgetLakhs + ', totalBudgetRupees=' + totalBudgetRupees + ', aiSum=' + aiSum)
      if (aiSum > 0) {
        const scale = totalBudgetRupees / aiSum
        for (const phase of planData.phases) {
          const val = Number(phase.budget_allocated) || 0
          if (val > 0) {
            phase.budget_allocated = Math.round(val * scale)
          }
        }
        // Fix rounding: add/subtract remainder to the largest phase
        const normalizedSum = planData.phases.reduce((s: number, p: any) => s + (Number(p.budget_allocated) || 0), 0)
        const remainder = totalBudgetRupees - normalizedSum
        if (remainder !== 0) {
          const largest = planData.phases.reduce((max: any, p: any) =>
            (Number(p.budget_allocated) || 0) > (Number(max.budget_allocated) || 0) ? p : max, planData.phases[0])
          largest.budget_allocated = (Number(largest.budget_allocated) || 0) + remainder
        }
        console.log('[budget-normalize] final sum=' + planData.phases.reduce((s: number, p: any) => s + (Number(p.budget_allocated) || 0), 0))
      } else {
        // AI returned no budgets at all — distribute evenly
        const perPhase = Math.round(totalBudgetRupees / planData.phases.length)
        for (const phase of planData.phases) {
          phase.budget_allocated = perPhase
        }
        // Fix remainder on first phase
        const evenSum = perPhase * planData.phases.length
        if (evenSum !== totalBudgetRupees) {
          planData.phases[0].budget_allocated += (totalBudgetRupees - evenSum)
        }
        console.log('[budget-normalize] no AI budgets, distributed evenly: ' + perPhase + ' per phase')
      }
    }

    // Build module name→id map
    const moduleMap: Record<string, string> = {}
    for (const mod of (modules || [])) {
      moduleMap[mod.name.toLowerCase()] = mod.id
    }

    // Insert phases and key results into DB
    for (const phase of planData.phases) {
      // Find matching module ID (fuzzy match)
      let moduleId: string | null = null
      const phaseLower = phase.module_name?.toLowerCase() || ''
      for (const [name, id] of Object.entries(moduleMap)) {
        if (phaseLower.includes(name.split(' ')[0].toLowerCase()) || name.includes(phaseLower.split(' ')[0])) {
          moduleId = id
          break
        }
      }

      const { data: phaseRow, error: phaseError } = await supabaseClient
        .from('milestone_phases')
        .insert({
          project_id,
          account_id,
          module_id: moduleId,
          name: phase.module_name || `Phase ${phase.phase_order}`,
          phase_order: phase.phase_order,
          status: 'pending',
          planned_start: phase.planned_start || null,
          planned_end: phase.planned_end || null,
          budget_allocated: phase.budget_allocated || null,
        })
        .select('id')
        .single()

      if (phaseError || !phaseRow) {
        console.error('Phase insert error:', phaseError)
        continue
      }

      // Insert key results
      if (phase.key_results && Array.isArray(phase.key_results)) {
        const krInserts = phase.key_results.map((kr: any) => ({
          phase_id: phaseRow.id,
          project_id,
          account_id,
          title: kr.title,
          metric_type: kr.metric_type || 'boolean',
          target_value: kr.target_value ?? 1,
          current_value: 0,
          unit: kr.unit || null,
          auto_track: false,
          completed: false,
        }))

        const { error: krError } = await supabaseClient
          .from('key_results')
          .insert(krInserts)

        if (krError) {
          console.error('Key results insert error:', krError)
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, phases_created: planData.phases.length }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('generate-milestone-plan error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
