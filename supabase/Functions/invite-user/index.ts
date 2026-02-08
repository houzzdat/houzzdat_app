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

    // Get request body - password is now optional for existing users
    const { email, password, role, account_id, full_name, preferred_languages } = await req.json()

    // Normalize languages: default to ['en'] if not provided
    const userLanguages: string[] = Array.isArray(preferred_languages) && preferred_languages.length > 0
      ? preferred_languages
      : ['en']
    const primaryLanguage = userLanguages[0] || 'en'

    // Validate required fields (password no longer always required)
    if (!email || !role || !account_id) {
      return new Response(
        JSON.stringify({
          error: 'Missing required fields: email, role, account_id'
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

    console.log(`Inviting user: ${email} with role: ${role} for account: ${account_id}`)

    // Step 1: Check if an association already exists for this user+account
    const { data: existingAssociation } = await supabaseAdmin
      .from('user_company_associations')
      .select('*')
      .eq('account_id', account_id)
      .ilike('role', role) // Use role as a proxy; we need user_id which we don't have yet
      // We'll check by finding the user first

    // Step 2: Check if user already exists in auth
    const { data: { users: authUsers } } = await supabaseAdmin.auth.admin.listUsers()
    const existingAuthUser = authUsers.find((u: any) => u.email === email)

    if (existingAuthUser) {
      // User exists in auth system
      const existingUserId = existingAuthUser.id

      // Check if they already have an association with this account
      const { data: assoc } = await supabaseAdmin
        .from('user_company_associations')
        .select('*')
        .eq('user_id', existingUserId)
        .eq('account_id', account_id)
        .maybeSingle()

      if (assoc) {
        if (assoc.status === 'active') {
          // Already active in this company
          return new Response(
            JSON.stringify({
              error: 'This user is already an active member of this company'
            }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }

        if (assoc.status === 'removed' || assoc.status === 'inactive') {
          // Re-activate the association
          const { error: reactivateError } = await supabaseAdmin
            .from('user_company_associations')
            .update({
              status: 'active',
              role: role,
              deactivated_at: null,
              deactivated_by: null,
              removed_at: null,
              removed_by: null,
            })
            .eq('id', assoc.id)

          if (reactivateError) {
            console.error('Error reactivating association:', reactivateError)
            return new Response(
              JSON.stringify({ error: `Failed to reactivate user: ${reactivateError.message}` }),
              {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
              }
            )
          }

          // Update the users table to reflect active company context
          await supabaseAdmin
            .from('users')
            .update({
              account_id: account_id,
              role: role,
              status: 'active'
            })
            .eq('id', existingUserId)

          // Audit log
          await supabaseAdmin.from('user_management_audit_log').insert({
            actor_id: existingUserId, // Will be overridden by caller context
            target_user_id: existingUserId,
            account_id: account_id,
            action: 'reactivate_association',
            details: { role, email, reactivated_from: assoc.status },
          })

          return new Response(
            JSON.stringify({
              success: true,
              user: {
                id: existingUserId,
                email: email,
                role: role,
                account_id: account_id,
              },
              message: 'User re-activated in this company',
              is_existing_user: true,
            }),
            {
              status: 200,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }
      }

      // User exists in auth but has no association with this account
      // Create a new association (no need to create auth user)
      console.log(`Existing auth user ${existingUserId} - adding to company ${account_id}`)

      // Check if user has a public.users row
      const { data: existingPublicUser } = await supabaseAdmin
        .from('users')
        .select('id')
        .eq('id', existingUserId)
        .maybeSingle()

      if (!existingPublicUser) {
        // Create public.users row for this user (first time in system)
        const { error: createUserError } = await supabaseAdmin
          .from('users')
          .insert({
            id: existingUserId,
            email: email,
            role: role,
            account_id: account_id,
            full_name: full_name || null,
            preferred_language: primaryLanguage,
            preferred_languages: userLanguages,
            status: 'active',
          })

        if (createUserError) {
          console.error('Error creating public user record:', createUserError)
          return new Response(
            JSON.stringify({ error: `Failed to create user record: ${createUserError.message}` }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }
      }

      // Create the association
      const { error: assocError } = await supabaseAdmin
        .from('user_company_associations')
        .insert({
          user_id: existingUserId,
          account_id: account_id,
          role: role,
          status: 'active',
          is_primary: false, // Not primary since they already have another company
        })

      if (assocError) {
        console.error('Error creating association:', assocError)
        return new Response(
          JSON.stringify({ error: `Failed to add user to company: ${assocError.message}` }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // Audit log
      await supabaseAdmin.from('user_management_audit_log').insert({
        actor_id: existingUserId,
        target_user_id: existingUserId,
        account_id: account_id,
        action: 'invite',
        details: { role, email, is_existing_user: true },
      })

      return new Response(
        JSON.stringify({
          success: true,
          user: {
            id: existingUserId,
            email: email,
            role: role,
            account_id: account_id,
          },
          message: 'Existing user added to company successfully',
          is_existing_user: true,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Step 3: User does NOT exist in auth - create new user
    // Password is required for new users
    if (!password) {
      return new Response(
        JSON.stringify({
          error: 'Password is required for new users'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (password.length < 6) {
      return new Response(
        JSON.stringify({ error: 'Password must be at least 6 characters' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Create auth user with metadata
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true,
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

    // Wait for database trigger
    await new Promise(resolve => setTimeout(resolve, 500))

    // Check if trigger created the user record
    const { data: userRecord, error: checkError } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('id', authData.user.id)
      .maybeSingle()

    if (checkError) {
      console.error('Error checking user record:', checkError)
    }

    // If trigger didn't create user record, create manually
    if (!userRecord) {
      console.log('Database trigger did not create user record, creating manually...')

      const { error: manualUserError } = await supabaseAdmin
        .from('users')
        .insert({
          id: authData.user.id,
          email: email,
          role: role,
          account_id: account_id,
          full_name: full_name || null,
          preferred_language: primaryLanguage,
          preferred_languages: userLanguages,
          status: 'active',
        })

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
      // Update the existing trigger-created record with our fields
      await supabaseAdmin
        .from('users')
        .update({
          status: 'active',
          full_name: full_name || userRecord.full_name || null,
          preferred_language: primaryLanguage,
          preferred_languages: userLanguages,
        })
        .eq('id', authData.user.id)

      console.log('User record created by database trigger, updated with status')
    }

    // Create the user_company_association
    const { error: assocCreateError } = await supabaseAdmin
      .from('user_company_associations')
      .insert({
        user_id: authData.user.id,
        account_id: account_id,
        role: role,
        status: 'active',
        is_primary: true, // First company is primary
      })

    if (assocCreateError) {
      console.error('Error creating association:', assocCreateError)
      // Non-fatal - the user is still created, association can be added later
    }

    // Audit log
    await supabaseAdmin.from('user_management_audit_log').insert({
      actor_id: authData.user.id,
      target_user_id: authData.user.id,
      account_id: account_id,
      action: 'invite',
      details: { role, email, is_existing_user: false },
    })

    // Fetch final user data
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
        message: 'User invited successfully',
        is_existing_user: false,
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
