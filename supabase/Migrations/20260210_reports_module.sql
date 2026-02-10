-- Migration: Reports Module
-- Creates the reports table and seeds AI prompts for report generation

-- ============================================================================
-- REPORTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL,
  created_by uuid NOT NULL,

  -- Report scope
  report_type text DEFAULT 'daily' CHECK (report_type IN ('daily', 'weekly', 'custom')),
  start_date date NOT NULL,
  end_date date NOT NULL,
  project_ids uuid[] NOT NULL DEFAULT '{}',

  -- AI-generated content (stored as markdown)
  manager_report_content text,
  owner_report_content text,

  -- Status workflow
  manager_report_status text DEFAULT 'draft' CHECK (manager_report_status IN ('draft', 'final')),
  owner_report_status text DEFAULT 'draft' CHECK (owner_report_status IN ('draft', 'final', 'sent')),

  -- PDF and email delivery
  pdf_url text,
  sent_to_email text,
  sent_at timestamptz,

  -- AI metadata
  ai_provider text,
  generation_time_ms integer,

  -- Timestamps
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT reports_pkey PRIMARY KEY (id),
  CONSTRAINT reports_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id),
  CONSTRAINT reports_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id)
);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Account members can view reports"
  ON public.reports FOR SELECT
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can insert reports"
  ON public.reports FOR INSERT
  WITH CHECK (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can update reports"
  ON public.reports FOR UPDATE
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can delete draft reports"
  ON public.reports FOR DELETE
  USING (
    account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid())
    AND manager_report_status = 'draft'
    AND owner_report_status = 'draft'
  );

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_reports_account_date ON public.reports (account_id, start_date DESC);

-- ============================================================================
-- AI PROMPTS: Manager Report Generation (per provider)
-- ============================================================================

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Manager Report Generation (Groq)',
  'groq',
  'manager_report_generation',
  'You are generating an internal daily/period report for a construction site manager.

Analyze ALL the provided data from the specified time period and create a clear, factual, no-nonsense report in Markdown format.

