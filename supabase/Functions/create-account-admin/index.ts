import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  // Handle CORS preflight requests for Flutter/Web
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { company_name, admin_email, admin_password, transcription_provider, admin_name, admin_languages } = await req.json()

    // Normalize languages: default to ['en'] if not provided
    const preferredLanguages: string[] = Array.isArray(admin_languages) && admin_languages.length > 0
      ? admin_languages
      : ['en']
    const preferredLanguage = preferredLanguages[0] || 'en'

    // Initialize Supabase with Service Role Key to bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Create the Account (Company) entry with status
    const { data: account, error: accError } = await supabaseAdmin
      .from('accounts')
      .insert({
        company_name,
        status: 'active',
        transcription_provider: transcription_provider || 'groq',
      })
      .select().single()
    if (accError) throw accError

    // 2. Create the Auth Identity (Email/Password)
    const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: admin_email,
      password: admin_password,
      email_confirm: true
    })
    if (authError) throw authError

    // 3. Link the user to the company in public.users
    const { error: userLinkError } = await supabaseAdmin.from('users').insert({
      id: authUser.user.id,
      email: admin_email,
      full_name: admin_name || null,
      role: 'admin',
      account_id: account.id,
      status: 'active',
      preferred_language: preferredLanguage,
      preferred_languages: preferredLanguages,
    })
    if (userLinkError) throw userLinkError

    // 4. Create user_company_association for multi-company support
    const { error: assocError } = await supabaseAdmin
      .from('user_company_associations')
      .insert({
        user_id: authUser.user.id,
        account_id: account.id,
        role: 'admin',
        status: 'active',
        is_primary: true,
      })
    if (assocError) {
      console.error('Warning: Failed to create association:', assocError)
      // Non-fatal - backward compat still works via users table
    }

    // 5. Audit log entry
    await supabaseAdmin.from('user_management_audit_log').insert({
      actor_id: authUser.user.id,
      target_user_id: authUser.user.id,
      account_id: account.id,
      action: 'invite',
      details: {
        role: 'admin',
        email: admin_email,
        company_name: company_name,
        is_company_creation: true,
      },
    })

    return new Response(JSON.stringify({ message: "Onboarding Successful" }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400
    })
  }
})
