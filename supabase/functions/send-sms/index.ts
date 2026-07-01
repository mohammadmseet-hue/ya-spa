// supabase/functions/send-sms/index.ts
// Supabase "Send SMS Hook" -> Authentica (Saudi) plain send-SMS endpoint.
//
// Deploy: supabase functions deploy send-sms --no-verify-jwt
//   (--no-verify-jwt is REQUIRED: Supabase Auth calls this hook WITHOUT a Supabase JWT;
//    authenticity is proven by the standard-webhooks signature, not a bearer token.)
//
// Set these secrets (Dashboard > Edge Functions > send-sms > Secrets, or `supabase secrets set`):
//   SEND_SMS_HOOK_SECRET   -> the "v1,whsec_..." value Supabase generated when you enabled the hook
//   SMS_PROVIDER_API_KEY   -> your Authentica API key  (sent as the X-Authorization header)
//   SMS_PROVIDER_ENDPOINT  -> https://api.authentica.sa/api/v2/send-sms
//   SMS_PROVIDER_SENDER_ID -> your approved Authentica Sender ID (e.g. the spa's short name)
//
// IMPORTANT: Supabase GENERATES and VERIFIES the OTP. We only DELIVER it.
// Always call the plain /send-sms endpoint here, never /send-otp or a verify API.
// (Confirm the exact endpoint/body against your provider's live API docs when you get the key —
//  the message-delivery structure below is what changes per provider; everything else stays.)

import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0'

// ---- Provider configuration -----------------------------------------------------------------
const SMS_PROVIDER_ENDPOINT = Deno.env.get('SMS_PROVIDER_ENDPOINT')! // https://api.authentica.sa/api/v2/send-sms
const SMS_PROVIDER_API_KEY  = Deno.env.get('SMS_PROVIDER_API_KEY')!  // Authentica API key
const SMS_PROVIDER_SENDER   = Deno.env.get('SMS_PROVIDER_SENDER_ID')! // Authentica Sender ID
// ---------------------------------------------------------------------------------------------

interface SendSmsPayload {
  user: {
    id: string
    phone: string          // E.164, e.g. "+9665XXXXXXXX"  <-- the recipient (ALWAYS use user.phone)
    [key: string]: unknown
  }
  sms: {
    otp: string            // the 6-digit code Supabase generated, e.g. "561166"
  }
}

// Authentica send-SMS call. Contract: POST /api/v2/send-sms
//   headers: X-Authorization: <API key>
//   body:    { sender, phone, message }
async function sendViaAuthentica(toPhone: string, message: string): Promise<void> {
  const res = await fetch(SMS_PROVIDER_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Authentica authenticates with the X-Authorization header (NOT a bearer token):
      'X-Authorization': SMS_PROVIDER_API_KEY,
    },
    body: JSON.stringify({
      sender: SMS_PROVIDER_SENDER, // your approved CITC Sender ID
      phone: toPhone,              // recipient in E.164 (from user.phone)
      message: message,            // the SMS body containing the OTP
    }),
  })

  if (!res.ok) {
    const detail = await res.text().catch(() => '')
    throw new Error(`Authentica returned ${res.status}: ${detail}`)
  }

  // ----------------------------------------------------------------------------------------
  // TO USE TAQNYAT INSTEAD (production upgrade, zero app changes): set
  //   SMS_PROVIDER_ENDPOINT = https://api.taqnyat.sa/v1/messages
  //   SMS_PROVIDER_API_KEY  = your Taqnyat token
  // and replace the fetch above with:
  //   headers: { 'Content-Type': 'application/json',
  //              'Authorization': `Bearer ${SMS_PROVIDER_API_KEY}` }
  //   body:    JSON.stringify({ recipients: [toPhone], body: message, sender: SMS_PROVIDER_SENDER })
  // Taqnyat expects `recipients` (array), `body`, `sender` and a Bearer token.
  // ----------------------------------------------------------------------------------------
}

Deno.serve(async (req) => {
  // 1) Read the RAW body. The signature is computed over exact bytes, so never JSON.parse first.
  const payload = await req.text()

  // 2) Load and normalize the hook secret. Supabase stores it as "v1,whsec_<base64>";
  //    the standardwebhooks library wants only the base64 portion.
  const rawSecret = Deno.env.get('SEND_SMS_HOOK_SECRET')
  if (!rawSecret) {
    return new Response(
      JSON.stringify({ error: { http_code: 500, message: 'Hook secret not configured' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
  const base64Secret = rawSecret.replace('v1,whsec_', '')

  // 3) VERIFY the request is genuinely from Supabase (standard-webhooks headers). Throws on bad sig.
  const wh = new Webhook(base64Secret)
  let data: SendSmsPayload
  try {
    data = wh.verify(payload, Object.fromEntries(req.headers)) as SendSmsPayload
  } catch (_err) {
    return new Response(
      JSON.stringify({ error: { http_code: 401, message: 'Invalid webhook signature' } }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // 4) Extract recipient (user.phone) and the code (sms.otp). Compose your own message body.
  const phone = data.user.phone
  const otp = data.sms.otp
  const messageBody = `رمز التحقق الخاص بك في يا سبا: ${otp}\nYour Ya Spa verification code is: ${otp}`

  // 5) Deliver via Authentica. On failure, return the standard error shape so Supabase surfaces it.
  try {
    await sendViaAuthentica(phone, messageBody)
  } catch (error) {
    // Use 429/503 to make Supabase retry (up to 3x); use 500 for a hard failure.
    return new Response(
      JSON.stringify({
        error: {
          http_code: 500,
          message: `Failed to send SMS: ${error instanceof Error ? error.message : String(error)}`,
        },
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // 6) SUCCESS: empty JSON body + 200.
  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
