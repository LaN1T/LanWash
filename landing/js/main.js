const servicesData = [
  { icon: '🚗', keyTitle: 'serviceWashTitle', keyDesc: 'serviceWashDesc' },
  { icon: '🛋️', keyTitle: 'serviceInteriorTitle', keyDesc: 'serviceInteriorDesc' },
  { icon: '✨', keyTitle: 'servicePolishTitle', keyDesc: 'servicePolishDesc' },
  { icon: '🛡️', keyTitle: 'serviceProtectionTitle', keyDesc: 'serviceProtectionDesc' },
];

const whyData = [
  { icon: '⚡', keyTitle: 'whyFastTitle', keyDesc: 'whyFastDesc' },
  { icon: '🏆', keyTitle: 'whyQualityTitle', keyDesc: 'whyQualityDesc' },
  { icon: '💰', keyTitle: 'whyPriceTitle', keyDesc: 'whyPriceDesc' },
  { icon: '📱', keyTitle: 'whyOnlineTitle', keyDesc: 'whyOnlineDesc' },
];

let currentLang = 'ru';
let currentTheme = 'light';
let carouselIndex = 0;
let carouselSlides = 0;

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
}

function updateThemeIcon() {
  const btn = document.getElementById('themeToggle');
  if (!btn) return;
  btn.querySelector('.theme-icon').textContent = currentTheme === 'dark' ? '☀️' : '🌙';
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
  container.innerHTML = servicesData.map(s => `
    <div class="service-card">
      <div class="service-card__icon">${s.icon}</div>
      <h3 class="service-card__title" data-i18n="${s.keyTitle}">${translations[currentLang][s.keyTitle] || ''}</h3>
      <p class="service-card__desc" data-i18n="${s.keyDesc}">${translations[currentLang][s.keyDesc] || ''}</p>
    </div>
  `).join('');
  applyLang();
}

function renderWhy() {
  const container = document.getElementById('whyGrid');
  if (!container) return;
  container.innerHTML = whyData.map(w => `
    <div class="why-item">
      <div class="why-item__icon">${w.icon}</div>
      <h3 class="why-item__title" data-i18n="${w.keyTitle}">${translations[currentLang][w.keyTitle] || ''}</h3>
      <p class="why-item__desc" data-i18n="${w.keyDesc}">${translations[currentLang][w.keyDesc] || ''}</p>
    </div>
  `).join('');
  applyLang();
}

async function loadReviews() {
  const container = document.getElementById('reviewsTrack');
  if (!container) return;

  let reviews = [];
  try {
    const res = await fetch('https://api.lanwash.ru/reviews?limit=6');
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
      <div class="review-card__stars">${'★'.repeat(r.stars || 5)}${'☆'.repeat(5 - (r.stars || 5))}</div>
      <p class="review-card__text">${escapeHtml(r.text)}</p>
      <p class="review-card__author">${escapeHtml(r.author)}</p>
    </div>
  `).join('');

  carouselSlides = reviews.length;
  carouselIndex = 0;
  updateCarousel();
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
  if (prev) prev.addEventListener('click', () => { carouselIndex = Math.max(0, carouselIndex - 1); updateCarousel(); });
  if (next) next.addEventListener('click', () => { carouselIndex = Math.min(carouselSlides - 1, carouselIndex + 1); updateCarousel(); });
}

function updateCarousel() {
  const track = document.getElementById('reviewsTrack');
  if (!track || !carouselSlides) return;
  const slide = track.firstElementChild;
  if (!slide) return;
  const gap = 20;
  const slideWidth = slide.getBoundingClientRect().width + gap;
  track.style.transform = `translateX(${-carouselIndex * slideWidth}px)`;
}

function trackEvent(eventName, params) {
  if (window.gtag) {
    gtag('event', eventName, params || {});
  }
  // Stub for future analytics integrations
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

document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  initLang();
  renderServices();
  renderWhy();
  loadReviews();
  initCarousel();
  initMobileMenu();

  document.getElementById('themeToggle')?.addEventListener('click', toggleTheme);
  document.getElementById('langToggle')?.addEventListener('click', toggleLang);

  window.addEventListener('resize', () => {
    updateCarousel();
  });
});
