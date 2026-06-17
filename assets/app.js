/* =========================================================================
   Ya Spa — interaction layer
   Vanilla JS, no dependencies. Bilingual (AR/EN), RTL-aware.
   ========================================================================= */
(function () {
  'use strict';
  const $  = (s, c) => (c || document).querySelector(s);
  const $$ = (s, c) => Array.from((c || document).querySelectorAll(s));

  /* ---------- i18n -------------------------------------------------------- */
  const AR_DIGITS = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  let lang = localStorage.getItem('yaspa-lang') || 'ar';

  const toLocaleDigits = (n) =>
    lang === 'ar' ? String(n).replace(/\d/g, d => AR_DIGITS[+d]) : String(n);

  const money = (n) =>
    lang === 'ar' ? `${toLocaleDigits(n)} ﷼` : `SAR ${n}`;

  const T = {
    join:        { ar: 'انضمي الآن', en: 'Join now' },
    waitOk:      { ar: '🌸 أهلًا بكِ! سنخبركِ فور وصولنا إلى حيّكِ.', en: '🌸 You\'re in! We\'ll tell you the moment we reach your area.' },
    waitErr:     { ar: 'الرجاء إدخال بريد إلكتروني صحيح', en: 'Please enter a valid email' },
    summaryEmpty:{ ar: 'اختاري خدمة لتبدئي', en: 'Pick a service to begin' },
    transport:   { ar: 'رسوم المواصلات', en: 'Transport' },
    vat:         { ar: 'ضريبة القيمة المضافة ١٥٪', en: 'VAT 15%' },
    total:       { ar: 'الإجمالي', en: 'Total' },
    needMore:    { ar: (x) => `أضيفي ${money(x)} للوصول للحد الأدنى للزيارة`, en: (x) => `Add ${money(x)} to reach the home-visit minimum` },
    ready:       { ar: '✓ زيارتكِ جاهزة للحجز', en: '✓ Your visit is ready to book' }
  };

  /* Services for the estimator (price = SAR, integer) */
  const SERVICES = [
    { id: 'mani',   ar: 'مانيكير وباديكير',     en: 'Mani-Pedi',           sub_ar: '٦٠ دقيقة', sub_en: '60 min', price: 119 },
    { id: 'thread', ar: 'إزالة الشعر والخيط',   en: 'Threading & Waxing',  sub_ar: '٣٠ دقيقة', sub_en: '30 min', price: 49  },
    { id: 'hair',   ar: 'تصفيف الشعر والسشوار', en: 'Hair & Blow-dry',     sub_ar: '٤٥ دقيقة', sub_en: '45 min', price: 99  },
    { id: 'facial', ar: 'العناية بالبشرة',      en: 'Facials & Skincare',  sub_ar: '٦٠ دقيقة', sub_en: '60 min', price: 149 }
  ];
  const MIN_BASKET = 200, TRANSPORT = 30, VAT = 0.15;
  const selected = new Set();

  function applyLang() {
    const html = document.documentElement;
    html.lang = lang;
    html.dir = lang === 'ar' ? 'rtl' : 'ltr';
    $('#langLabel').textContent = lang === 'ar' ? 'EN' : 'ع';

    $$('[data-ar]').forEach(el => {
      const v = el.getAttribute(lang === 'ar' ? 'data-ar' : 'data-en');
      if (v != null) el.textContent = v;
    });
    $$('[data-ph-ar]').forEach(el => {
      el.placeholder = el.getAttribute(lang === 'ar' ? 'data-ph-ar' : 'data-ph-en');
    });
    document.title = lang === 'ar'
      ? 'يا سبا · صالونكِ يجيكِ البيت — Ya Spa'
      : 'Ya Spa · Your salon comes home';

    localStorage.setItem('yaspa-lang', lang);
    renderEstimator();
    renderSummary();
  }

  $('#langToggle').addEventListener('click', () => {
    lang = lang === 'ar' ? 'en' : 'ar';
    applyLang();
  });

  /* ---------- Estimator -------------------------------------------------- */
  function renderEstimator() {
    const box = $('#estItems');
    if (!box) return;
    box.innerHTML = SERVICES.map(s => `
      <div class="est-item${selected.has(s.id) ? ' active' : ''}" data-id="${s.id}" role="checkbox" tabindex="0" aria-checked="${selected.has(s.id)}">
        <span class="est-check"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M20 6 9 17l-5-5"/></svg></span>
        <span class="ei-name">${s[lang]}<span>${lang === 'ar' ? s.sub_ar : s.sub_en}</span></span>
        <span class="ei-price">${money(s.price)}</span>
      </div>`).join('');

    $$('.est-item', box).forEach(el => {
      const toggle = () => {
        const id = el.dataset.id;
        selected.has(id) ? selected.delete(id) : selected.add(id);
        el.classList.toggle('active');
        el.setAttribute('aria-checked', selected.has(id));
        renderSummary();
      };
      el.addEventListener('click', toggle);
      el.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggle(); } });
    });
  }

  function renderSummary() {
    const lines = $('#estLines'), prog = $('#estProgress'), fill = $('#estFill'), hint = $('#estHint');
    if (!lines) return;

    if (selected.size === 0) {
      lines.innerHTML = `<p class="est-empty">${T.summaryEmpty[lang]}</p>`;
      prog.hidden = true;
      return;
    }

    const chosen = SERVICES.filter(s => selected.has(s.id));
    const subtotal = chosen.reduce((a, s) => a + s.price, 0);
    const base = subtotal + TRANSPORT;
    const vat = Math.round(base * VAT);
    const total = base + vat;

    let html = chosen.map(s =>
      `<div class="est-line"><span>${s[lang]}</span><span>${money(s.price)}</span></div>`).join('');
    html += `<div class="est-line"><span>${T.transport[lang]}</span><span>${money(TRANSPORT)}</span></div>`;
    html += `<div class="est-line"><span>${T.vat[lang]}</span><span>${money(vat)}</span></div>`;
    html += `<div class="est-line total"><span>${T.total[lang]}</span><span>${money(total)}</span></div>`;
    lines.innerHTML = html;

    prog.hidden = false;
    const pct = Math.min(100, Math.round((subtotal / MIN_BASKET) * 100));
    fill.style.width = pct + '%';
    if (subtotal >= MIN_BASKET) {
      hint.textContent = T.ready[lang];
      hint.classList.add('ok');
    } else {
      hint.textContent = T.needMore[lang](MIN_BASKET - subtotal);
      hint.classList.remove('ok');
    }
  }

  /* ---------- Sticky header + back-to-top -------------------------------- */
  const header = $('#header'), toTop = $('#toTop');
  const onScroll = () => {
    const y = window.scrollY;
    header.classList.toggle('scrolled', y > 20);
    toTop.classList.toggle('show', y > 600);
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
  toTop.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));

  /* ---------- Mobile menu ------------------------------------------------ */
  const burger = $('#burger'), menu = $('#mobileMenu');
  const closeMenu = () => { burger.classList.remove('open'); menu.classList.remove('open'); burger.setAttribute('aria-expanded', 'false'); document.body.style.overflow = ''; };
  burger.addEventListener('click', () => {
    const open = !menu.classList.contains('open');
    burger.classList.toggle('open', open);
    menu.classList.toggle('open', open);
    burger.setAttribute('aria-expanded', open);
    document.body.style.overflow = open ? 'hidden' : '';
  });
  menu.addEventListener('click', e => { if (e.target === menu || e.target.closest('a')) closeMenu(); });

  /* ---------- FAQ accordion ---------------------------------------------- */
  $$('.faq-item').forEach(item => {
    const q = $('.faq-q', item), a = $('.faq-a', item);
    q.addEventListener('click', () => {
      const open = item.classList.contains('open');
      $$('.faq-item').forEach(o => { o.classList.remove('open'); $('.faq-a', o).style.maxHeight = null; });
      if (!open) { item.classList.add('open'); a.style.maxHeight = a.scrollHeight + 'px'; }
    });
  });

  /* ---------- Scroll reveal ---------------------------------------------- */
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
  $$('.reveal').forEach(el => io.observe(el));

  /* ---------- Smooth in-page anchors (and close menu) -------------------- */
  $$('a[href^="#"]').forEach(a => {
    a.addEventListener('click', e => {
      const id = a.getAttribute('href');
      if (id.length < 2) return;
      const t = document.querySelector(id);
      if (t) { e.preventDefault(); t.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
    });
  });

  /* ---------- Toast ------------------------------------------------------ */
  let toastTimer;
  function toast(msg) {
    const t = $('#toast');
    $('#toastMsg').textContent = msg;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove('show'), 4200);
  }

  /* ---------- Waitlist form --------------------------------------------- */
  $('#waitForm').addEventListener('submit', e => {
    e.preventDefault();
    const email = $('#waitEmail');
    const ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value.trim());
    if (!ok) {
      email.style.borderColor = 'var(--error-600)';
      email.focus();
      toast(T.waitErr[lang]);
      return;
    }
    email.style.borderColor = '';
    /* Front-end only — wire to your CRM / Mailchimp / Supabase endpoint here. */
    e.target.reset();
    toast(T.waitOk[lang]);
  });
  $('#waitEmail').addEventListener('input', e => { e.target.style.borderColor = ''; });

  /* ---------- Init ------------------------------------------------------- */
  applyLang();
})();
