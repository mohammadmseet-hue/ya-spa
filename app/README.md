# يا سبا · Ya Spa — iOS app (App Store)

This folder turns the existing Ya Spa website into a **real native iOS app** using
[Capacitor](https://capacitorjs.com/). Capacitor bundles the exact HTML/CSS/JS you
already have into a native shell — no rewrite — and adds native powers (push
notifications, offline, native share) on top. **We build entirely in the cloud, so you
never need a Mac.**

---

## What you need (one-time)

| Thing | Why | Cost |
|-------|-----|------|
| **Apple Developer Program** ✅ done | Publish on the App Store | $99/yr |
| **App Store Connect API key** | Lets the cloud build sign + upload for you | free |
| **Codemagic account** | Builds the app on *their* Macs — you have no Mac | free tier |
| Node.js (already installed here) | Runs Capacitor tooling | free |

You do **not** need a Mac, Xcode, tax info, or the Paid Applications Agreement (the app
is a free download; payment for the massage happens through Moyasar, not Apple).

---

## Build it (cloud, no Mac)

The whole build runs on Codemagic — see `codemagic.yaml`. Setup:

1. **Push this repo to GitHub** (done for you on a branch — just merge/push).
2. On **codemagic.io**: add the repo, and connect your **App Store Connect API key**
   (App Store Connect → *Users and Access → Integrations → App Store Connect API →
   Generate*; upload the `.p8` into Codemagic, name the integration **`Ya Spa ASC`**).
3. Register the bundle id **`sa.yaspa.app`** (Codemagic can auto-create it) and create
   the app record in App Store Connect (name **Ya Spa**, language **Arabic**).
4. Run the **ios** workflow → Codemagic builds on its Mac and pushes to **TestFlight**.
5. In App Store Connect: add screenshots + metadata (see `store-listing.md`), then
   submit for review.

### Building locally instead (only if you later get a Mac)
```bash
npm install
npm run add:ios      # scaffolds the ios/ Xcode project
npm run assets       # icons + splash from app/assets/ (already provided)
npm run ios          # opens Xcode → set signing team → Archive → upload
```
Re-run **`npm run sync`** any time you change the website, then rebuild.

- **App name:** `Ya Spa`  ·  **Bundle id:** `sa.yaspa.app` (permanent once live — change
  it in `capacitor.config.json` before the first build if you want something else).

---

## ⚠️ The one real risk: App Store rule 4.2 ("minimum functionality")

Apple rejects apps that are just a website in a wrapper. Ya Spa already ships native
value so it reads as a real app — but make sure at least these are on before submitting:

1. **Push notifications** — booking confirmations / therapist-on-the-way / offers. This
   alone usually clears 4.2. Wired in `native/native.js`; enable the **Push
   Notifications** capability in the build, and configure your **APNs auth key**.
2. **Works offline** — the app shell is bundled on-device, so it opens with no network.
3. **Native status bar + splash** — already themed via the Capacitor plugins.
4. Recommended next: **in-app checkout** (see `PAYMENTS.md`) so paying happens in the
   app, not only via a WhatsApp hand-off.

Also: fill **App Privacy**, set age rating **4+**, and add the review note from
`store-listing.md` explaining it's a physical women-only massage service.

---

## Files in this folder

- `capacitor.config.json` — app id, name, theme color, iOS settings.
- `package.json` — Capacitor deps + `copy:web` / `sync` / `add:ios` / `ios` / `assets`.
- `codemagic.yaml` — cloud iOS build → TestFlight (no Mac needed).
- `scripts/copy-web.mjs` — copies the site into `www/` and injects the app-only
  `native.js` (and payments, when configured).
- `assets/` — `icon.png` (1024, App-Store ready), `logo.png` (source for `npm run
  assets`), `splash.png` / `splash-dark.png`.
- `native/native.js` — app-only native layer (status bar, **push notifications**,
  native share). No-ops on the website.
- `checkout/` — **in-app payments** (card · Apple Pay · mada · STC Pay via Moyasar).
  See `PAYMENTS.md`. `demo.html` shows the payment form working with a test key.
- `store-listing.md` — App Store copy (Arabic + English), ready to paste.
- `PAYMENTS.md` — what you need to accept payments + the go-live checklist.
- `www/`, `ios/` *(generated)* — never edit; regenerated from the site + `cap add`.

## Turning on payments (after you have a Moyasar account)
See `PAYMENTS.md`. Short version: `cp checkout/config.example.js checkout/config.js`,
paste your **publishable** key + Worker URL, deploy `checkout/server/`, set
`enabled:true`, then `npm run sync`. Until then the app ships WhatsApp-ordering only.

## Why Capacitor
Reuse 100% of the existing site, real native app, native plugins, cloud-built with no
Mac. A full native (Swift/React Native) rewrite only pays off later if in-app booking,
accounts and payments grow large.
