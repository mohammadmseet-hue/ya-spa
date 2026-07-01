# Ya Spa — Phone OTP via a Saudi SMS provider (Supabase Send SMS Hook)

**Why this exists:** Twilio can't register a CITC Sender ID for Saudi (+966) traffic, which is
why it failed. A Saudi provider (Authentica to start, Taqnyat for scale) registers your CITC
Sender ID **using your Commercial Registration (CR)** — the exact step Twilio couldn't do.

Supabase still generates and verifies the 6-digit code exactly as before. This function only
changes the **delivery pipe**: Supabase's "Send SMS Hook" calls this function, which hands the
code to the Saudi provider. **No app changes** — the phone-login + OTP screens stay identical.

## One-time setup

1. **Sign up with Authentica** (`authentica.sa`). 100 free credits, no upfront paperwork to test.
   To go live on a branded +966 sender, give them your **CR + bank details** → they register your
   CITC Sender ID. Copy your **API key** and your approved **Sender ID**.

2. **Enable the hook in Supabase** → Authentication → Providers → enable **Phone**. Then
   Authentication → Hooks → **Send SMS** → type **HTTP**. Enabling it generates a **Hook Secret**
   like `v1,whsec_...` — copy the whole string.

3. **Set the 4 secrets** (Edge Functions → send-sms → Secrets, or `supabase secrets set`):
   ```
   SEND_SMS_HOOK_SECRET   = v1,whsec_...            # from step 2
   SMS_PROVIDER_API_KEY    = <your Authentica API key>
   SMS_PROVIDER_ENDPOINT   = https://api.authentica.sa/api/v2/send-sms
   SMS_PROVIDER_SENDER_ID  = <your approved Sender ID>
   ```

4. **Deploy** (from repo root):
   ```
   supabase functions deploy send-sms --no-verify-jwt
   ```
   `--no-verify-jwt` is required — Supabase Auth calls the hook without a Supabase JWT; the
   webhook signature proves authenticity. Copy the deployed function URL.

5. **Point the hook at it** → Authentication → Hooks → Send SMS → paste the function URL → save.

6. **Test** with a real +9665… number from the app's phone screen. Confirm the SMS arrives, the
   code logs you in, and `auth.users.phone` is set.

7. **Flip `Config.requireAuth = true`** in the app (`YaSpa/Sources/Config.swift`) and ship. RLS +
   cloud bookings already sit behind Supabase auth, so nothing else changes.

## Upgrading to Taqnyat later (production, zero app changes)

Sign up at `taqnyat.sa`, register your sender via your CR, then update secrets:
```
SMS_PROVIDER_ENDPOINT  = https://api.taqnyat.sa/v1/messages
SMS_PROVIDER_API_KEY    = <your Taqnyat token>
SMS_PROVIDER_SENDER_ID  = <your Taqnyat sender>
```
and switch the fetch in `index.ts` to Taqnyat's schema (`Authorization: Bearer` header;
body `{ recipients: [phone], body: message, sender }`) — see the comment block in the code.

> Confirm the provider's exact endpoint/body against their live API docs when you get the key.
> Everything else (the hook verification, payload parsing, message body) stays the same.
