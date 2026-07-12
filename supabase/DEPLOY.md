# Ya Spa — going live (real backend)

The app is wired to Supabase. The old project (`plzdjimvrvuhxnenrdgt`) is dead, so
provision a fresh one and deploy this schema. The backend is verified by
`supabase/test/run.sh` (13/13 on real Postgres).

## 0. Prerequisites
- A Supabase account + the `supabase` CLI (`brew install supabase/tap/supabase`).
- An Authentica (or Taqnyat) account for Saudi SMS OTP.
- (Later) a Moyasar merchant account for online card/Apple Pay/mada.

## 1. Create the project
```
supabase projects create ya-spa --region <closest-region>   # see PDPL note below
supabase link --project-ref <NEW_REF>
```

## 2. Push the schema (0001 + 0002)
```
supabase db push          # applies supabase/migrations in order
```
Verify locally first (optional, needs Docker):
```
bash supabase/test/run.sh   # expect: PASS=13  FAIL=0
```

## 3. Auth
- **Anonymous sign-ins: ON** (the app creates an identity on launch so bookings persist).
- **Phone auth: ON**, provider = *Send SMS Hook* → deploy the OTP delivery function:
  ```
  supabase functions deploy send-sms --no-verify-jwt
  supabase secrets set SEND_SMS_HOOK_SECRET='v1,whsec_...' \
    SMS_PROVIDER_API_KEY='<authentica key>' \
    SMS_PROVIDER_ENDPOINT='https://api.authentica.sa/api/v2/send-sms' \
    SMS_PROVIDER_SENDER_ID='<approved sender>'
  ```
  Then in Auth → Hooks, point *Send SMS* at the `send-sms` function.
- When OTP works, set `Config.requireAuth = true` in the iOS app.

## 4. Owner notifications (you receive every order)
```
supabase functions deploy notify-owner --no-verify-jwt
supabase secrets set NOTIFY_SECRET='<random-long-string>' \
  TELEGRAM_BOT_TOKEN='<from @BotFather>' TELEGRAM_CHAT_ID='<your chat id>'
# optional instead/also: OWNER_WEBHOOK_URL='<WhatsApp Cloud API / Slack / n8n>'
```
Then create a **Database Webhook** (Database → Webhooks):
- Table `public.bookings`, event **INSERT**
- URL = the `notify-owner` function URL
- HTTP header `x-notify-secret: <same NOTIFY_SECRET>`

Now every booking DMs you: service · type · duration · date/time · customer
name+phone · a Google Maps pin · total · payment method.

## 5. Make yourself the owner (admin console)
After you sign in once on your own device, find your `auth.uid()` and:
```sql
insert into public.admins (user_id, label) values ('<your-uid>', 'owner');
```
The in-app **Owner** tab (Realtime) then shows all incoming orders live, with
accept → on-the-way → completed → cancel, tap-to-call, and tap-to-navigate.

## 6. Point the app at the new project
In `YaSpa/Sources/Config.swift`:
```swift
static let supabaseURL     = "https://<NEW_REF>.supabase.co"
static let supabaseAnonKey = "sb_publishable_..."   // Project Settings → API (publishable/anon)
```
Realtime is already enabled for `bookings` by migration 0002.

## 7. Payments (when ready)
Deploy the Cloudflare Worker (`app/checkout/server`) and set `MOYASAR_SECRET_KEY`.
The server is the price authority — the client never dictates the amount. Flip
`Config.paymentsEnabled = true` only after the Worker verifies amounts against the
server-side booking total and enforces payment-id idempotency.

## PDPL / data residency
Ya Spa stores Saudi PII (phone, home address, geo). Choose a region and complete
SDAIA cross-border-transfer controls per `compliance.html`. Minimise stored
sensitive fields; keep free-text health notes out of any foreign region.
