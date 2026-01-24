import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0" 

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { email, password, role, account_id } = await req.json()
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' 
    )

    let authUser: any = null;

    try {
      // Check if user already exists
      console.log('Checking if user exists:', email)
      const { data: users, error: listError } = await supabaseAdmin.auth.admin.listUsers()
      if (listError) {
        console.error('List users error:', listError)
        throw listError
      }
      const existingUser = users.users.find((u: any) => u.email === email)
      if (existingUser) {
        console.log('User already exists:', existingUser.id)
        throw new Error('User already exists')
      }

      // 1. Create the Auth Identity with user_metadata
      // Metadata allows the Database Trigger to automatically sync the user profile.
      console.log('Creating auth user for:', email)
      const { data, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { 
          role: role, 
          account_id: account_id 
        }
      })
      
      if (authError) {
        console.error('Auth error:', authError)
        throw authError
      }
      
      authUser = data
      console.log('Auth user created:', authUser.user.id)

      // 2. Manual Link Fallback
      console.log('Linking to public.users table...')
      const { error: userLinkError } = await supabaseAdmin.from('users').insert({
        id: authUser.user.id,
        role: role, 
        account_id: account_id
      })

      if (userLinkError) {
        // Ignore if the database trigger already created the record (Code 23505)
        if (userLinkError.code !== '23505') { 
          console.error('Insert error:', userLinkError)
          throw userLinkError
        }
        console.log('Sync handled by database trigger.')
      } else {
        console.log('Sync handled by Edge Function manual insert.')
      }

      return new Response(JSON.stringify({ message: "User Invited Successfully" }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      })

    } catch (innerError) {
      console.error('Onboarding failure:', innerError)
      // ROLLBACK: Delete Auth user if table linking fails to prevent ghost accounts
      if (authUser) {
        console.log('Rolling back: Deleting auth user', authUser.user.id)
        await supabaseAdmin.auth.admin.deleteUser(authUser.user.id)
      }
      throw innerError
    }
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400 
    })
  }
})