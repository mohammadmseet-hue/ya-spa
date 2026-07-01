# Ya Spa — Payments (card · Apple Pay · mada · STC Pay)

This explains **exactly what you need** to take payments in Saudi Arabia, the good news
about Apple's cut, the architecture, and how the code in `app/checkout/` fits in.

> Terminology: what you asked for ("customers pay by card/Apple Pay") = **accepting
> payments / checkout**. Paying your *therapists* their share = **payouts** — that's a
> separate, later phase covered at the bottom.

---

## 1. The good news about Apple's 30%

Ya Spa sells a **physical, in-person service** (massage at your home). Under App Store
guideline **3.1.3(e) / 3.1.5**, physical services consumed outside the app **must NOT**
use Apple In-App Purchase — you use a normal card processor instead, and **Apple takes
0%**. So you keep everything except the payment gateway's ~2.5% fee. (IAP + its 30% only
applies to digital goods, which we don't sell.)

Apple Pay is **not** IAP — it's just a card method through your gateway, and it's the
**most popular way to pay in KSA (~36%)**, running on the mada network. Definitely enable it.

---

## 2. What you need to accept payments

### Business / legal (you obtain these)
| # | Requirement | Notes |
|---|-------------|-------|
| 1 | **Commercial Registration (السجل التجاري / CR)** | A registered Saudi business. Sole-proprietor CR is fine to start. |
| 2 | **Saudi business bank account + IBAN** | Where the gateway settles your money (in SAR). |
| 3 | **National ID / Iqama** of the owner | For gateway KYC. |
| 4 | **VAT registration with ZATCA** (15%) | Required once you cross the VAT threshold; the app already prices VAT in. E-invoicing (Fatoora) comes with it. |
| 5 | **A payment-gateway merchant account** | See below — this is the key one. |

### The payment gateway (pick one — I built the code for **Moyasar**)
All of these are SAMA-licensed and support **mada + Visa/Mastercard + Apple Pay + STC Pay**:

| Gateway | Why | Pricing (2026, confirm on their site) |
|---------|-----|----------------------------------------|
| **Moyasar** ✅ recommended | Saudi-built, startup-friendly, cleanest API, fast onboarding, test mode | flat **~2.5%**, no monthly/setup fee |
| Tap Payments | GCC-wide, good SDKs | ~2.85% + SAR 0.30 |
| HyperPay | Enterprise, built-in Tabby/Tamara BNPL | ~2.5% + SAR 1 |
| PayTabs / Amazon Payment Services | Alternatives | varies |

> **Not Stripe** — it doesn't onboard Saudi-domestic businesses for local settlement.

### Apple Pay specifics
- On the **website + Safari**, Moyasar's form gives you Apple Pay with **zero extra Apple
  setup** (Moyasar is the merchant of record for the Apple Pay session).
- To show Apple Pay **inside the native iOS app**, Apple Pay JS does **not** run in the
  app's webview — you need a **native Apple Pay** path. Two options:
  1. Ship Apple Pay on the **website** now (works in mobile Safari) and, in the app,
     offer **card + mada + STC Pay** via Moyasar (all work in-app). ← simplest launch.
  2. Add a native Capacitor Apple Pay bridge later (Moyasar iOS SDK / a PassKit plugin)
     for in-app Apple Pay. Requires an **Apple Merchant ID** in your developer account.

---

## 3. Architecture (why you need a tiny backend)

You **cannot** safely take card payments from the app alone — the gateway's **secret
key** must never ship in the client, and payments must be **verified server-side**.

```
  App / Website                Your backend (serverless)         Moyasar
  ┌───────────┐  create        ┌──────────────────────┐  Basic-auth   ┌────────┐
  │ checkout  │ ──────────────▶│  /api/verify         │ ────────────▶ │  API   │
  │ (Moyasar  │  payment id    │  (uses SECRET key)   │  GET payment  │        │
  │  form,    │ ◀──────────────│  confirm paid+amount │ ◀──────────── │        │
  │  pk_ key) │   paid ✓/✗      │  then notify/booking │               └────────┘
  └───────────┘                └──────────┬───────────┘
                                          │ webhook (payment.paid)
                               ◀──────────┘  Moyasar → /api/webhook
```

- Client uses the **publishable** key (`pk_...`) — safe to expose — to collect the card
  and create the payment.
- Backend uses the **secret** key (`sk_...`) to **verify** the payment really succeeded
  and the amount matches, then marks the booking confirmed (and can WhatsApp/notify you).
- A **webhook** gives you a reliable second confirmation even if the user closes the app.

I provided that backend as a **Cloudflare Worker** in `app/checkout/server/` (free tier,
deploys in minutes, no server to manage). Firebase Functions or any Node host works too.

---

## 4. What's already built for you (in `app/checkout/`)
- `checkout.js` — drops a **"Pay by card / Apple Pay / mada"** step into the order flow,
  computes the SAR total (incl. transport + 15% VAT), and opens the Moyasar form.
  Falls back to the existing **WhatsApp** flow until you switch payments on.
- `config.example.js` — where your keys + backend URL go (copy to `config.js`).
- `demo.html` — a standalone page to **see the payment form working** with a test key.
- `server/worker.js` + `server/wrangler.toml` — the verify + webhook backend.

### Go-live checklist
1. Sign up at **moyasar.com**, finish KYC (CR + IBAN + ID).
2. Copy your **test** keys → `app/checkout/config.js`. Open `demo.html`, pay with test
   card `4111 1111 1111 1111` → confirm it works end to end.
3. Deploy the Worker: `cd app/checkout/server && npx wrangler deploy`. Put its URL in
   `config.js` and set the `MOYASAR_SECRET_KEY` + `WEBHOOK_TOKEN` secrets.
4. Register the Worker's `/api/webhook` URL in the Moyasar dashboard.
5. Flip `config.js` `enabled: true` and swap **test → live** keys. Done.

---

## 5. Later: paying your therapists (real "payouts")
When you split each booking with the therapist, you're moving money to third parties,
which is regulated (SAMA). Two clean routes:
- **Manual/batch payouts** (simplest, launch-ready): you're merchant of record, collect
  the full amount, then pay each therapist her share by **bank transfer to her IBAN**
  weekly. No extra licensing; just bookkeeping.
- **Split payments / marketplace** via a provider that supports sub-merchants (Tap and
  HyperPay offer marketplace/split; Moyasar via their payouts product) — less manual, but
  more onboarding. Move here once volume justifies it.

Start with **manual payouts**; it's how almost every marketplace begins.
