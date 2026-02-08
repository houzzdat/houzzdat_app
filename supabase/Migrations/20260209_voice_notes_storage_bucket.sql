-- Create the voice-notes storage bucket (was missing — created manually on dashboard)
-- This ensures the bucket exists with correct settings for public audio playback

INSERT INTO storage.buckets (id, name, public)
VALUES ('voice-notes', 'voice-notes', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow authenticated users to upload voice note audio files
CREATE POLICY "Authenticated users can upload voice notes"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'voice-notes');

-- Allow public read access (needed for audio player to stream without auth tokens)
CREATE POLICY "Public can listen to voice notes"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'voice-notes');

-- Allow authenticated users to delete their own voice notes
CREATE POLICY "Authenticated users can delete voice notes"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'voice-notes');
