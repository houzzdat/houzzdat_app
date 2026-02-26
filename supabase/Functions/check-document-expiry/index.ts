import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Expiry warning windows in days
const WARNING_WINDOWS = [30, 14, 7] as const

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    // Find all documents expiring within 30 days that haven't been notified yet.
    // Uses the outermost window (30 days) — we filter into buckets below.
    const thirtyDaysOut = new Date(today)
    thirtyDaysOut.setDate(thirtyDaysOut.getDate() + 30)

    const { data: expiringDocs, error: queryError } = await supabase
      .from('documents')
      .select(`
        id, name, category, expires_at, expiry_notified,
        project_id, account_id,
        projects ( name ),
        users!uploaded_by ( id )
      `)
      .not('expires_at', 'is', null)
      .eq('expiry_notified', false)
      .lte('expires_at', thirtyDaysOut.toISOString().split('T')[0])
      .neq('approval_status', 'rejected')

    if (queryError) {
      throw new Error(`Failed to query expiring documents: ${queryError.message}`)
    }

    if (!expiringDocs || expiringDocs.length === 0) {
      return new Response(
        JSON.stringify({ success: true, processed: 0, message: 'No expiring documents found' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    let notificationsCreated = 0
    let documentsMarked = 0

    for (const doc of expiringDocs) {
      const expiryDate = new Date(doc.expires_at)
      expiryDate.setHours(0, 0, 0, 0)

      const msPerDay = 1000 * 60 * 60 * 24
      const daysUntilExpiry = Math.round((expiryDate.getTime() - today.getTime()) / msPerDay)

      // Determine urgency label
      let urgencyLabel: string
      let notificationType: string
      if (daysUntilExpiry <= 0) {
        urgencyLabel = 'has expired'
        notificationType = 'document_expired'
      } else if (daysUntilExpiry <= 7) {
        urgencyLabel = `expires in ${daysUntilExpiry} day${daysUntilExpiry === 1 ? '' : 's'}`
        notificationType = 'document_expiring'
      } else if (daysUntilExpiry <= 14) {
        urgencyLabel = `expires in ${daysUntilExpiry} days`
        notificationType = 'document_expiring'
      } else {
        urgencyLabel = `expires in ${daysUntilExpiry} days`
        notificationType = 'document_expiring'
      }

      const projectName = (doc.projects as any)?.name || 'Unknown Project'
      const categoryLabel = doc.category.replace(/_/g, ' ')

      // Find managers and admins in the account to notify
      const { data: managers } = await supabase
        .from('user_company_associations')
        .select('user_id')
        .eq('account_id', doc.account_id)
        .in('role', ['admin', 'manager'])
        .eq('status', 'active')

      if (managers && managers.length > 0) {
        const notifications = managers.map((m: { user_id: string }) => ({
          user_id: m.user_id,
          account_id: doc.account_id,
          type: notificationType,
          title: daysUntilExpiry <= 0 ? 'Document Expired' : 'Document Expiring Soon',
          message: `"${doc.name}" (${categoryLabel}) for ${projectName} ${urgencyLabel}. Please renew or replace this document.`,
          metadata: {
            document_id: doc.id,
            project_id: doc.project_id,
            document_name: doc.name,
            category: doc.category,
            expires_at: doc.expires_at,
            days_until_expiry: daysUntilExpiry,
          },
          is_read: false,
        }))

        const { error: notifError } = await supabase
          .from('notifications')
          .insert(notifications)

        if (notifError) {
          console.error(`Failed to create notifications for document ${doc.id}:`, notifError)
          continue
        }

        notificationsCreated += notifications.length
      }

      // Mark as notified so we don't send duplicate notifications
      const { error: markError } = await supabase
        .from('documents')
        .update({ expiry_notified: true })
        .eq('id', doc.id)

      if (markError) {
        console.error(`Failed to mark document ${doc.id} as notified:`, markError)
      } else {
        documentsMarked++
      }
    }

    console.log(`check-document-expiry: processed ${expiringDocs.length} docs, created ${notificationsCreated} notifications, marked ${documentsMarked} as notified`)

    return new Response(
      JSON.stringify({
        success: true,
        processed: expiringDocs.length,
        notifications_created: notificationsCreated,
        documents_marked: documentsMarked,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )

  } catch (error) {
    console.error('check-document-expiry error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
