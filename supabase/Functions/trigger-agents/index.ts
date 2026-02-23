// Supabase Edge Function: trigger-agents
// Webhook listener that calls the sitevoice-agents service
// when a voice note completes

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const AGENT_WEBHOOK_URL = Deno.env.get('AGENT_WEBHOOK_URL') || 'https://your-deployment.vercel.app/api/webhooks/voice-note-completed';
const AGENT_WEBHOOK_SECRET = Deno.env.get('AGENT_WEBHOOK_SECRET') || '';

serve(async (req) => {
  try {
    // Parse webhook payload from Supabase
    const payload = await req.json();

    console.log('Received webhook:', payload);

    // Extract voice note ID from different payload formats
    const voiceNoteId = payload.record?.id || payload.voice_note_id;

    if (!voiceNoteId) {
      return new Response(
        JSON.stringify({ error: 'Missing voice_note_id' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Only process if status is 'completed'
    const status = payload.record?.status || payload.status;
    if (status !== 'completed') {
      console.log('Skipping - status is not completed:', status);
      return new Response(
        JSON.stringify({ skipped: true, reason: 'status not completed' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Call the agents webhook
    console.log('Calling agents webhook for voice_note_id:', voiceNoteId);

    const response = await fetch(AGENT_WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AGENT_WEBHOOK_SECRET}`,
      },
      body: JSON.stringify({
        voice_note_id: voiceNoteId,
        timestamp: new Date().toISOString(),
      }),
    });

    const result = await response.json();
    console.log('Agents webhook response:', result);

    return new Response(
      JSON.stringify({ success: true, agentResponse: result }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error triggering agents:', error);
    return new Response(
      JSON.stringify({
        error: 'Failed to trigger agents',
        message: error instanceof Error ? error.message : String(error)
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
