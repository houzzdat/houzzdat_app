import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/* ============================================================
   RETRY UTILITY (copied from transcribe-audio)
============================================================ */

async function fetchWithRetry(
  url: string,
  options: RequestInit,
  maxRetries = 3
): Promise<Response> {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const timeoutMs = attempt === 1 ? 45000 : 60000;
      const res = await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(timeoutMs),
      });

      if (res.ok) return res;

      if ((res.status === 429 || res.status >= 500) && attempt < maxRetries) {
        const backoffMs = 1000 * attempt;
        console.warn(`  ⚠ Attempt ${attempt} got ${res.status}, retrying in ${backoffMs}ms...`);
        await new Promise(r => setTimeout(r, backoffMs));
        continue;
      }

      return res;
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
  throw new Error('fetchWithRetry exhausted all retries');
}

/* ============================================================
   LLM FUNCTIONS (copied from transcribe-audio)
============================================================ */

async function callGeminiLLM(key: string, options: { prompt: string, context?: string | null }) {
  const parts: any[] = [{ text: options.prompt }];
  if (options.context) {
    parts.push({ text: options.context });
  }

  const res = await fetchWithRetry(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${key}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 8000
        }
      })
    }
  );

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Gemini LLM failed: ${data.error?.message || res.status}`);
  }

  return data.candidates?.[0]?.content?.parts?.[0]?.text || '';
}

async function callRegistryLLM(
  provider: string,
  key: string,
  options: {
    prompt: string,
    context?: string | null,
  }
): Promise<string> {
  if (provider === 'gemini') {
    return callGeminiLLM(key, options);
  }

  const baseUrl = provider === 'groq'
    ? 'https://api.groq.com/openai/v1'
    : 'https://api.openai.com/v1';

  const model = provider === 'groq'
    ? 'llama-3.3-70b-versatile'
    : 'gpt-4o-mini';

  const messages: any[] = [{ role: 'system', content: options.prompt }];
  if (options.context) {
    messages.push({ role: 'user', content: options.context });
  }

  console.log(`  → Calling ${provider} LLM (${model}) for report generation...`);
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
      temperature: 0.3,
      max_tokens: 8000
    })
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`LLM call failed: ${data.error?.message}`);
  }

  console.log(`  ✓ LLM completed in ${(performance.now() - t0).toFixed(0)}ms`);

  return data.choices[0].message.content;
}

/* ============================================================
   HELPER: Build structured data context for AI
============================================================ */

function buildDataContext(data: {
  projects: any[],
  actionItems: any[],
  voiceNotes: any[],
  invoices: any[],
  payments: any[],
  ownerPayments: any[],
  fundRequests: any[],
  attendance: any[],
  startDate: string,
  endDate: string,
}): string {
  const { projects, actionItems, voiceNotes, invoices, payments, ownerPayments, fundRequests, attendance, startDate, endDate } = data;

  // Summarize action items by status
  const actionsByStatus: Record<string, number> = {};
  const criticalActions: any[] = [];
  const highPriorityActions: any[] = [];
  for (const a of actionItems) {
    const status = a.status || 'unknown';
    actionsByStatus[status] = (actionsByStatus[status] || 0) + 1;
    if (a.is_critical_flag) criticalActions.push(a);
    if (a.priority === 'High' || a.priority === 'Critical') highPriorityActions.push(a);
  }

  // Summarize voice notes
  const notesByCategory: Record<string, number> = {};
  const noteSummaries: string[] = [];
  for (const vn of voiceNotes) {
    const cat = vn.category || 'update';
    notesByCategory[cat] = (notesByCategory[cat] || 0) + 1;
    if (vn.transcript_final) {
      const sender = vn.users?.full_name || 'Unknown';
      const project = vn.projects?.name || 'Unknown';
      const preview = vn.transcript_final.substring(0, 200);
      noteSummaries.push(`[${sender} @ ${project}]: ${preview}`);
    }
  }

  // Financial summaries
  const totalInvoiced = invoices.reduce((s: number, i: any) => s + (Number(i.amount) || 0), 0);
  const totalPayments = payments.reduce((s: number, p: any) => s + (Number(p.amount) || 0), 0);
  const totalOwnerPayments = ownerPayments.reduce((s: number, p: any) => s + (Number(p.amount) || 0), 0);
  const pendingInvoices = invoices.filter((i: any) => ['draft', 'submitted', 'approved'].includes(i.status));
  const overdueInvoices = invoices.filter((i: any) => {
    if (i.status === 'paid') return false;
    if (!i.due_date) return false;
    return new Date(i.due_date) < new Date();
  });
  const pendingFundRequests = fundRequests.filter((f: any) => f.status === 'pending');

  // Attendance summary
  const totalCheckIns = attendance.length;
  const uniqueWorkers = new Set(attendance.map((a: any) => a.user_id)).size;
  let totalHoursWorked = 0;
  for (const a of attendance) {
    if (a.check_in_at && a.check_out_at) {
      const hours = (new Date(a.check_out_at).getTime() - new Date(a.check_in_at).getTime()) / (1000 * 60 * 60);
      totalHoursWorked += hours;
    }
  }
  const avgHours = totalCheckIns > 0 ? (totalHoursWorked / totalCheckIns).toFixed(1) : '0';

  return JSON.stringify({
    period: { start_date: startDate, end_date: endDate },
    sites: projects.map((p: any) => ({ name: p.name, location: p.location })),
    action_items: {
      total: actionItems.length,
      by_status: actionsByStatus,
      critical_items: criticalActions.map((a: any) => ({
        summary: a.summary,
        status: a.status,
        priority: a.priority,
        project: a.projects?.name,
        assigned_to: a.assigned_user?.full_name,
      })),
      high_priority_items: highPriorityActions.map((a: any) => ({
        summary: a.summary,
        status: a.status,
        category: a.category,
        project: a.projects?.name,
      })),
      recent_items: actionItems.slice(0, 20).map((a: any) => ({
        summary: a.summary,
        details: a.details?.substring(0, 300),
        status: a.status,
        category: a.category,
        priority: a.priority,
        project: a.projects?.name,
        created_by: a.creator?.full_name,
        assigned_to: a.assigned_user?.full_name,
      })),
    },
    voice_notes: {
      total: voiceNotes.length,
      by_category: notesByCategory,
      summaries: noteSummaries.slice(0, 30),
    },
    finances: {
      total_invoiced: totalInvoiced,
      total_payments: totalPayments,
      total_owner_payments: totalOwnerPayments,
      pending_invoices_count: pendingInvoices.length,
      pending_invoices_amount: pendingInvoices.reduce((s: number, i: any) => s + (Number(i.amount) || 0), 0),
      overdue_invoices_count: overdueInvoices.length,
      overdue_invoices_amount: overdueInvoices.reduce((s: number, i: any) => s + (Number(i.amount) || 0), 0),
      invoices_detail: invoices.slice(0, 20).map((i: any) => ({
        invoice_number: i.invoice_number,
        vendor: i.vendor,
        amount: i.amount,
        status: i.status,
        project: i.projects?.name,
        due_date: i.due_date,
      })),
      payments_detail: payments.slice(0, 20).map((p: any) => ({
        amount: p.amount,
        method: p.payment_method,
        paid_to: p.paid_to,
        project: p.projects?.name,
        date: p.payment_date,
      })),
      fund_requests_total: fundRequests.length,
      fund_requests_pending: pendingFundRequests.length,
      fund_requests_total_amount: fundRequests.reduce((s: number, f: any) => s + (Number(f.amount) || 0), 0),
      fund_requests_detail: fundRequests.slice(0, 10).map((f: any) => ({
        title: f.title,
        amount: f.amount,
        urgency: f.urgency,
        status: f.status,
        project: f.projects?.name,
      })),
    },
    attendance: {
      total_check_ins: totalCheckIns,
      unique_workers: uniqueWorkers,
      total_hours_worked: totalHoursWorked.toFixed(1),
      average_hours_per_worker: avgHours,
      records: attendance.slice(0, 30).map((a: any) => ({
        worker: a.users?.full_name,
        site: a.projects?.name,
        check_in: a.check_in_at,
        check_out: a.check_out_at,
        report_type: a.report_type,
        report_text: a.report_text?.substring(0, 200),
      })),
    },
  }, null, 2);
}

/* ============================================================
   MAIN HANDLER
============================================================ */

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const pipelineStart = performance.now();
  console.log("=== Report Generation Started ===");

  try {
    const payload = await req.json();
    const { account_id, start_date, end_date, project_ids } = payload;

    if (!account_id) throw new Error("account_id required");
    if (!start_date) throw new Error("start_date required");
    if (!end_date) throw new Error("end_date required");

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    /* --------------------------------------------------
       PHASE 1: FETCH ACCOUNT SETTINGS
    -------------------------------------------------- */
    console.log(`[1] Fetching account settings for ${account_id}...`);

    const { data: account, error: accErr } = await supabase
      .from("accounts")
      .select("id, name, transcription_provider")
      .eq("id", account_id)
      .single();

    if (accErr || !account) {
      throw new Error(`Account not found: ${accErr?.message}`);
    }

    const providerName = account.transcription_provider || 'groq';
    const apiKey = Deno.env.get(`${providerName.toUpperCase()}_API_KEY`);
    if (!apiKey) throw new Error(`API Key for ${providerName} not found`);

    console.log(`  Provider: ${providerName}`);

    /* --------------------------------------------------
       PHASE 2: FETCH AI PROMPTS
    -------------------------------------------------- */
    console.log(`[2] Fetching AI prompts...`);

    const [managerPromptResult, ownerPromptResult] = await Promise.all([
      supabase
        .from("ai_prompts")
        .select("*")
        .eq("provider", providerName)
        .eq("purpose", "manager_report_generation")
        .eq("is_active", true)
        .order("version", { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase
        .from("ai_prompts")
        .select("*")
        .eq("provider", providerName)
        .eq("purpose", "owner_report_generation")
        .eq("is_active", true)
        .order("version", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ]);

    const managerPrompt = managerPromptResult.data?.prompt;
    const ownerPrompt = ownerPromptResult.data?.prompt;

    if (!managerPrompt) throw new Error("Manager report prompt not found in ai_prompts table");
    if (!ownerPrompt) throw new Error("Owner report prompt not found in ai_prompts table");

    console.log(`  ✓ Prompts loaded (manager v${managerPromptResult.data?.version}, owner v${ownerPromptResult.data?.version})`);

    /* --------------------------------------------------
       PHASE 3: PARALLEL DATA FETCH
    -------------------------------------------------- */
    console.log(`[3] Fetching data for period ${start_date} to ${end_date}...`);
    const dataStart = performance.now();

    // Build project filter for queries
    const hasProjectFilter = project_ids && project_ids.length > 0;

    // Build base queries with date range
    const startDateStr = `${start_date}T00:00:00.000Z`;
    const endDateStr = `${end_date}T23:59:59.999Z`;

    // Parallel fetch all data sources
    const [
      actionItemsResult,
      voiceNotesResult,
      invoicesResult,
      paymentsResult,
      ownerPaymentsResult,
      fundRequestsResult,
      attendanceResult,
      projectsResult,
    ] = await Promise.all([
      // 1. Action Items
      (() => {
        let q = supabase
          .from("action_items")
          .select("*, projects(name), creator:users!action_items_user_id_fkey(full_name), assigned_user:users!action_items_assigned_to_fkey(full_name)")
          .eq("account_id", account_id)
          .gte("created_at", startDateStr)
          .lte("created_at", endDateStr)
          .order("created_at", { ascending: false });
        if (hasProjectFilter) q = q.in("project_id", project_ids);
        return q;
      })(),

      // 2. Voice Notes
      (() => {
        let q = supabase
          .from("voice_notes")
          .select("*, users!voice_notes_user_id_fkey(full_name), projects(name)")
          .eq("account_id", account_id)
          .eq("status", "completed")
          .gte("created_at", startDateStr)
          .lte("created_at", endDateStr)
          .order("created_at", { ascending: false });
        if (hasProjectFilter) q = q.in("project_id", project_ids);
        return q;
      })(),

      // 3. Invoices
      (() => {
        let q = supabase
          .from("invoices")
          .select("*, projects(name)")
          .eq("account_id", account_id)
          .gte("created_at", startDateStr)
          .lte("created_at", endDateStr)
          .order("created_at", { ascending: false });
        if (hasProjectFilter) q = q.in("project_id", project_ids);
        return q;
      })(),

      // 4. Payments
      (() => {
        let q = supabase
          .from("payments")
          .select("*, projects(name)")
          .eq("account_id", account_id)
          .gte("payment_date", start_date)
          .lte("payment_date", end_date)
          .order("payment_date", { ascending: false });
        if (hasProjectFilter) q = q.in("project_id", project_ids);
        return q;
      })(),

      // 5. Owner Payments
      (() => {
        let q = supabase
          .from("owner_payments")
          .select("*, users!owner_payments_owner_id_fkey(full_name), projects(name)")
          .eq("account_id", account_id)
          .gte("received_date", start_date)
          .lte("received_date", end_date)
          .order("received_date", { ascending: false });
        if (hasProjectFilter) q = q.in("project_id", project_ids);
        return q;
      })(),

      // 6. Fund Requests
      (() => {
        let q = supabase
          .from("fund_requests")
          .select("*, projects(name)")
          .eq("account_id", account_id)
          .gte("created_at", startDateStr)
          .lte("created_at", endDateStr)
          .order("created_at", { ascending: false });
        if (hasProjectFilter) q = q.in("project_id", project_ids);
        return q;
      })(),

      // 7. Attendance
      (() => {
        let q = supabase
          .from("attendance")
          .select("*, users!attendance_user_id_fkey(full_name), projects(name)")
          .eq("account_id", account_id)
          .gte("check_in_at", startDateStr)
          .lte("check_in_at", endDateStr)
          .order("check_in_at", { ascending: false });
        if (hasProjectFilter) q = q.in("project_id", project_ids);
        return q;
      })(),

      // 8. Projects
      (() => {
        let q = supabase
          .from("projects")
          .select("id, name, location")
          .eq("account_id", account_id)
          .order("name");
        if (hasProjectFilter) q = q.in("id", project_ids);
        return q;
      })(),
    ]);

    const actionItems = actionItemsResult.data || [];
    const voiceNotes = voiceNotesResult.data || [];
    const invoices = invoicesResult.data || [];
    const payments = paymentsResult.data || [];
    const ownerPayments = ownerPaymentsResult.data || [];
    const fundRequests = fundRequestsResult.data || [];
    const attendanceRecords = attendanceResult.data || [];
    const projects = projectsResult.data || [];

    console.log(`  ✓ Data fetched in ${(performance.now() - dataStart).toFixed(0)}ms`);
    console.log(`    Actions: ${actionItems.length}, Notes: ${voiceNotes.length}, Invoices: ${invoices.length}`);
    console.log(`    Payments: ${payments.length}, Owner Payments: ${ownerPayments.length}, Fund Requests: ${fundRequests.length}`);
    console.log(`    Attendance: ${attendanceRecords.length}, Projects: ${projects.length}`);

    /* --------------------------------------------------
       PHASE 4: BUILD DATA CONTEXT
    -------------------------------------------------- */
    console.log(`[4] Building data context...`);

    const dataContext = buildDataContext({
      projects,
      actionItems,
      voiceNotes,
      invoices,
      payments,
      ownerPayments,
      fundRequests,
      attendance: attendanceRecords,
      startDate: start_date,
      endDate: end_date,
    });

    /* --------------------------------------------------
       PHASE 5: GENERATE MANAGER REPORT
    -------------------------------------------------- */
    console.log(`[5] Generating manager report via ${providerName}...`);
    const mgr0 = performance.now();

    const managerReport = await callRegistryLLM(providerName, apiKey, {
      prompt: managerPrompt,
      context: `Here is the complete data for the report period. Analyze this data and generate the report:\n\n${dataContext}`,
    });

    console.log(`  ✓ Manager report generated in ${(performance.now() - mgr0).toFixed(0)}ms (${managerReport.length} chars)`);

    /* --------------------------------------------------
       PHASE 6: GENERATE OWNER REPORT
    -------------------------------------------------- */
    console.log(`[6] Generating owner report via ${providerName}...`);
    const own0 = performance.now();

    const ownerReport = await callRegistryLLM(providerName, apiKey, {
      prompt: ownerPrompt,
      context: `Here is the complete data for the report period:\n\n${dataContext}\n\n---\n\nHere is the internal manager report for context (use this to inform your owner report but reframe for the owner audience):\n\n${managerReport}`,
    });

    console.log(`  ✓ Owner report generated in ${(performance.now() - own0).toFixed(0)}ms (${ownerReport.length} chars)`);

    /* --------------------------------------------------
       PHASE 7: SAVE REPORT TO DATABASE
    -------------------------------------------------- */
    console.log(`[7] Saving report to database...`);

    // Get current user from auth header (if available)
    const authHeader = req.headers.get('Authorization');
    let userId: string | null = null;
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '');
      const { data: { user } } = await supabase.auth.getUser(token);
      userId = user?.id || null;
    }

    // Fallback: find the first admin/manager for this account
    if (!userId) {
      const { data: fallbackUser } = await supabase
        .from("users")
        .select("id")
        .eq("account_id", account_id)
        .in("role", ["admin", "manager"])
        .limit(1)
        .maybeSingle();
      userId = fallbackUser?.id;
    }

    if (!userId) throw new Error("Could not determine user for report creation");

    const processingTime = Math.round(performance.now() - pipelineStart);

    const { data: report, error: insertErr } = await supabase
      .from("reports")
      .insert({
        account_id,
        created_by: userId,
        report_type: start_date === end_date ? 'daily' : 'custom',
        start_date,
        end_date,
        project_ids: hasProjectFilter ? project_ids : [],
        manager_report_content: managerReport,
        owner_report_content: ownerReport,
        manager_report_status: 'draft',
        owner_report_status: 'draft',
        ai_provider: providerName,
        generation_time_ms: processingTime,
      })
      .select('id')
      .single();

    if (insertErr) {
      throw new Error(`Failed to save report: ${insertErr.message}`);
    }

    console.log(`  ✓ Report saved: ${report.id}`);
    console.log(`=== Report Generation Complete in ${processingTime}ms ===`);

    return new Response(
      JSON.stringify({
        success: true,
        report_id: report.id,
        manager_report: managerReport,
        owner_report: ownerReport,
        processing_time_ms: processingTime,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error("Report generation failed:", error.message);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