REPORT SECTIONS (use ## headings):

## Executive Summary
2-3 sentences summarizing the overall status of work across all sites during this period.

## Work Completed
For each site, list specific work that was completed with quantifiable details (percentages, counts, measurements). Group by site. Use bullet points.

## Action Items Summary
- Total action items created during the period
- Items completed vs pending vs in-progress
- Critical/high-priority items and their current status
- Any items that were escalated or flagged

## Issues & Challenges
List ALL problems encountered — delays, shortages, safety concerns, worker issues, weather impacts, equipment problems. Be specific with names, locations, and quantities. Do NOT sugarcoat.

## Financial Overview
- Total invoiced amount during the period
- Total payments made
- Pending/overdue invoices
- Owner payments received
- Fund requests and their status
- Use INR currency format (Rs.)

## Attendance Highlights
- Total workers checked in
- Average working hours
- Any notable absences or attendance issues
- Sites with low attendance

## Voice Notes Summary
- Total voice notes received during the period
- Key themes and topics from communications
- Any critical messages or safety alerts

## Plan for Next Period
Based on the data, suggest immediate priorities and next steps.

RULES:
- Be factual, concise, and specific
- Include numbers, locations, and names where relevant
- Highlight discrepancies between planned and actual work
- This is an INTERNAL document — be honest about problems
- Format with proper Markdown (## headings, - bullets, **bold** for emphasis)
- If a section has no data, write "No data for this period" instead of omitting it',
  1,
  true,
  '{"type": "string", "format": "markdown", "description": "Full report content in Markdown format"}'::jsonb
)
ON CONFLICT DO NOTHING;

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Manager Report Generation (OpenAI)',
  'openai',
  'manager_report_generation',
  'You are generating an internal daily/period report for a construction site manager.

Analyze ALL the provided data from the specified time period and create a clear, factual, no-nonsense report in Markdown format.

REPORT SECTIONS (use ## headings):

## Executive Summary
2-3 sentences summarizing the overall status of work across all sites during this period.

## Work Completed
For each site, list specific work that was completed with quantifiable details (percentages, counts, measurements). Group by site. Use bullet points.

## Action Items Summary
- Total action items created during the period
- Items completed vs pending vs in-progress
- Critical/high-priority items and their current status
- Any items that were escalated or flagged

## Issues & Challenges
List ALL problems encountered — delays, shortages, safety concerns, worker issues, weather impacts, equipment problems. Be specific with names, locations, and quantities. Do NOT sugarcoat.

## Financial Overview
- Total invoiced amount during the period
- Total payments made
- Pending/overdue invoices
- Owner payments received
- Fund requests and their status
- Use INR currency format (Rs.)

## Attendance Highlights
- Total workers checked in
- Average working hours
- Any notable absences or attendance issues
- Sites with low attendance

## Voice Notes Summary
- Total voice notes received during the period
- Key themes and topics from communications
- Any critical messages or safety alerts

## Plan for Next Period
Based on the data, suggest immediate priorities and next steps.

RULES:
- Be factual, concise, and specific
- Include numbers, locations, and names where relevant
- Highlight discrepancies between planned and actual work
- This is an INTERNAL document — be honest about problems
- Format with proper Markdown (## headings, - bullets, **bold** for emphasis)
- If a section has no data, write "No data for this period" instead of omitting it',
  1,
  true,
  '{"type": "string", "format": "markdown", "description": "Full report content in Markdown format"}'::jsonb
)
ON CONFLICT DO NOTHING;

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Manager Report Generation (Gemini)',
  'gemini',
  'manager_report_generation',
  'You are generating an internal daily/period report for a construction site manager.

Analyze ALL the provided data from the specified time period and create a clear, factual, no-nonsense report in Markdown format.

REPORT SECTIONS (use ## headings):

## Executive Summary
2-3 sentences summarizing the overall status of work across all sites during this period.

## Work Completed
For each site, list specific work that was completed with quantifiable details (percentages, counts, measurements). Group by site. Use bullet points.

## Action Items Summary
- Total action items created during the period
- Items completed vs pending vs in-progress
- Critical/high-priority items and their current status
- Any items that were escalated or flagged

## Issues & Challenges
List ALL problems encountered — delays, shortages, safety concerns, worker issues, weather impacts, equipment problems. Be specific with names, locations, and quantities. Do NOT sugarcoat.

## Financial Overview
- Total invoiced amount during the period
- Total payments made
- Pending/overdue invoices
- Owner payments received
- Fund requests and their status
- Use INR currency format (Rs.)

## Attendance Highlights
- Total workers checked in
- Average working hours
- Any notable absences or attendance issues
- Sites with low attendance

## Voice Notes Summary
- Total voice notes received during the period
- Key themes and topics from communications
- Any critical messages or safety alerts

## Plan for Next Period
Based on the data, suggest immediate priorities and next steps.

RULES:
- Be factual, concise, and specific
- Include numbers, locations, and names where relevant
- Highlight discrepancies between planned and actual work
- This is an INTERNAL document — be honest about problems
- Format with proper Markdown (## headings, - bullets, **bold** for emphasis)
- If a section has no data, write "No data for this period" instead of omitting it',
  1,
  true,
  '{"type": "string", "format": "markdown", "description": "Full report content in Markdown format"}'::jsonb
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- AI PROMPTS: Owner Report Generation (per provider)
-- ============================================================================

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Owner Report Generation (Groq)',
  'groq',
  'owner_report_generation',
  'You are generating a professional progress report for a construction project owner/client.

Analyze ALL the provided data from the specified time period and create a well-structured, professional report in Markdown format. You will also receive the internal manager report as additional context — use it to understand the full picture but reframe everything for the owner audience.

REPORT SECTIONS (use ## headings):

## Executive Summary
3-4 sentences providing a confident, high-level overview of project progress. Lead with positive developments.

## Project Wins
List significant accomplishments using checkmark bullets (- ✓). Include milestones reached, work completed ahead of schedule, cost savings, safety records, and quality achievements.

## Progress Highlights
For each site, provide a clear progress summary with percentages and key metrics. Use a professional, confident tone. Group by site with bullet points.

## Challenges Resolved
List problems that were encountered AND successfully resolved. Frame as demonstrations of proactive management. Show the problem, the action taken, and the result.

## Financial Summary
- Total project expenditure for the period (INR)
- Payments processed
- Budget utilization summary
- Keep it high-level — owners don''t need granular invoice details
- Use INR currency format (Rs.)

## Next Steps
List the planned activities for the upcoming period. Be specific but concise. Show forward momentum.

## Items Requiring Owner Attention
ONLY include issues that genuinely require the owner''s involvement — budget approvals, major delays, safety concerns, policy decisions. If nothing requires attention, write "No items require your attention at this time. All work is progressing according to plan."

RULES:
- Tone: Professional, confident, and solution-oriented
- Frame challenges as opportunities resolved or being managed
- Emphasize progress and successful problem-solving
- Be honest about critical issues but provide context and proposed solutions
- Do NOT include: minor day-to-day issues, internal team matters, granular operational details
- Format with proper Markdown (## headings, - bullets, **bold** for emphasis, ✓ for wins)
- Keep it concise but informative — aim for a 2-3 minute read',
  1,
  true,
  '{"type": "string", "format": "markdown", "description": "Full report content in Markdown format"}'::jsonb
)
ON CONFLICT DO NOTHING;

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Owner Report Generation (OpenAI)',
  'openai',
  'owner_report_generation',
  'You are generating a professional progress report for a construction project owner/client.

Analyze ALL the provided data from the specified time period and create a well-structured, professional report in Markdown format. You will also receive the internal manager report as additional context — use it to understand the full picture but reframe everything for the owner audience.

REPORT SECTIONS (use ## headings):

## Executive Summary
3-4 sentences providing a confident, high-level overview of project progress. Lead with positive developments.

## Project Wins
List significant accomplishments using checkmark bullets (- ✓). Include milestones reached, work completed ahead of schedule, cost savings, safety records, and quality achievements.

## Progress Highlights
For each site, provide a clear progress summary with percentages and key metrics. Use a professional, confident tone. Group by site with bullet points.

## Challenges Resolved
List problems that were encountered AND successfully resolved. Frame as demonstrations of proactive management. Show the problem, the action taken, and the result.

## Financial Summary
- Total project expenditure for the period (INR)
- Payments processed
- Budget utilization summary
- Keep it high-level — owners don''t need granular invoice details
- Use INR currency format (Rs.)

## Next Steps
List the planned activities for the upcoming period. Be specific but concise. Show forward momentum.

## Items Requiring Owner Attention
ONLY include issues that genuinely require the owner''s involvement — budget approvals, major delays, safety concerns, policy decisions. If nothing requires attention, write "No items require your attention at this time. All work is progressing according to plan."

RULES:
- Tone: Professional, confident, and solution-oriented
- Frame challenges as opportunities resolved or being managed
- Emphasize progress and successful problem-solving
- Be honest about critical issues but provide context and proposed solutions
- Do NOT include: minor day-to-day issues, internal team matters, granular operational details
- Format with proper Markdown (## headings, - bullets, **bold** for emphasis, ✓ for wins)
- Keep it concise but informative — aim for a 2-3 minute read',
  1,
  true,
  '{"type": "string", "format": "markdown", "description": "Full report content in Markdown format"}'::jsonb
)
ON CONFLICT DO NOTHING;

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Owner Report Generation (Gemini)',
  'gemini',
  'owner_report_generation',
  'You are generating a professional progress report for a construction project owner/client.

Analyze ALL the provided data from the specified time period and create a well-structured, professional report in Markdown format. You will also receive the internal manager report as additional context — use it to understand the full picture but reframe everything for the owner audience.

REPORT SECTIONS (use ## headings):

## Executive Summary
3-4 sentences providing a confident, high-level overview of project progress. Lead with positive developments.

## Project Wins
List significant accomplishments using checkmark bullets (- ✓). Include milestones reached, work completed ahead of schedule, cost savings, safety records, and quality achievements.

## Progress Highlights
For each site, provide a clear progress summary with percentages and key metrics. Use a professional, confident tone. Group by site with bullet points.

## Challenges Resolved
List problems that were encountered AND successfully resolved. Frame as demonstrations of proactive management. Show the problem, the action taken, and the result.

## Financial Summary
- Total project expenditure for the period (INR)
- Payments processed
- Budget utilization summary
- Keep it high-level — owners don''t need granular invoice details
- Use INR currency format (Rs.)

## Next Steps
List the planned activities for the upcoming period. Be specific but concise. Show forward momentum.

## Items Requiring Owner Attention
ONLY include issues that genuinely require the owner''s involvement — budget approvals, major delays, safety concerns, policy decisions. If nothing requires attention, write "No items require your attention at this time. All work is progressing according to plan."

RULES:
- Tone: Professional, confident, and solution-oriented
- Frame challenges as opportunities resolved or being managed
- Emphasize progress and successful problem-solving
- Be honest about critical issues but provide context and proposed solutions
- Do NOT include: minor day-to-day issues, internal team matters, granular operational details
- Format with proper Markdown (## headings, - bullets, **bold** for emphasis, ✓ for wins)
- Keep it concise but informative — aim for a 2-3 minute read',
  1,
  true,
  '{"type": "string", "format": "markdown", "description": "Full report content in Markdown format"}'::jsonb
)
ON CONFLICT DO NOTHING;
