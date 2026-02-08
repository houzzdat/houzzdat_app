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

    const { action, target_user_id, account_id, actor_id } = await req.json()

    // Validate required fields
    if (!action || !target_user_id || !account_id || !actor_id) {
      return new Response(
        JSON.stringify({
          error: 'Missing required fields: action, target_user_id, account_id, actor_id'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate action
    if (!['deactivate', 'activate', 'remove'].includes(action)) {
      return new Response(
        JSON.stringify({ error: 'Invalid action. Must be: deactivate, activate, or remove' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify actor is admin/manager in this account
    const { data: actorAssoc } = await supabaseAdmin
      .from('user_company_associations')
      .select('role, status')
      .eq('user_id', actor_id)
      .eq('account_id', account_id)
      .eq('status', 'active')
      .maybeSingle()

    if (!actorAssoc) {
      return new Response(
        JSON.stringify({ error: 'You are not an active member of this company' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const actorRole = actorAssoc.role?.toLowerCase()
    if (!['admin', 'manager', 'owner'].includes(actorRole)) {
      return new Response(
        JSON.stringify({ error: 'Insufficient permissions. Only admins and managers can manage users.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get target user's association
    const { data: targetAssoc } = await supabaseAdmin
      .from('user_company_associations')
      .select('id, role, status')
      .eq('user_id', target_user_id)
      .eq('account_id', account_id)
      .maybeSingle()

    if (!targetAssoc) {
      return new Response(
        JSON.stringify({ error: 'Target user is not associated with this company' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Permission guard: admins cannot deactivate/remove other admins
    const targetRole = targetAssoc.role?.toLowerCase()
    if ((action === 'deactivate' || action === 'remove') && targetRole === 'admin') {
      return new Response(
        JSON.stringify({
          error: 'Cannot modify admin users. Only super admins can manage admin accounts.'
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Cannot act on yourself
    if (actor_id === target_user_id) {
      return new Response(
        JSON.stringify({ error: 'You cannot modify your own account status' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let resultMessage = ''

    if (action === 'deactivate') {
      // Verify user is currently active
      if (targetAssoc.status !== 'active') {
        return new Response(
          JSON.stringify({ error: 'User is not currently active' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Update association status
      const { error: updateError } = await supabaseAdmin
        .from('user_company_associations')
        .update({
          status: 'inactive',
          deactivated_at: new Date().toISOString(),
          deactivated_by: actor_id,
        })
        .eq('id', targetAssoc.id)

      if (updateError) throw updateError

      // Unassign from project in users table (if this is their active company)
      await supabaseAdmin
        .from('users')
        .update({
          current_project_id: null,
          status: 'inactive',
        })
        .eq('id', target_user_id)
        .eq('account_id', account_id)

      resultMessage = 'User deactivated successfully'

    } else if (action === 'activate') {
      // Verify user is currently inactive
      if (targetAssoc.status !== 'inactive') {
        return new Response(
          JSON.stringify({ error: 'User is not currently inactive' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Update association status
      const { error: updateError } = await supabaseAdmin
        .from('user_company_associations')
        .update({
          status: 'active',
          deactivated_at: null,
          deactivated_by: null,
        })
        .eq('id', targetAssoc.id)

      if (updateError) throw updateError

      // Re-activate in users table
      await supabaseAdmin
        .from('users')
        .update({
          status: 'active',
        })
        .eq('id', target_user_id)
        .eq('account_id', account_id)

      resultMessage = 'User activated successfully'

    } else if (action === 'remove') {
      // Can remove from active or inactive
      if (targetAssoc.status === 'removed') {
        return new Response(
          JSON.stringify({ error: 'User is already removed from this company' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Update association status to removed
      const { error: updateError } = await supabaseAdmin
        .from('user_company_associations')
        .update({
          status: 'removed',
          removed_at: new Date().toISOString(),
          removed_by: actor_id,
        })
        .eq('id', targetAssoc.id)

      if (updateError) throw updateError

      // Unassign from project (if this is their active company)
      await supabaseAdmin
        .from('users')
        .update({
          current_project_id: null,
          status: 'inactive',
        })
        .eq('id', target_user_id)
        .eq('account_id', account_id)

      // Do NOT delete from auth.users - user may belong to other companies
      // Do NOT delete historical data - voice_notes, action_items remain linked

      resultMessage = 'User removed from company successfully'
    }

    // Insert audit log
    await supabaseAdmin.from('user_management_audit_log').insert({
      actor_id: actor_id,
      target_user_id: target_user_id,
      account_id: account_id,
      action: action,
      details: {
        target_role: targetAssoc.role,
        previous_status: targetAssoc.status,
      },
    })

    return new Response(
      JSON.stringify({ success: true, message: resultMessage }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in manage-user-status:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'An unexpected error occurred' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
