import { createClient } from 'npm:@supabase/supabase-js@2'

export function userClient(req: Request) {
  const authorization = req.headers.get('Authorization')
  if (!authorization) throw new Error('Missing authorization header')
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authorization } } },
  )
}

export function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

export function publicBaseUrl(): string {
  const env = Deno.env.get('SUPABASE_PUBLIC_URL')
  const base = env && env.length > 0 ? env : 'https://supabase.langkatkab.go.id'
  return base.replace(/\/+$/, '')
}

export function toPublicUrl(url: string): string {
  return url.replace(/^https?:\/\/[^/]+/, publicBaseUrl())
}
