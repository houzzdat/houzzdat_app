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
    const { company_name, admin_email, admin_password } = await req.json()
    
    // Initialize Supabase with Service Role Key to bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Create the Account (Company) entry
    const { data: account, error: accError } = await supabaseAdmin
      .from('accounts')
      .insert({ company_name })
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
      role: 'admin',
      account_id: account.id
    })
    if (userLinkError) throw userLinkError

    return new Response(JSON.stringify({ message: "Onboarding Successful" }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200 
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400 
    })
  }
})