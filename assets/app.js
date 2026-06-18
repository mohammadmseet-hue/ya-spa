/* =========================================================================
   Ya Spa — interaction layer
   Vanilla JS. Bilingual (AR/EN), RTL-aware. WhatsApp ordering.
   ========================================================================= */
(function () {
  'use strict';
  const $  = (s, c) => (c || document).querySelector(s);
  const $$ = (s, c) => Array.from((c || document).querySelectorAll(s));

  const WA = '966565722923';
  const AR_DIGITS = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  let lang = localStorage.getItem('yaspa-lang') || 'ar';

  const dig = (n) => lang === 'ar' ? String(n).replace(/\d/g, d => AR_DIGITS[+d]) : String(n);
  const money = (n) => lang === 'ar' ? `${dig(n)} ﷼` : `SAR ${n}`;

  const T = {
    summaryEmpty:{ ar: 'اختاري خدمة لتبدئي', en: 'Pick a service to begin' },
    transport:   { ar: 'رسوم المواصلات', en: 'Transport' },
    vat:         { ar: 'ضريبة القيمة المضافة ١٥٪', en: 'VAT 15%' },
    total:       { ar: 'الإجمالي', en: 'Total' },
    needMore:    { ar: (x) => `أضيفي ${money(x)} للوصول للحد الأدنى للزيارة`, en: (x) => `Add ${money(x)} to reach the home-visit minimum` },
    ready:       { ar: '✓ طلبكِ جاهز للإرسال', en: '✓ Your order is ready to send' },
    add:         { ar: 'أضيفي للطلب', en: 'Add to order' },
    added:       { ar: '✓ مضافة', en: '✓ Added' },
    cartItems:   { ar: (n) => `${dig(n)} خدمة`, en: (n) => `${n} item${n>1?'s':''}` },
    pickFirst:   { ar: 'اختاري خدمة واحدة على الأقل أولًا 🌸', en: 'Pick at least one service first 🌸' },
  };

  /* Services (massage first, then beauty) */
  const SERVICES = [
    { id:'m_swedish', cat:'massage', ar:'المساج السويدي',        en:'Swedish Massage',    sub_ar:'٦٠ د', sub_en:'60 min', price:199 },
    { id:'m_deep',    cat:'massage', ar:'مساج الأنسجة العميقة',   en:'Deep Tissue',        sub_ar:'٦٠ د', sub_en:'60 min', price:249 },
    { id:'m_stone',   cat:'massage', ar:'مساج الأحجار الساخنة',   en:'Hot Stone',          sub_ar:'٧٥ د', sub_en:'75 min', price:279 },
    { id:'m_thai',    cat:'massage', ar:'المساج التايلندي',       en:'Thai Massage',       sub_ar:'٩٠ د', sub_en:'90 min', price:289 },
    { id:'m_aroma',   cat:'massage', ar:'العلاج بالزيوت العطرية', en:'Aromatherapy',       sub_ar:'٦٠ د', sub_en:'60 min', price:219 },
    { id:'m_foot',    cat:'massage', ar:'مساج القدمين الانعكاسي', en:'Foot Reflexology',   sub_ar:'٤٥ د', sub_en:'45 min', price:149 },
    { id:'b_mani',    cat:'beauty',  ar:'مانيكير وباديكير',       en:'Mani-Pedi',          sub_ar:'٦٠ د', sub_en:'60 min', price:119 },
    { id:'b_thread',  cat:'beauty',  ar:'إزالة الشعر والخيط',     en:'Threading & Waxing', sub_ar:'٣٠ د', sub_en:'30 min', price:49 },
    { id:'b_hair',    cat:'beauty',  ar:'تصفيف الشعر والسشوار',   en:'Hair & Blow-dry',    sub_ar:'٤٥ د', sub_en:'45 min', price:99 },
    { id:'b_facial',  cat:'beauty',  ar:'العناية بالبشرة',        en:'Facials & Skincare', sub_ar:'٦٠ د', sub_en:'60 min', price:149 },
  ];
  const byId = (id) => SERVICES.find(s => s.id === id);
  const CAT = { massage:{ar:'المساج',en:'Massage'}, beauty:{ar:'التجميل والعناية',en:'Beauty & care'} };

  const PKG = {
    occasion:{ ar:'باقة لمسة المناسبة', en:'The Occasion package', price:1200 },
    journey: { ar:'باقة رحلة العروس',   en:'The Bride\'s Journey package', price:4900 },
    deluxe:  { ar:'باقة عروس فاخرة',     en:'Bride Deluxe package', price:8500 },
  };

  const MIN_BASKET = 200, TRANSPORT = 30, VAT = 0.15;
  const cart = new Set();

  /* ---------- WhatsApp helpers ------------------------------------------ */
  function waLink(text){ return `https://wa.me/${WA}?text=${encodeURIComponent(text)}`; }
  function openWA(text){ window.open(waLink(text), '_blank'); }

  function orderMessage(){
    const chosen = SERVICES.filter(s => cart.has(s.id));
    const subtotal = chosen.reduce((a,s)=>a+s.price,0);
    const vat = Math.round((subtotal+TRANSPORT)*VAT);
    const total = subtotal+TRANSPORT+vat;
    if (lang === 'ar'){
      let m = 'مرحبًا يا سبا 🌸\nأرغب بحجز الخدمات التالية في جدة:\n';
      chosen.forEach(s => m += `• ${s.ar} (${s.sub_ar}) — ${s.price} ﷼\n`);
      m += `\nالمواصلات: ${TRANSPORT} ﷼\nالضريبة: ${vat} ﷼\nالإجمالي التقديري: ${total} ﷼\n\n`;
      m += 'الاسم:\nالحي في جدة:\nالموعد المفضّل:';
      return m;
    }
    let m = 'Hello Ya Spa 🌸\nI\'d like to book the following in Jeddah:\n';
    chosen.forEach(s => m += `• ${s.en} (${s.sub_en}) — SAR ${s.price}\n`);
    m += `\nTransport: SAR ${TRANSPORT}\nVAT: SAR ${vat}\nEstimated total: SAR ${total}\n\n`;
    m += 'Name:\nDistrict in Jeddah:\nPreferred time:';
    return m;
  }

  /* ---------- Render: estimator list ------------------------------------ */
  function renderEstimator(){
    const box = $('#estItems'); if (!box) return;
    let html = '';
    let lastCat = '';
    SERVICES.forEach(s => {
      if (s.cat !== lastCat){ html += `<div class="est-cat">${CAT[s.cat][lang]}</div>`; lastCat = s.cat; }
      html += `<div class="est-item${cart.has(s.id)?' active':''}" data-id="${s.id}" role="checkbox" tabindex="0" aria-checked="${cart.has(s.id)}">
        <span class="est-check"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M20 6 9 17l-5-5"/></svg></span>
        <span class="ei-name">${s[lang]}<span>${lang==='ar'?s.sub_ar:s.sub_en}</span></span>
        <span class="ei-price">${money(s.price)}</span></div>`;
    });
    box.innerHTML = html;
    $$('.est-item', box).forEach(el => {
      const toggle = () => setItem(el.dataset.id, !cart.has(el.dataset.id));
      el.addEventListener('click', toggle);
      el.addEventListener('keydown', e => { if (e.key==='Enter'||e.key===' '){ e.preventDefault(); toggle(); }});
    });
  }

  /* ---------- Render: summary + progress -------------------------------- */
  function renderSummary(){
    const lines = $('#estLines'), prog = $('#estProgress'), fill = $('#estFill'), hint = $('#estHint');
    if (!lines) return;
    const chosen = SERVICES.filter(s => cart.has(s.id));
    if (!chosen.length){ lines.innerHTML = `<p class="est-empty">${T.summaryEmpty[lang]}</p>`; prog.hidden = true; return; }
    const subtotal = chosen.reduce((a,s)=>a+s.price,0);
    const vat = Math.round((subtotal+TRANSPORT)*VAT);
    const total = subtotal+TRANSPORT+vat;
    let html = chosen.map(s => `<div class="est-line"><span>${s[lang]}</span><span>${money(s.price)}</span></div>`).join('');
    html += `<div class="est-line"><span>${T.transport[lang]}</span><span>${money(TRANSPORT)}</span></div>`;
    html += `<div class="est-line"><span>${T.vat[lang]}</span><span>${money(vat)}</span></div>`;
    html += `<div class="est-line total"><span>${T.total[lang]}</span><span>${money(total)}</span></div>`;
    lines.innerHTML = html;
    prog.hidden = false;
    fill.style.width = Math.min(100, Math.round(subtotal/MIN_BASKET*100)) + '%';
    if (subtotal >= MIN_BASKET){ hint.textContent = T.ready[lang]; hint.classList.add('ok'); }
    else { hint.textContent = T.needMore[lang](MIN_BASKET-subtotal); hint.classList.remove('ok'); }
  }

  /* ---------- Render: card buttons + cart bar --------------------------- */
  function renderCards(){
    $$('[data-add]').forEach(btn => {
      const on = cart.has(btn.dataset.add);
      btn.classList.toggle('added', on);
      const label = $('span:last-child', btn);
      if (label) label.textContent = on ? T.added[lang] : T.add[lang];
    });
  }
  function renderCartBar(){
    const bar = $('#cartBar'); if (!bar) return;
    const chosen = SERVICES.filter(s => cart.has(s.id));
    if (!chosen.length){ bar.hidden = true; document.body.classList.remove('cart-open'); return; }
    const subtotal = chosen.reduce((a,s)=>a+s.price,0);
    const total = subtotal + TRANSPORT + Math.round((subtotal+TRANSPORT)*VAT);
    bar.hidden = false;
    document.body.classList.add('cart-open');
    $('#cartCount').textContent = T.cartItems[lang](chosen.length);
    $('#cartTotal').textContent = money(total);
  }

  function setItem(id, on){ on ? cart.add(id) : cart.delete(id); sync(); }
  function sync(){ renderEstimator(); renderSummary(); renderCards(); renderCartBar(); }

  /* ---------- i18n ------------------------------------------------------- */
  function applyLang(){
    const html = document.documentElement;
    html.lang = lang; html.dir = lang === 'ar' ? 'rtl' : 'ltr';
    $('#langLabel').textContent = lang === 'ar' ? 'EN' : 'ع';
    $$('[data-ar]').forEach(el => { const v = el.getAttribute(lang==='ar'?'data-ar':'data-en'); if (v!=null) el.textContent = v; });
    $$('[data-ph-ar]').forEach(el => { el.placeholder = el.getAttribute(lang==='ar'?'data-ph-ar':'data-ph-en'); });
    document.title = lang==='ar' ? 'يا سبا · السبا والمساج يجيكِ البيت — Ya Spa' : 'Ya Spa · Massage & beauty at home in Jeddah';
    localStorage.setItem('yaspa-lang', lang);
    sync();
  }
  $('#langToggle').addEventListener('click', () => { lang = lang==='ar'?'en':'ar'; applyLang(); });

  /* ---------- Add buttons on cards -------------------------------------- */
  $$('[data-add]').forEach(btn => btn.addEventListener('click', () => {
    const id = btn.dataset.add;
    setItem(id, !cart.has(id));
    if (cart.has(id)) toast(lang==='ar' ? 'أُضيفت لطلبكِ 🌸' : 'Added to your order 🌸');
  }));

  /* ---------- Checkout + package + join buttons ------------------------- */
  function checkout(){
    if (!cart.size){ toast(T.pickFirst[lang]); $('#massage').scrollIntoView({behavior:'smooth'}); return; }
    openWA(orderMessage());
  }
  $('#checkoutBtn') && $('#checkoutBtn').addEventListener('click', checkout);
  $('#cartCheckout') && $('#cartCheckout').addEventListener('click', checkout);

  $$('[data-pkg]').forEach(btn => btn.addEventListener('click', () => {
    const p = PKG[btn.dataset.pkg];
    const msg = lang==='ar'
      ? `مرحبًا يا سبا 🌸\nأرغب بالاستفسار/الحجز عن: ${p.ar} (${p.price} ﷼) في جدة.\n\nالاسم:\nتاريخ المناسبة:\nالحي:`
      : `Hello Ya Spa 🌸\nI'd like to enquire/book: ${p.en} (SAR ${p.price}) in Jeddah.\n\nName:\nEvent date:\nDistrict:`;
    openWA(msg);
  }));

  $('#joinBtn') && $('#joinBtn').addEventListener('click', () => {
    openWA(lang==='ar'
      ? 'مرحبًا يا سبا 🌸\nأنا معالِجة مساج/أخصائية تجميل وأرغب بالانضمام للعمل معكم في جدة.\n\nالاسم:\nالتخصص:\nسنوات الخبرة:'
      : 'Hello Ya Spa 🌸\nI\'m a massage therapist / beauty pro and I\'d like to join you in Jeddah.\n\nName:\nSpeciality:\nYears of experience:');
  });

  $('#waDirect') && $('#waDirect').addEventListener('click', () => {
    openWA(lang==='ar' ? 'مرحبًا يا سبا 🌸 أريد الاستفسار عن خدماتكم في جدة.' : 'Hello Ya Spa 🌸 I\'d like to ask about your services in Jeddah.');
  });

  /* ---------- Sticky header + back-to-top -------------------------------- */
  const header = $('#header'), toTop = $('#toTop');
  const onScroll = () => { const y = window.scrollY; header.classList.toggle('scrolled', y>20); toTop.classList.toggle('show', y>600); };
  window.addEventListener('scroll', onScroll, { passive:true }); onScroll();
  toTop.addEventListener('click', () => window.scrollTo({ top:0, behavior:'smooth' }));

  /* ---------- Mobile menu ------------------------------------------------ */
  const burger = $('#burger'), menu = $('#mobileMenu');
  const closeMenu = () => { burger.classList.remove('open'); menu.classList.remove('open'); burger.setAttribute('aria-expanded','false'); document.body.style.overflow=''; };
  burger.addEventListener('click', () => {
    const open = !menu.classList.contains('open');
    burger.classList.toggle('open', open); menu.classList.toggle('open', open);
    burger.setAttribute('aria-expanded', open); document.body.style.overflow = open ? 'hidden' : '';
  });
  menu.addEventListener('click', e => { if (e.target===menu || e.target.closest('a')) closeMenu(); });

  /* ---------- FAQ -------------------------------------------------------- */
  $$('.faq-item').forEach(item => {
    const q = $('.faq-q', item), a = $('.faq-a', item);
    q.addEventListener('click', () => {
      const open = item.classList.contains('open');
      $$('.faq-item').forEach(o => { o.classList.remove('open'); $('.faq-a', o).style.maxHeight = null; });
      if (!open){ item.classList.add('open'); a.style.maxHeight = a.scrollHeight + 'px'; }
    });
  });

  /* ---------- Scroll reveal ---------------------------------------------- */
  const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); }}), { threshold:0.12, rootMargin:'0px 0px -40px 0px' });
  $$('.reveal').forEach(el => io.observe(el));

  /* ---------- Smooth anchors -------------------------------------------- */
  $$('a[href^="#"]').forEach(a => a.addEventListener('click', e => {
    const id = a.getAttribute('href'); if (id.length < 2) return;
    const t = document.querySelector(id); if (t){ e.preventDefault(); t.scrollIntoView({ behavior:'smooth', block:'start' }); }
  }));

  /* ---------- Toast ------------------------------------------------------ */
  let toastTimer;
  function toast(msg){ const t = $('#toast'); $('#toastMsg').textContent = msg; t.classList.add('show'); clearTimeout(toastTimer); toastTimer = setTimeout(()=>t.classList.remove('show'), 3200); }

  /* ---------- PWA: service worker + install prompt ---------------------- */
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(()=>{}));
  }
  let deferredPrompt = null;
  const installBtn = $('#installBtn');
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault(); deferredPrompt = e;
    if (installBtn) installBtn.hidden = false;
  });
  if (installBtn) installBtn.addEventListener('click', async () => {
    if (!deferredPrompt) return;
    deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    deferredPrompt = null; installBtn.hidden = true;
  });
  window.addEventListener('appinstalled', () => { if (installBtn) installBtn.hidden = true; });
  // iOS Safari: no beforeinstallprompt — show a one-time add-to-home hint
  const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const standalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone;
  if (isIOS && !standalone && !localStorage.getItem('yaspa-ios-hint')) {
    setTimeout(() => { toast(lang==='ar' ? 'لتثبيت التطبيق: شارك ← أضف إلى الشاشة الرئيسية' : 'To install: Share → Add to Home Screen'); localStorage.setItem('yaspa-ios-hint','1'); }, 3500);
  }

  /* ---------- Init ------------------------------------------------------- */
  applyLang();
})();
