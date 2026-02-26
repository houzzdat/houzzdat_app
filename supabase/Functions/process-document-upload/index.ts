import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { document_id } = await req.json()

    if (!document_id) {
      return new Response(
        JSON.stringify({ error: 'document_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Fetch the document with project info
    const { data: doc, error: docError } = await supabase
      .from('documents')
      .select(`
        id, name, category, version_number, requires_owner_approval,
        approval_status, project_id, account_id, uploaded_by,
        projects ( name )
      `)
      .eq('id', document_id)
      .single()

    if (docError || !doc) {
      throw new Error(`Document not found: ${docError?.message}`)
    }

    // Log the upload action in document_access_log
    await supabase
      .from('document_access_log')
      .insert({
        document_id: doc.id,
        user_id: doc.uploaded_by,
        action: 'upload',
        metadata: {
          version_number: doc.version_number,
          category: doc.category,
          requires_owner_approval: doc.requires_owner_approval,
        },
      })

    // If requires owner approval, notify all owner-role users in the account
    if (doc.requires_owner_approval) {
      // Find all users with 'owner' role in this account
      const { data: ownerMembers } = await supabase
        .from('user_company_associations')
        .select('user_id')
        .eq('account_id', doc.account_id)
        .eq('role', 'owner')
        .eq('status', 'active')

      if (ownerMembers && ownerMembers.length > 0) {
        const projectName = (doc.projects as any)?.name || 'Unknown Project'
        const versionLabel = doc.version_number > 1 ? ` (v${doc.version_number})` : ''
        const categoryLabel = doc.category.replace(/_/g, ' ')

        const notifications = ownerMembers.map((member: { user_id: string }) => ({
          user_id: member.user_id,
          account_id: doc.account_id,
          type: 'document_pending_approval',
          title: 'Document Awaiting Approval',
          message: `"${doc.name}${versionLabel}" (${categoryLabel}) has been uploaded for ${projectName} and requires your approval.`,
          metadata: {
            document_id: doc.id,
            project_id: doc.project_id,
            document_name: doc.name,
            category: doc.category,
            version_number: doc.version_number,
          },
          is_read: false,
        }))

        const { error: notifError } = await supabase
          .from('notifications')
          .insert(notifications)

        if (notifError) {
          console.error('Failed to create owner notifications:', notifError)
        } else {
          console.log(`Notified ${ownerMembers.length} owner(s) for document ${document_id}`)
        }
      }
    }

    // Check if this is a new version of an existing document — notify the original uploader
    if (doc.version_number > 1 && doc.uploaded_by) {
      // Find the original document uploader (version 1) to notify them
      const { data: originalDoc } = await supabase
        .from('documents')
        .select('uploaded_by')
        .eq('project_id', doc.project_id)
        .eq('name', doc.name)
        .eq('version_number', 1)
        .single()

      const originalUploader = originalDoc?.uploaded_by
      // Notify the original uploader if different from current uploader
      if (originalUploader && originalUploader !== doc.uploaded_by) {
        await supabase
          .from('notifications')
          .insert({
            user_id: originalUploader,
            account_id: doc.account_id,
            type: 'document_versioned',
            title: 'Document Updated',
            message: `A new version (v${doc.version_number}) of "${doc.name}" has been uploaded.`,
            metadata: {
              document_id: doc.id,
              project_id: doc.project_id,
              document_name: doc.name,
              version_number: doc.version_number,
            },
            is_read: false,
          })
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        document_id: doc.id,
        owner_notifications_sent: doc.requires_owner_approval,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )

  } catch (error) {
    console.error('process-document-upload error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
