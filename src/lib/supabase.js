import { createClient } from '@supabase/supabase-js'
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public'

// PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY are safe to expose —
// Supabase anon keys are intentionally public and secured by Row Level Security.
export const supabase = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY)