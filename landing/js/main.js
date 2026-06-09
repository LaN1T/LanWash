const icons = {
  wash: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/></svg>',
  interior: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
  polish: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/></svg>',
  protection: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
  fast: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
  quality: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="7"/><polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"/></svg>',
  price: '<svg width="28" height="28" viewBox="0 0 256 256" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M148,156a64,64,0,0,0,0-128H88A12.0006,12.0006,0,0,0,76,40v92H56a12,12,0,0,0,0,24H76v16H56a12,12,0,0,0,0,24H76v20a12,12,0,0,0,24,0V196h44a12,12,0,0,0,0-24H100V156ZM100,52h48a40,40,0,0,1,0,80H100Z"/></svg>',
  online: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>',
};

const servicesData = [
  { icon: icons.wash, key: 'wash' },
  { icon: icons.interior, key: 'interior' },
  { icon: icons.polish, key: 'polish' },
  { icon: icons.protection, key: 'protection' },
];

const whyData = [
  { icon: icons.fast, key: 'fast' },
  { icon: icons.quality, key: 'quality' },
  { icon: icons.price, key: 'price' },
  { icon: icons.online, key: 'online' },
];

let currentLang = 'ru';
let currentTheme = 'light';

function initTheme() {
  const saved = localStorage.getItem('lanwash-theme');
  if (saved) {
    currentTheme = saved;
  } else {
    currentTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  document.documentElement.setAttribute('data-theme', currentTheme);
  updateThemeIcon();
}

function toggleTheme() {
  currentTheme = currentTheme === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', currentTheme);
  localStorage.setItem('lanwash-theme', currentTheme);
  updateThemeIcon();
  trackEvent('theme_toggle');
}

function updateThemeIcon() {
  const btn = document.getElementById('themeToggle');
  if (!btn) return;
  const svg = btn.querySelector('svg');
  if (!svg) return;
  if (currentTheme === 'dark') {
    svg.innerHTML = '<circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>';
  } else {
    svg.innerHTML = '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>';
  }
}

function initLang() {
  const saved = localStorage.getItem('lanwash-lang');
  if (saved && translations[saved]) {
    currentLang = saved;
  } else {
    currentLang = 'ru';
  }
  applyLang();
  updateLangButton();
}

function toggleLang() {
  currentLang = currentLang === 'ru' ? 'en' : 'ru';
  localStorage.setItem('lanwash-lang', currentLang);
  applyLang();
  updateLangButton();
  trackEvent('lang_switch');
}

function applyLang() {
  document.documentElement.lang = currentLang === 'ru' ? 'ru' : 'en';
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (translations[currentLang][key]) {
      el.textContent = translations[currentLang][key];
    }
  });
}

function updateLangButton() {
  const btn = document.getElementById('langToggle');
  if (btn) {
    btn.textContent = currentLang.toUpperCase();
  }
}

function renderServices() {
  const container = document.getElementById('servicesGrid');
  if (!container) return;
  container.innerHTML = servicesData.map(s => {
    const titleKey = `service.${s.key}.title`;
    const descKey = `service.${s.key}.desc`;
    const priceKey = `service.${s.key}.price`;
    return `
      <div class="service-card" data-service="${s.key}" role="button" tabindex="0">
        <div class="service-card__icon">${s.icon}</div>
        <h3 class="service-card__title" data-i18n="${titleKey}">${translations[currentLang][titleKey] || ''}</h3>
        <p class="service-card__desc" data-i18n="${descKey}">${translations[currentLang][descKey] || ''}</p>
        <div class="service-card__price" data-i18n="${priceKey}">${translations[currentLang][priceKey] || ''}</div>
      </div>
    `;
  }).join('');

  // Add click handlers for modal
  container.querySelectorAll('.service-card').forEach(card => {
    card.addEventListener('click', () => openServiceModal(card.dataset.service));
    card.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        openServiceModal(card.dataset.service);
      }
    });
  });

  applyLang();
}

function openServiceModal(key) {
  const modal = document.getElementById('serviceModal');
  const iconEl = document.getElementById('modalIcon');
  const titleEl = document.getElementById('modalTitle');
  const descEl = document.getElementById('modalDesc');
  const listEl = document.getElementById('modalList');
  const priceEl = document.getElementById('modalPrice');

  const service = servicesData.find(s => s.key === key);
  if (!service || !modal) return;

  const title = translations[currentLang][`service.${key}.title`] || '';
  const desc = translations[currentLang][`service.${key}.desc`] || '';
  const price = translations[currentLang][`service.${key}.price`] || '';
  const detailsRaw = translations[currentLang][`service.${key}.details`] || '';
  const details = detailsRaw.split('|').filter(Boolean);

  iconEl.innerHTML = service.icon;
  titleEl.textContent = title;
  descEl.textContent = desc;
  priceEl.textContent = price;
  listEl.innerHTML = details.map(d => {
    const parts = d.split('—');
    const name = parts[0].trim();
    const itemPrice = parts[1] ? parts[1].trim() : '';
    return `<li><span>${escapeHtml(name)}</span>${itemPrice ? `<span class="modal__list-price">${escapeHtml(itemPrice)}</span>` : ''}</li>`;
  }).join('');

  modal.setAttribute('aria-hidden', 'false');
  document.body.style.overflow = 'hidden';
}

function closeServiceModal() {
  const modal = document.getElementById('serviceModal');
  if (!modal) return;
  modal.setAttribute('aria-hidden', 'true');
  document.body.style.overflow = '';
}

