import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with service role key for admin operations
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

    // Get request body
    const { email, password, role, account_id } = await req.json()

    // Validate required fields
    if (!email || !password || !role || !account_id) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: email, password, role, account_id' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(email)) {
      return new Response(
        JSON.stringify({ error: 'Invalid email format' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Validate password length
    if (password.length < 6) {
      return new Response(
        JSON.stringify({ error: 'Password must be at least 6 characters' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log(`Creating user: ${email} with role: ${role} for account: ${account_id}`)

    // Step 1: Check if user already exists
    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers()
    const userExists = existingUsers.users.some((u) => u.email === email)

    if (userExists) {
      return new Response(
        JSON.stringify({ 
          error: 'User with this email already exists' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Step 2: Create auth user with metadata
    // The database trigger will automatically create the users table entry
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true, // Auto-confirm email
      user_metadata: {
        role: role,
        account_id: account_id
      }
    })

    if (authError) {
      console.error('Auth creation error:', authError)
      return new Response(
        JSON.stringify({ 
          error: authError.message || 'Failed to create auth user' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    if (!authData.user) {
      throw new Error('User created but no user data returned')
    }

    console.log(`Auth user created: ${authData.user.id}`)

    // Step 3: Wait briefly for database trigger to complete, then verify
    await new Promise(resolve => setTimeout(resolve, 500))

    // Step 4: Check if trigger created the user record
    const { data: userRecord, error: checkError } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('id', authData.user.id)
      .maybeSingle()

    if (checkError) {
      console.error('Error checking user record:', checkError)
    }

    // Step 5: If trigger didn't create user record, create it manually as fallback
    if (!userRecord) {
      console.log('Database trigger did not create user record, creating manually...')
      
      const { data: manualUserData, error: manualUserError } = await supabaseAdmin
        .from('users')
        .insert({
          id: authData.user.id,
          email: email,
          role: role,
          account_id: account_id,
          preferred_language: 'en'
        })
        .select()
        .single()

      if (manualUserError) {
        console.error('Manual user creation error:', manualUserError)
        
        // Rollback: Delete the auth user
        await supabaseAdmin.auth.admin.deleteUser(authData.user.id)
        
        return new Response(
          JSON.stringify({ 
            error: `Failed to create user record: ${manualUserError.message}` 
          }),
          { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      console.log('User record created manually')
    } else {
      console.log('User record created by database trigger')
    }

    // Step 6: Fetch final user data
    const { data: finalUserData } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('id', authData.user.id)
      .single()

    return new Response(
      JSON.stringify({ 
        success: true,
        user: {
          id: finalUserData.id,
          email: finalUserData.email,
          role: finalUserData.role,
          account_id: finalUserData.account_id
        },
        message: 'User invited successfully'
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message || 'An unexpected error occurred' 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})