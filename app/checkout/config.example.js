/* Ya Spa payments config.
   1. Copy this file to `config.js` (same folder).
   2. Paste your Moyasar keys + your deployed Worker URL.
   3. Keep `enabled:false` until you've tested; flip to true to turn payments on.
   NEVER put the SECRET key (sk_...) here — it lives only in the backend Worker. */
window.YASPA_PAY = {
  enabled: false,                     // ← flip to true to show in-app card/Apple Pay checkout

  // Moyasar PUBLISHABLE key only (safe to ship). Test keys start with pk_test_...
  publishableKey: 'pk_test_REPLACE_ME',

  // Your deployed backend (see app/checkout/server/). Verifies payments server-side.
  backendUrl: 'https://yaspa-pay.YOURNAME.workers.dev',

  currency: 'SAR',
  methods: ['creditcard', 'applepay', 'stcpay'],   // mada is processed under 'creditcard'
  language: 'ar',                                   // form language; app switches this at runtime

  // Where Moyasar returns the buyer after payment (must be an allowed URL in your dashboard).
  callbackUrl: 'https://mohammadmseet-hue.github.io/ya-spa/paid.html',

  applePay: {
    label: 'Ya Spa',
    country: 'SA',
    validateMerchantUrl: 'https://api.moyasar.com/v1/applepay/initiate'
  }
};
