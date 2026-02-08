import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const { action, account_id, actor_id } = await req.json()

    // Validate required fields
    if (!action || !account_id || !actor_id) {
      return new Response(
        JSON.stringify({
          error: 'Missing required fields: action, account_id, actor_id'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate action
    if (!['activate', 'deactivate', 'archive'].includes(action)) {
      return new Response(
        JSON.stringify({ error: 'Invalid action. Must be: activate, deactivate, or archive' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify actor is a super admin
    const { data: superAdmin } = await supabaseAdmin
      .from('super_admins')
      .select('id')
      .eq('id', actor_id)
      .maybeSingle()

    if (!superAdmin) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized. Only super admins can manage company status.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get current company status
    const { data: company } = await supabaseAdmin
      .from('accounts')
      .select('id, company_name, status')
      .eq('id', account_id)
      .maybeSingle()

    if (!company) {
      return new Response(
        JSON.stringify({ error: 'Company not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let resultMessage = ''
    const previousStatus = company.status

    if (action === 'activate') {
      if (company.status === 'active') {
        return new Response(
          JSON.stringify({ error: 'Company is already active' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Cannot re-activate archived companies (intentional business rule)
      if (company.status === 'archived') {
        return new Response(
          JSON.stringify({ error: 'Archived companies cannot be reactivated. Data is preserved for viewing only.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Activate the company
      const { error: updateError } = await supabaseAdmin
        .from('accounts')
        .update({
          status: 'active',
          deactivated_at: null,
        })
        .eq('id', account_id)

      if (updateError) throw updateError

      // Re-activate all user associations that were deactivated when company was deactivated
      // Only re-activate those that were 'inactive' (not 'removed')
      await supabaseAdmin
        .from('user_company_associations')
        .update({
          status: 'active',
          deactivated_at: null,
          deactivated_by: null,
        })
        .eq('account_id', account_id)
        .eq('status', 'inactive')

      resultMessage = `Company "${company.company_name}" activated successfully`

    } else if (action === 'deactivate') {
      if (company.status !== 'active') {
        return new Response(
          JSON.stringify({ error: `Company is currently ${company.status}, not active` }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Deactivate the company
      const { error: updateError } = await supabaseAdmin
        .from('accounts')
        .update({
          status: 'inactive',
          deactivated_at: new Date().toISOString(),
        })
        .eq('id', account_id)

      if (updateError) throw updateError

      // Deactivate all active user associations
      await supabaseAdmin
        .from('user_company_associations')
        .update({
          status: 'inactive',
          deactivated_at: new Date().toISOString(),
          deactivated_by: actor_id,
        })
        .eq('account_id', account_id)
        .eq('status', 'active')

      resultMessage = `Company "${company.company_name}" deactivated successfully`

    } else if (action === 'archive') {
      if (company.status === 'archived') {
        return new Response(
          JSON.stringify({ error: 'Company is already archived' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Archive the company
      const { error: updateError } = await supabaseAdmin
        .from('accounts')
        .update({
          status: 'archived',
          archived_at: new Date().toISOString(),
          deactivated_at: company.deactivated_at || new Date().toISOString(),
        })
        .eq('id', account_id)

      if (updateError) throw updateError

      // Deactivate all remaining active user associations
      await supabaseAdmin
        .from('user_company_associations')
        .update({
          status: 'inactive',
          deactivated_at: new Date().toISOString(),
          deactivated_by: actor_id,
        })
        .eq('account_id', account_id)
        .eq('status', 'active')

      resultMessage = `Company "${company.company_name}" archived successfully. Data is preserved for viewing.`
    }

    // Audit log
    await supabaseAdmin.from('user_management_audit_log').insert({
      actor_id: actor_id,
      target_user_id: null,
      account_id: account_id,
      action: `company_${action}`,
      details: {
        company_name: company.company_name,
        previous_status: previousStatus,
        new_status: action === 'activate' ? 'active' : action === 'deactivate' ? 'inactive' : 'archived',
      },
    })

    return new Response(
      JSON.stringify({ success: true, message: resultMessage }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in manage-company-status:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'An unexpected error occurred' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
