// supabase/functions/notify-owner/index.ts
// Fires on every NEW booking and notifies the owner with the full order:
// service · massage type · duration · date/time · customer name+phone · a
// tap-to-open Google Maps pin · price · payment method.
//
// Wiring (see supabase/DEPLOY.md):
//   Database Webhook  →  table public.bookings  →  event INSERT  →  this function,
//   with an HTTP header  x-notify-secret: <NOTIFY_SECRET>.
//
// Deploy:  supabase functions deploy notify-owner --no-verify-jwt
// Secrets (supabase secrets set ...):
//   NOTIFY_SECRET            shared secret you also put in the Database Webhook header
//   SUPABASE_URL             (auto-provided) — used to look up the customer's phone
//   SUPABASE_SERVICE_ROLE_KEY(auto-provided) — service-role read of profiles
//   TELEGRAM_BOT_TOKEN       (optional) owner Telegram bot token
//   TELEGRAM_CHAT_ID         (optional) owner Telegram chat id
//   OWNER_WEBHOOK_URL        (optional) any generic webhook (WhatsApp Cloud API, Slack, n8n…)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SERVICE_LABEL: Record<string, string> = {
  swedish: 'Swedish Massage', deep: 'Deep Tissue', stone: 'Hot Stone',
  thai: 'Thai Massage', aroma: 'Aromatherapy', foot: 'Foot Reflexology',
}

function mapsLink(b: any): string {
  if (b.lat != null && b.lng != null) return `https://maps.google.com/?q=${b.lat},${b.lng}`
  const q = [b.address_line, b.building && `Bldg ${b.building}`, b.apartment && `Apt ${b.apartment}`,
             b.district, b.city].filter(Boolean).join(', ')
  return `https://maps.google.com/?q=${encodeURIComponent(q)}`
}

Deno.serve(async (req) => {
  // 1) authenticate the caller (the Database Webhook) via shared secret
  const secret = Deno.env.get('NOTIFY_SECRET')
  if (!secret || req.headers.get('x-notify-secret') !== secret) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 })
  }

  // 2) the webhook payload: { type: 'INSERT', table, record, ... }
  const body = await req.json().catch(() => null)
  const b = body?.record
  if (!b || body?.type !== 'INSERT') return new Response(JSON.stringify({ skipped: true }), { status: 200 })

  // 3) contact captured at booking time; fall back to the profile if absent.
  let phone = b.contact_phone ?? '', name = b.customer_name ?? ''
  if (!phone || !name) {
    try {
      const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
      const { data } = await admin.from('profiles').select('phone, full_name').eq('id', b.user_id).single()
      phone = phone || (data?.phone ?? ''); name = name || (data?.full_name ?? '')
    } catch (_) { /* non-fatal */ }
  }

  const svc = SERVICE_LABEL[b.service_id] ?? b.service_name_en ?? b.service_id
  const when = `${b.booking_date} · ${b.booking_time}`
  const addr = [b.address_line, b.building && `Bldg ${b.building}`, b.apartment && `Apt ${b.apartment}`,
                b.district, b.city].filter(Boolean).join(', ')
  const lines = [
    '🌸 New Ya Spa booking',
    `• Service: ${svc} (${b.duration_min} min)`,
    `• Therapist: ${b.therapist_name ?? '—'}`,
    `• When: ${when}`,
    `• Customer: ${name || '—'}  ${phone}`,
    `• Address: ${addr || '—'}`,
    `• Map: ${mapsLink(b)}`,
    `• Total: SAR ${b.total}  ·  ${b.payment_method}`,
    b.notes ? `• Notes: ${b.notes}` : '',
  ].filter(Boolean)
  const text = lines.join('\n')

  // 4) fan out to whatever channels are configured
  const sends: Promise<unknown>[] = []
  const tgToken = Deno.env.get('TELEGRAM_BOT_TOKEN'), tgChat = Deno.env.get('TELEGRAM_CHAT_ID')
  if (tgToken && tgChat) {
    sends.push(fetch(`https://api.telegram.org/bot${tgToken}/sendMessage`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: tgChat, text, disable_web_page_preview: false }),
    }))
  }
  const hook = Deno.env.get('OWNER_WEBHOOK_URL')
  if (hook) {
    sends.push(fetch(hook, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, booking: b, phone, name, map: mapsLink(b) }),
    }))
  }
  const results = await Promise.allSettled(sends)
  const delivered = results.filter(r => r.status === 'fulfilled').length

  return new Response(JSON.stringify({ ok: true, channels: sends.length, delivered }),
    { status: 200, headers: { 'Content-Type': 'application/json' } })
})
