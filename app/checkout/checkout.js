/* =========================================================================
   Ya Spa — in-app checkout (Moyasar: card · Apple Pay · mada · STC Pay)
   Progressive enhancement over the existing WhatsApp flow.

   How it works:
   - Reads the basket total the same way app.js does (services + transport + 15% VAT).
   - If window.YASPA_PAY.enabled is true AND a publishable key is set, it shows a
     "Pay now" button that opens the Moyasar payment form in a modal.
   - After payment, the buyer is verified SERVER-SIDE via your Worker before the
     booking is treated as paid.
   - If payments are disabled/unconfigured, everything falls back to WhatsApp — the
     app keeps working exactly as today.

   Load order in the page:
     <script src="checkout/config.js"></script>
     <script src="assets/app.js"></script>
     <script src="checkout/checkout.js"></script>
   ========================================================================= */
(function () {
  'use strict';
  var CFG = window.YASPA_PAY || {};
  var live = CFG.enabled && /^pk_(test|live)_/.test(CFG.publishableKey || '');

  // Pricing must match app.js exactly.
  var TRANSPORT = 30, VAT = 0.15;
  function lang(){ return localStorage.getItem('yaspa-lang') || 'ar'; }

  // Read chosen services from the DOM (the estimator marks .est-item.active with data-id + price)
  function basket(){
    var items = Array.prototype.slice.call(document.querySelectorAll('.est-item.active'));
    var lines = items.map(function(el){
      var name = (el.querySelector('.ei-name') || {}).firstChild;
      var priceTxt = (el.querySelector('.ei-price') || {}).textContent || '';
      var price = parseInt(priceTxt.replace(/[^\d]/g, ''), 10) || 0;   // handles ٩٩ / SAR 99
      return { id: el.getAttribute('data-id'), name: (name && name.textContent || '').trim(), price: price };
    });
    var subtotal = lines.reduce(function(a, l){ return a + l.price; }, 0);
    var vat = Math.round((subtotal + TRANSPORT) * VAT);
    return { lines: lines, subtotal: subtotal, total: subtotal + TRANSPORT + vat };
  }

  function ensureMoyasarLoaded(cb){
    if (window.Moyasar) return cb();
    var css = document.createElement('link');
    css.rel = 'stylesheet'; css.href = 'https://cdn.moyasar.com/mpf/1.15.0/moyasar.css';
    document.head.appendChild(css);
    var s = document.createElement('script');
    s.src = 'https://cdn.moyasar.com/mpf/1.15.0/moyasar.js';  // confirm latest at moyasar.com/docs
    s.onload = cb; s.onerror = function(){ alert('Payment failed to load — try WhatsApp for now.'); };
    document.head.appendChild(s);
  }

  function openModal(){
    var b = basket();
    if (!b.total || b.subtotal < 200){    // home-visit minimum, same as app.js
      alert(lang() === 'ar' ? 'أضيفي خدمات للوصول للحد الأدنى ٢٠٠ ﷼ أولًا 🌸'
                            : 'Add services to reach the SAR 200 minimum first 🌸');
      return;
    }
    var overlay = document.createElement('div');
    overlay.setAttribute('style', 'position:fixed;inset:0;z-index:9999;background:rgba(40,20,30,.55);display:flex;align-items:center;justify-content:center;padding:16px');
    overlay.innerHTML =
      '<div style="background:#fff;border-radius:20px;max-width:460px;width:100%;padding:20px;max-height:92vh;overflow:auto">' +
        '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">' +
          '<b style="font-family:sans-serif">' + (lang()==='ar'?'الدفع الآمن':'Secure payment') + '</b>' +
          '<button id="yspClose" style="border:0;background:#f3e6eb;border-radius:50%;width:32px;height:32px;cursor:pointer">✕</button>' +
        '</div>' +
        '<div style="font-family:sans-serif;color:#7a5966;margin-bottom:12px">' +
          (lang()==='ar'?'الإجمالي شامل المواصلات والضريبة: ':'Total incl. transport & VAT: ') +
          '<b>' + b.total + ' ' + (lang()==='ar'?'﷼':'SAR') + '</b></div>' +
        '<div class="mysr-form"></div>' +
      '</div>';
    document.body.appendChild(overlay);
    overlay.querySelector('#yspClose').onclick = function(){ overlay.remove(); };

    ensureMoyasarLoaded(function(){
      window.Moyasar.init({
        element: '.mysr-form',
        language: lang(),
        amount: b.total * 100,               // Moyasar expects the smallest unit (halalas)
        currency: CFG.currency || 'SAR',
        description: 'Ya Spa booking · ' + b.lines.map(function(l){ return l.name; }).join(', '),
        publishable_api_key: CFG.publishableKey,
        callback_url: CFG.callbackUrl,
        methods: CFG.methods || ['creditcard', 'applepay', 'stcpay'],
        apple_pay: CFG.applePay ? {
          label: CFG.applePay.label, country: CFG.applePay.country,
          validate_merchant_url: CFG.applePay.validateMerchantUrl
        } : undefined,
        // Verify server-side before we consider it paid.
        on_completed: function (payment) {
          return fetch((CFG.backendUrl || '') + '/api/verify', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: payment.id, expected_amount: b.total * 100 })
          }).then(function(r){ return r.json(); }).then(function(res){
            if (!res.paid) throw new Error('verification failed');
            return payment;    // resolve → Moyasar shows success + redirects to callback_url
          });
        }
      });
    });
  }

  // Public hook so app.js's checkout button can call payments when enabled.
  window.YaSpaCheckout = { enabled: live, open: openModal };

  // Auto-wire: add a "Pay now" button next to the WhatsApp checkout when enabled.
  if (live) document.addEventListener('DOMContentLoaded', function () {
    ['checkoutBtn', 'cartCheckout'].forEach(function (id) {
      var el = document.getElementById(id); if (!el) return;
      var pay = document.createElement('button');
      pay.className = el.className;
      pay.style.marginInlineStart = '8px';
      pay.textContent = lang() === 'ar' ? '💳 ادفعي الآن' : '💳 Pay now';
      pay.addEventListener('click', function (e) { e.preventDefault(); openModal(); });
      el.parentNode.insertBefore(pay, el.nextSibling);
    });
  });
})();
