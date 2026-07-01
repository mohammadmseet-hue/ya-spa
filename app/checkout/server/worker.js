/* =========================================================================
   Ya Spa payments backend — Cloudflare Worker
   Two jobs:
     POST /api/verify   { id, expected_amount }  → confirms a payment really
                        succeeded (server-side, using the SECRET key) so the app
                        can trust it. Returns { paid: true|false, amount, status }.
     POST /api/webhook  ← Moyasar calls this on payment.paid; we check a shared
                        token and (here) just log/acknowledge. Wire your booking
                        store / WhatsApp notify inside handleWebhook().

   Secrets (set with `wrangler secret put NAME`, never commit them):
     MOYASAR_SECRET_KEY   e.g. sk_test_xxx / sk_live_xxx
     WEBHOOK_TOKEN        a random string you also register in Moyasar's dashboard

   Deploy:  cd app/checkout/server && npx wrangler deploy
   ========================================================================= */

const MOYASAR_API = 'https://api.moyasar.com/v1';

const CORS = {
  'Access-Control-Allow-Origin': '*',            // tighten to your domain(s) for production
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type'
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json', ...CORS } });

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(request.url);

    if (url.pathname === '/api/verify' && request.method === 'POST') {
      return verify(request, env);
    }
    if (url.pathname === '/api/webhook' && request.method === 'POST') {
      return webhook(request, env);
    }
    return json({ error: 'not found' }, 404);
  }
};

// ---- Verify a payment by ID using the SECRET key (Basic auth: key as username) ----
async function verify(request, env) {
  let body;
  try { body = await request.json(); } catch { return json({ paid: false, error: 'bad json' }, 400); }
  const { id, expected_amount } = body || {};
  if (!id) return json({ paid: false, error: 'missing id' }, 400);

  const auth = 'Basic ' + btoa(env.MOYASAR_SECRET_KEY + ':');
  const r = await fetch(`${MOYASAR_API}/payments/${encodeURIComponent(id)}`, {
    headers: { Authorization: auth }
  });
  if (!r.ok) return json({ paid: false, error: 'lookup failed', status: r.status }, 502);

  const p = await r.json();
  const paid = p.status === 'paid' &&
               (expected_amount == null || Number(p.amount) === Number(expected_amount));

  // TODO: on `paid`, record the booking as confirmed (KV/D1) and notify (WhatsApp/push).
  return json({ paid, amount: p.amount, currency: p.currency, status: p.status });
}

// ---- Webhook: Moyasar → us, on payment events ----
async function webhook(request, env) {
  const token = request.headers.get('x-moyasar-token') || new URL(request.url).searchParams.get('token');
  if (!env.WEBHOOK_TOKEN || token !== env.WEBHOOK_TOKEN) return json({ error: 'unauthorized' }, 401);

  let event;
  try { event = await request.json(); } catch { return json({ error: 'bad json' }, 400); }

  await handleWebhook(event, env);
  return json({ received: true });
}

async function handleWebhook(event, env) {
  // event.type e.g. 'payment_paid'; event.data is the payment object.
  const p = event && event.data;
  if (!p || p.status !== 'paid') return;
  // TODO: mark booking paid + notify. Example (uncomment + set env vars):
  // await fetch(`https://api.whatsapp.com/... or your notify endpoint`, {...});
  console.log('paid booking', p.id, p.amount, p.description);
}