function renderWhy() {
  const container = document.getElementById('whyGrid');
  if (!container) return;
  container.innerHTML = whyData.map(w => {
    const titleKey = `why.${w.key}.title`;
    const descKey = `why.${w.key}.desc`;
    return `
      <div class="why-item">
        <div class="why-item__icon">${w.icon}</div>
        <h3 class="why-item__title" data-i18n="${titleKey}">${translations[currentLang][titleKey] || ''}</h3>
        <p class="why-item__desc" data-i18n="${descKey}">${translations[currentLang][descKey] || ''}</p>
      </div>
    `;
  }).join('');
  applyLang();
}

async function loadReviews() {
  const container = document.getElementById('reviewsTrack');
  if (!container) return;

  let reviews = [];
  try {
    const res = await fetch('https://api.lanwash.ru/api/reviews?limit=10&published=true');
    if (res.ok) {
      const data = await res.json();
      reviews = Array.isArray(data) ? data : (data.items || []);
    }
  } catch (e) {
    // fallback to placeholder
  }

  if (!reviews.length) {
    reviews = [
      { author: 'Алексей К.', text: 'Отличная мойка, машина блестит как новая! Персонал вежливый, запись через приложение очень удобная.', stars: 5 },
      { author: 'Мария С.', text: 'Делала химчистку салона — результат превзошёл ожидания. Запах ушёл полностью, пятен не осталось.', stars: 5 },
      { author: 'Дмитрий В.', text: 'Полировка заняла меньше времени, чем обещали. Качество на высоте, рекомендую.', stars: 5 },
    ];
  }

  container.innerHTML = reviews.map(r => `
    <div class="review-card">
      <div class="review-card__stars">${'<svg width="16" height="16" viewBox="0 0 24 24" fill="#f59e0b" stroke="none"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>'.repeat(r.stars || 5)}</div>
      <p class="review-card__text">${escapeHtml(r.text)}</p>
      <p class="review-card__author">${escapeHtml(r.author)}</p>
    </div>
  `).join('');
}

function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function initCarousel() {
  const prev = document.getElementById('reviewsPrev');
  const next = document.getElementById('reviewsNext');
  const track = document.getElementById('reviewsTrack');
  if (!track) return;

  if (prev) {
    prev.addEventListener('click', () => {
      track.scrollBy({ left: -340, behavior: 'smooth' });
    });
  }
  if (next) {
    next.addEventListener('click', () => {
      track.scrollBy({ left: 340, behavior: 'smooth' });
    });
  }
}

function trackEvent(eventName, params) {
  if (typeof gtag === 'function') {
    gtag('event', eventName, params || {});
  }
  if (typeof ym === 'function' && window.LANWASH_YM_ID) {
    ym(window.LANWASH_YM_ID, 'reachGoal', eventName);
  }
}

function initAnalytics() {
  const gaId = window.LANWASH_GA_ID;
  if (gaId && /^G-[A-Z0-9]+$/i.test(gaId)) {
    const script = document.createElement('script');
    script.async = true;
    script.src = 'https://www.googletagmanager.com/gtag/js?id=' + gaId;
    document.head.appendChild(script);

    window.dataLayer = window.dataLayer || [];
    function gtag() { dataLayer.push(arguments); }
    window.gtag = gtag;
    gtag('js', new Date());
    gtag('config', gaId);
  }

  const ymId = window.LANWASH_YM_ID;
  if (ymId && /^\d+$/.test(ymId)) {
    window.ym = window.ym || function() {
      (window.ym.a = window.ym.a || []).push(arguments);
    };
    window.ym.l = 1 * new Date();

    const script = document.createElement('script');
    script.async = true;
    script.src = 'https://mc.yandex.ru/metrika/tag.js';
    script.onload = function() {
      window.ym(ymId, 'init', {
        clickmap: true,
        trackLinks: true,
        accurateTrackBounce: true,
        webvisor: true
      });
    };
    document.head.appendChild(script);
  }
}

function initMobileMenu() {
  const toggle = document.getElementById('menuToggle');
  const menu = document.getElementById('mobileMenu');
  if (!toggle || !menu) return;

  toggle.addEventListener('click', () => {
    const expanded = toggle.getAttribute('aria-expanded') === 'true';
    toggle.setAttribute('aria-expanded', String(!expanded));
    menu.setAttribute('aria-hidden', String(expanded));
  });

  menu.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      toggle.setAttribute('aria-expanded', 'false');
      menu.setAttribute('aria-hidden', 'true');
    });
  });
}

function initModal() {
  const modal = document.getElementById('serviceModal');
  const overlay = document.getElementById('modalOverlay');
  const closeBtn = document.getElementById('modalClose');

  if (overlay) {
    overlay.addEventListener('click', closeServiceModal);
  }
  if (closeBtn) {
    closeBtn.addEventListener('click', closeServiceModal);
  }
  if (modal) {
    modal.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        closeServiceModal();
      }
    });
  }
}

document.addEventListener('DOMContentLoaded', () => {
  initAnalytics();
  initTheme();
  initLang();
  renderServices();
  renderWhy();
  loadReviews();
  initCarousel();
  initMobileMenu();
  initModal();

  document.getElementById('themeToggle')?.addEventListener('click', toggleTheme);
  document.getElementById('langToggle')?.addEventListener('click', toggleLang);

  document.querySelector('.hero__cta')?.addEventListener('click', () => {
    trackEvent('book_click');
  });
});
