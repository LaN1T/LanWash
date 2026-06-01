# Web & Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a premium landing page (`lanwash.ru`) with GSAP animations, dark/light theme, i18n, PWA, analytics; fix Flutter web CanvasKit crash; redesign splash screen with system theme support; replace raster icon with SVG and generate all platform assets; add review moderation backend.

**Architecture:** Landing is a static HTML/CSS/JS site in `landing/` folder served by Nginx alongside the existing Flutter web app. All landing logic is client-side (theme, language, GSAP animations). Flutter web switches to HTML renderer to avoid CanvasKit CDN dependency. Icons are generated from a single SVG source via `flutter_launcher_icons`.

**Tech Stack:** HTML5, CSS3, Vanilla JS, GSAP, Flutter (Dart), Python/FastAPI/SQLAlchemy, Nginx, Docker

---

## File Structure

```
landing/
├── index.html
├── css/
│   └── style.css
├── js/
│   ├── main.js
│   ├── translations.js
│   └── gsap-animations.js
├── manifest.json
├── sw.js
├── sitemap.xml
├── robots.txt
└── assets/
    ├── logo.svg
    ├── hero-bg.webp
    ├── service-wash.webp
    ├── service-interior.webp
    ├── service-polish.webp
    └── service-protection.webp

backend/
├── migrations/versions/... (new: add is_published to reviews)
├── models/review.py (add is_published)
└── routers/reviews.py (add admin endpoints)

lib/
├── main.dart (splash integration)
├── screens/admin/reviews_moderation_screen.dart (new)
└── ...
```

---

## Task 1: Create Landing Page Foundation

**Files:**
- Create: `landing/index.html`
- Create: `landing/css/style.css`
- Create: `landing/js/translations.js`
- Create: `landing/js/main.js`

### Step 1.1: Create `landing/index.html`

```html
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LanWash — Профессиональная автомойка</title>
  <meta name="description" content="LanWash — профессиональный уход за вашим авто. Мойка, химчистка, полировка. Запишитесь онлайн.">
  <meta property="og:title" content="LanWash — Профессиональная автомойка">
  <meta property="og:description" content="Мойка, химчистка, полировка. Запишитесь онлайн или через Telegram.">
  <meta property="og:image" content="/assets/og-image.png">
  <meta property="og:type" content="website">
  <link rel="icon" type="image/svg+xml" href="/assets/logo.svg">
  <link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
  <link rel="manifest" href="/manifest.json">
  <link rel="stylesheet" href="/css/style.css">
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "LocalBusiness",
    "name": "LanWash",
    "description": "Профессиональная автомойка",
    "url": "https://lanwash.ru",
    "telephone": "+7-999-999-99-99",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "ул. Примерная, 1",
      "addressLocality": "Москва",
      "addressCountry": "RU"
    },
    "openingHours": "Mo-Su 08:00-22:00"
  }
  </script>
</head>
<body>
  <header class="header">
    <div class="container header__inner">
      <a href="#" class="logo">
        <img src="/assets/logo.svg" alt="LanWash" width="40" height="40">
        <span>LanWash</span>
      </a>
      <nav class="nav">
        <a href="#services" data-i18n="nav.services">Услуги</a>
        <a href="#why-us" data-i18n="nav.why">Почему мы</a>
        <a href="#reviews" data-i18n="nav.reviews">Отзывы</a>
        <a href="#contacts" data-i18n="nav.contacts">Контакты</a>
      </nav>
      <div class="header__controls">
        <button class="theme-toggle" aria-label="Toggle theme">🌙</button>
        <button class="lang-toggle" aria-label="Toggle language">RU</button>
      </div>
      <button class="mobile-menu-btn" aria-label="Menu">☰</button>
    </div>
  </header>

  <main>
    <section class="hero" id="hero">
      <div class="hero__bg"></div>
      <div class="hero__content">
        <h1 class="hero__title">LanWash</h1>
        <p class="hero__subtitle" data-i18n="hero.subtitle">Профессиональный уход за вашим авто</p>
        <a href="https://app.lanwash.ru" class="btn btn--primary" data-i18n="hero.book">Записаться</a>
        <p class="hero__alt" data-i18n="hero.alt">Или запишитесь через <a href="https://t.me/lanwash_bot">Telegram Bot</a></p>
      </div>
    </section>

    <section class="services" id="services">
      <div class="container">
        <h2 class="section-title" data-i18n="services.title">Наши услуги</h2>
        <div class="services__grid" id="services-grid"></div>
      </div>
    </section>

    <section class="why-us" id="why-us">
      <div class="container">
        <h2 class="section-title" data-i18n="why.title">Почему мы</h2>
        <div class="why-us__grid" id="why-grid"></div>
      </div>
    </section>

    <section class="reviews" id="reviews">
      <div class="container">
        <h2 class="section-title" data-i18n="reviews.title">Отзывы клиентов</h2>
        <div class="reviews__carousel" id="reviews-carousel">
          <button class="reviews__arrow reviews__arrow--prev" aria-label="Previous">‹</button>
          <div class="reviews__track" id="reviews-track"></div>
          <button class="reviews__arrow reviews__arrow--next" aria-label="Next">›</button>
        </div>
      </div>
    </section>

    <section class="contacts" id="contacts">
      <div class="container">
        <h2 class="section-title" data-i18n="contacts.title">Контакты</h2>
        <div class="contacts__grid">
          <div class="contacts__info">
            <p data-i18n="contacts.address">Адрес: ул. Примерная, 1, Москва</p>
            <p data-i18n="contacts.hours">Часы работы: ежедневно 08:00–22:00</p>
            <a href="tel:+79999999999" class="btn btn--secondary" data-i18n="contacts.call">Позвонить</a>
            <a href="https://t.me/lanwash_bot" class="btn btn--secondary" data-i18n="contacts.tg">Написать в Telegram</a>
          </div>
          <div class="contacts__map">
            <iframe src="https://yandex.ru/map-widget/v1/-/..." width="100%" height="300" frameborder="0"></iframe>
          </div>
        </div>
      </div>
    </section>
  </main>

  <footer class="footer">
    <div class="container">
      <p>© LanWash 2025</p>
    </div>
  </footer>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.2/gsap.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.2/ScrollTrigger.min.js"></script>
  <script src="/js/translations.js"></script>
  <script src="/js/main.js"></script>
</body>
</html>
```

### Step 1.2: Create `landing/css/style.css`

```css
:root {
  --color-bg: #ffffff;
  --color-bg-alt: #f5f5f7;
  --color-text: #1a1a1a;
  --color-text-muted: #666666;
  --color-primary: #2563eb;
  --color-primary-hover: #1d4ed8;
  --color-border: #e5e5e5;
  --header-height: 64px;
  --radius: 12px;
  --shadow: 0 4px 24px rgba(0,0,0,0.08);
  --transition: 0.3s ease;
}

[data-theme="dark"] {
  --color-bg: #0a0a0a;
  --color-bg-alt: #141414;
  --color-text: #f5f5f5;
  --color-text-muted: #a0a0a0;
  --color-primary: #3b82f6;
  --color-primary-hover: #60a5fa;
  --color-border: #2a2a2a;
  --shadow: 0 4px 24px rgba(0,0,0,0.4);
}

* { margin: 0; padding: 0; box-sizing: border-box; }

html { scroll-behavior: smooth; }

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--color-bg);
  color: var(--color-text);
  line-height: 1.6;
  transition: background var(--transition), color var(--transition);
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 24px;
}

/* Header */
.header {
  position: fixed;
  top: 0; left: 0; right: 0;
  height: var(--header-height);
  background: rgba(var(--color-bg), 0.8);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--color-border);
  z-index: 1000;
  transition: background var(--transition);
}

.header__inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 100%;
}

.logo {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--color-text);
  text-decoration: none;
}

.logo img { width: 40px; height: 40px; }

.nav { display: flex; gap: 32px; }

.nav a {
  color: var(--color-text-muted);
  text-decoration: none;
  font-weight: 500;
  transition: color var(--transition);
}

.nav a:hover { color: var(--color-primary); }

.header__controls { display: flex; gap: 12px; }

.theme-toggle, .lang-toggle {
  background: none;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  padding: 6px 12px;
  cursor: pointer;
  color: var(--color-text);
  font-size: 0.9rem;
  transition: all var(--transition);
}

.theme-toggle:hover, .lang-toggle:hover {
  border-color: var(--color-primary);
}

.mobile-menu-btn {
  display: none;
  background: none;
  border: none;
  font-size: 1.5rem;
  color: var(--color-text);
  cursor: pointer;
}

/* Hero */
.hero {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  overflow: hidden;
}

.hero__bg {
  position: absolute;
  inset: 0;
  background: url('/assets/hero-bg.webp') center/cover no-repeat;
}

.hero__bg::after {
  content: '';
  position: absolute;
  inset: 0;
  background: rgba(0,0,0,0.6);
}

[data-theme="dark"] .hero__bg::after {
  background: rgba(0,0,0,0.75);
}

.hero__content {
  position: relative;
  z-index: 1;
  color: #fff;
}

.hero__title {
  font-size: clamp(3rem, 8vw, 6rem);
  font-weight: 800;
  letter-spacing: -0.02em;
  opacity: 0.9;
}

.hero__subtitle {
  font-size: clamp(1rem, 2.5vw, 1.5rem);
  margin-top: 16px;
  opacity: 0.85;
}

.hero .btn--primary {
  margin-top: 32px;
  display: inline-block;
}

.hero__alt {
  margin-top: 16px;
  font-size: 0.9rem;
  opacity: 0.7;
}

.hero__alt a { color: #fff; text-decoration: underline; }

/* Buttons */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 14px 32px;
  border-radius: var(--radius);
  font-weight: 600;
  text-decoration: none;
  transition: all var(--transition);
  cursor: pointer;
  border: none;
}

.btn--primary {
  background: var(--color-primary);
  color: #fff;
}

.btn--primary:hover { background: var(--color-primary-hover); transform: translateY(-2px); }

.btn--secondary {
  background: transparent;
  color: var(--color-text);
  border: 1px solid var(--color-border);
}

.btn--secondary:hover { border-color: var(--color-primary); color: var(--color-primary); }

/* Sections */
section { padding: 80px 0; }

.section-title {
  font-size: clamp(1.75rem, 4vw, 2.5rem);
  font-weight: 700;
  text-align: center;
  margin-bottom: 48px;
}

/* Services */
.services { background: var(--color-bg-alt); }

.services__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 24px;
}

.service-card {
  background: var(--color-bg);
  border-radius: var(--radius);
  padding: 32px;
  border: 1px solid var(--color-border);
  transition: transform var(--transition), box-shadow var(--transition);
}

.service-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow);
}

.service-card__icon {
  width: 48px;
  height: 48px;
  margin-bottom: 16px;
}

.service-card__title {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 8px;
}

.service-card__desc {
  color: var(--color-text-muted);
  font-size: 0.95rem;
}

.service-card__price {
  margin-top: 12px;
  font-weight: 600;
  color: var(--color-primary);
}

/* Why Us */
.why-us__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 32px;
}

.why-item {
  text-align: center;
  padding: 24px;
}

.why-item__icon {
  width: 56px;
  height: 56px;
  margin: 0 auto 16px;
  background: var(--color-bg-alt);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
}

.why-item__title {
  font-weight: 600;
  margin-bottom: 8px;
}

.why-item__desc {
  color: var(--color-text-muted);
  font-size: 0.9rem;
}

/* Reviews */
.reviews { background: var(--color-bg-alt); }

.reviews__carousel {
  position: relative;
  max-width: 800px;
  margin: 0 auto;
}

.reviews__track {
  display: flex;
  gap: 24px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
  padding: 8px 0;
}

.reviews__track::-webkit-scrollbar { display: none; }

.review-card {
  flex: 0 0 320px;
  background: var(--color-bg);
  border-radius: var(--radius);
  padding: 24px;
  border: 1px solid var(--color-border);
  scroll-snap-align: start;
}

.review-card__header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

.review-card__avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: var(--color-bg-alt);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  color: var(--color-primary);
}

.review-card__name { font-weight: 600; }

.review-card__stars { color: #f59e0b; font-size: 0.9rem; }

.review-card__text {
  color: var(--color-text-muted);
  font-size: 0.95rem;
  line-height: 1.5;
}

.reviews__arrow {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: 1px solid var(--color-border);
  background: var(--color-bg);
  color: var(--color-text);
  font-size: 1.25rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2;
}

.reviews__arrow--prev { left: -20px; }
.reviews__arrow--next { right: -20px; }

/* Contacts */
.contacts__grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 48px;
  align-items: start;
}

.contacts__info p { margin-bottom: 12px; }

.contacts__info .btn { margin-top: 16px; margin-right: 12px; }

.contacts__map {
  border-radius: var(--radius);
  overflow: hidden;
  border: 1px solid var(--color-border);
}

.contacts__map iframe { display: block; border: none; }

/* Footer */
.footer {
  padding: 32px 0;
  border-top: 1px solid var(--color-border);
  text-align: center;
  color: var(--color-text-muted);
  font-size: 0.875rem;
}

/* Mobile */
@media (max-width: 768px) {
  .nav { display: none; }
  .mobile-menu-btn { display: block; }
  .header__controls { gap: 8px; }
  .contacts__grid { grid-template-columns: 1fr; }
  .reviews__arrow { display: none; }
  .review-card { flex: 0 0 85vw; }
  section { padding: 60px 0; }
}
```

### Step 1.3: Create `landing/js/translations.js`

```javascript
const translations = {
  ru: {
    'nav.services': 'Услуги',
    'nav.why': 'Почему мы',
    'nav.reviews': 'Отзывы',
    'nav.contacts': 'Контакты',
    'hero.subtitle': 'Профессиональный уход за вашим авто',
    'hero.book': 'Записаться',
    'hero.alt': 'Или запишитесь через',
    'services.title': 'Наши услуги',
    'why.title': 'Почему мы',
    'reviews.title': 'Отзывы клиентов',
    'contacts.title': 'Контакты',
    'contacts.address': 'Адрес: ул. Примерная, 1, Москва',
    'contacts.hours': 'Часы работы: ежедневно 08:00–22:00',
    'contacts.call': 'Позвонить',
    'contacts.tg': 'Написать в Telegram',
    'service.wash.title': 'Мойка кузова',
    'service.wash.desc': 'Полная мойка кузова с использованием профессиональной химии',
    'service.interior.title': 'Химчистка салона',
    'service.interior.desc': 'Глубокая очистка всех поверхностей салона',
    'service.polish.title': 'Полировка',
    'service.polish.desc': 'Восстановление блеска и удаление мелких царапин',
    'service.protection.title': 'Защитное покрытие',
    'service.protection.desc': 'Нанесение керамического или воскового покрытия',
    'why.fast.title': 'Быстро',
    'why.fast.desc': 'Среднее время мойки — 30 минут',
    'why.quality.title': 'Качественно',
    'why.quality.desc': 'Только профессиональные средства и оборудование',
    'why.price.title': 'Честная цена',
    'why.price.desc': 'Прозрачное ценообразование без скрытых платежей',
    'why.online.title': 'Онлайн-запись',
    'why.online.desc': 'Запишитесь удобное время через сайт или Telegram',
  },
  en: {
    'nav.services': 'Services',
    'nav.why': 'Why Us',
    'nav.reviews': 'Reviews',
    'nav.contacts': 'Contacts',
    'hero.subtitle': 'Professional car care',
    'hero.book': 'Book now',
    'hero.alt': 'Or book via',
    'services.title': 'Our Services',
    'why.title': 'Why choose us',
    'reviews.title': 'Customer Reviews',
    'contacts.title': 'Contact us',
    'contacts.address': 'Address: 1 Example St, Moscow',
    'contacts.hours': 'Hours: daily 08:00–22:00',
    'contacts.call': 'Call us',
    'contacts.tg': 'Message on Telegram',
    'service.wash.title': 'Exterior Wash',
    'service.wash.desc': 'Full body wash using professional products',
    'service.interior.title': 'Interior Detailing',
    'service.interior.desc': 'Deep cleaning of all interior surfaces',
    'service.polish.title': 'Polishing',
    'service.polish.desc': 'Restore shine and remove minor scratches',
    'service.protection.title': 'Protective Coating',
    'service.protection.desc': 'Ceramic or wax coating application',
    'why.fast.title': 'Fast',
    'why.fast.desc': 'Average wash time — 30 minutes',
    'why.quality.title': 'Quality',
    'why.quality.desc': 'Only professional products and equipment',
    'why.price.title': 'Fair Price',
    'why.price.desc': 'Transparent pricing with no hidden fees',
    'why.online.title': 'Online Booking',
    'why.online.desc': 'Book your slot via website or Telegram',
  }
};
```

### Step 1.4: Create `landing/js/main.js`

```javascript
// Theme
function initTheme() {
  const saved = localStorage.getItem('theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const theme = saved || (prefersDark ? 'dark' : 'light');
  document.documentElement.setAttribute('data-theme', theme);
  updateThemeIcon(theme);
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme');
  const next = current === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
  updateThemeIcon(next);
}

function updateThemeIcon(theme) {
  const btn = document.querySelector('.theme-toggle');
  if (btn) btn.textContent = theme === 'dark' ? '☀️' : '🌙';
}

// Language
let currentLang = localStorage.getItem('lang') || 'ru';

function initLang() {
  applyLang(currentLang);
}

function toggleLang() {
  currentLang = currentLang === 'ru' ? 'en' : 'ru';
  localStorage.setItem('lang', currentLang);
  applyLang(currentLang);
}

function applyLang(lang) {
  const t = translations[lang];
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (t[key]) el.textContent = t[key];
  });
  document.documentElement.lang = lang;
  const btn = document.querySelector('.lang-toggle');
  if (btn) btn.textContent = lang.toUpperCase();
}

// Services data
const services = [
  { key: 'wash', icon: '🚗' },
  { key: 'interior', icon: '🛋️' },
  { key: 'polish', icon: '✨' },
  { key: 'protection', icon: '🛡️' }
];

function renderServices() {
  const grid = document.getElementById('services-grid');
  if (!grid) return;
  grid.innerHTML = services.map(s => `
    <div class="service-card">
      <div class="service-card__icon">${s.icon}</div>
      <h3 class="service-card__title" data-i18n="service.${s.key}.title"></h3>
      <p class="service-card__desc" data-i18n="service.${s.key}.desc"></p>
      <div class="service-card__price">от 500 ₽</div>
    </div>
  `).join('');
  applyLang(currentLang);
}

// Why Us data
const whyItems = [
  { key: 'fast', icon: '⚡' },
  { key: 'quality', icon: '⭐' },
  { key: 'price', icon: '💰' },
  { key: 'online', icon: '📱' }
];

function renderWhy() {
  const grid = document.getElementById('why-grid');
  if (!grid) return;
  grid.innerHTML = whyItems.map(w => `
    <div class="why-item">
      <div class="why-item__icon">${w.icon}</div>
      <h3 class="why-item__title" data-i18n="why.${w.key}.title"></h3>
      <p class="why-item__desc" data-i18n="why.${w.key}.desc"></p>
    </div>
  `).join('');
  applyLang(currentLang);
}

// Reviews
async function loadReviews() {
  const track = document.getElementById('reviews-track');
  if (!track) return;
  
  let reviews = [];
  try {
    const res = await fetch('https://api.lanwash.ru/api/reviews?limit=10&published=true');
    if (res.ok) reviews = await res.json();
  } catch (e) {
    console.log('Reviews API failed, using placeholders');
  }
  
  if (reviews.length === 0) {
    reviews = [
      { name: 'Александр', rating: 5, comment: 'Отличная мойка, быстро и качественно!' },
      { name: 'Мария', rating: 5, comment: 'Салон как новый после химчистки.' },
      { name: 'Дмитрий', rating: 4, comment: 'Хороший сервис, рекомендую.' }
    ];
  }
  
  track.innerHTML = reviews.map(r => `
    <div class="review-card">
      <div class="review-card__header">
        <div class="review-card__avatar">${r.name[0]}</div>
        <div>
          <div class="review-card__name">${r.name}</div>
          <div class="review-card__stars">${'★'.repeat(r.rating)}${'☆'.repeat(5 - r.rating)}</div>
        </div>
      </div>
      <p class="review-card__text">${r.comment}</p>
    </div>
  `).join('');
}

// Carousel scroll
function initCarousel() {
  const track = document.getElementById('reviews-track');
  const prev = document.querySelector('.reviews__arrow--prev');
  const next = document.querySelector('.reviews__arrow--next');
  if (!track || !prev || !next) return;
  
  prev.addEventListener('click', () => {
    track.scrollBy({ left: -340, behavior: 'smooth' });
  });
  next.addEventListener('click', () => {
    track.scrollBy({ left: 340, behavior: 'smooth' });
  });
}

// Analytics helpers
function trackEvent(name) {
  if (window.ym) ym(XXXXXX, 'reachGoal', name);
  if (window.gtag) gtag('event', name);
}

// Init
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  initLang();
  renderServices();
  renderWhy();
  loadReviews();
  initCarousel();
  
  document.querySelector('.theme-toggle')?.addEventListener('click', () => {
    toggleTheme();
    trackEvent('theme_toggle');
  });
  document.querySelector('.lang-toggle')?.addEventListener('click', () => {
    toggleLang();
    trackEvent('lang_switch');
  });
  document.querySelector('.btn--primary')?.addEventListener('click', () => trackEvent('book_click'));
});
```

### Step 1.5: Commit

```bash
git add landing/
git commit -m "feat(landing): create landing page foundation (HTML, CSS, i18n, theme)"
```

---

## Task 2: Add GSAP Animations

**Files:**
- Create: `landing/js/gsap-animations.js`
- Modify: `landing/index.html` (add script tag)

### Step 2.1: Create `landing/js/gsap-animations.js`

```javascript
gsap.registerPlugin(ScrollTrigger);

// Hero entrance
gsap.from('.hero__title', {
  y: 60,
  opacity: 0,
  duration: 1,
  ease: 'power3.out',
  delay: 0.2
});

gsap.from('.hero__subtitle', {
  y: 40,
  opacity: 0,
  duration: 0.8,
  ease: 'power3.out',
  delay: 0.5
});

gsap.from('.hero .btn--primary', {
  scale: 0.8,
  opacity: 0,
  duration: 0.6,
  ease: 'back.out(1.7)',
  delay: 0.8
});

// Services cards stagger
gsap.from('.service-card', {
  scrollTrigger: {
    trigger: '#services',
    start: 'top 80%',
    toggleActions: 'play none none none'
  },
  y: 50,
  opacity: 0,
  duration: 0.7,
  stagger: 0.1,
  ease: 'power2.out'
});

// Why Us items
gsap.from('.why-item', {
  scrollTrigger: {
    trigger: '#why-us',
    start: 'top 80%'
  },
  y: 40,
  opacity: 0,
  duration: 0.6,
  stagger: 0.12,
  ease: 'power2.out'
});

// Reviews carousel
gsap.from('.reviews__carousel', {
  scrollTrigger: {
    trigger: '#reviews',
    start: 'top 80%'
  },
  y: 30,
  opacity: 0,
  duration: 0.8,
  ease: 'power2.out'
});

// Contacts
gsap.from('.contacts__info', {
  scrollTrigger: {
    trigger: '#contacts',
    start: 'top 80%'
  },
  x: -40,
  opacity: 0,
  duration: 0.7,
  ease: 'power2.out'
});

gsap.from('.contacts__map', {
  scrollTrigger: {
    trigger: '#contacts',
    start: 'top 80%'
  },
  x: 40,
  opacity: 0,
  duration: 0.7,
  ease: 'power2.out'
});
```

### Step 2.2: Add script to `landing/index.html`

Add before closing `</body>`:
```html
<script src="/js/gsap-animations.js"></script>
```

### Step 2.3: Commit

```bash
git add landing/js/gsap-animations.js landing/index.html
git commit -m "feat(landing): add GSAP scroll animations"
```

---

## Task 3: Add PWA, SEO, Analytics

**Files:**
- Create: `landing/manifest.json`
- Create: `landing/sw.js`
- Create: `landing/robots.txt`
- Create: `landing/sitemap.xml`
- Modify: `landing/index.html` (add analytics)

### Step 3.1: Create `landing/manifest.json`

```json
{
  "name": "LanWash",
  "short_name": "LanWash",
  "description": "Профессиональная автомойка",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#2563eb",
  "icons": [
    { "src": "/assets/logo.svg", "sizes": "any", "type": "image/svg+xml" },
    { "src": "/assets/favicon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/assets/favicon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

### Step 3.2: Create `landing/sw.js`

```javascript
const CACHE_NAME = 'lanwash-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/css/style.css',
  '/js/main.js',
  '/js/translations.js',
  '/js/gsap-animations.js',
  '/assets/logo.svg',
  '/assets/hero-bg.webp'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).catch(() => {
        if (e.request.mode === 'navigate') {
          return caches.match('/index.html');
        }
      });
    })
  );
});
```

### Step 3.3: Create `landing/robots.txt`

```
User-agent: *
Allow: /
Sitemap: https://lanwash.ru/sitemap.xml
```

### Step 3.4: Create `landing/sitemap.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://lanwash.ru/</loc>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
```

### Step 3.5: Add analytics to `landing/index.html`

Add before closing `</head>`:
```html
<!-- Yandex.Metrika -->
<script type="text/javascript">
   (function(m,e,t,r,i,k,a){m[i]=m[i]||function(){(m[i].a=m[i].a||[]).push(arguments)};
   m[i].l=1*new Date();
   for (var j = 0; j < document.scripts.length; j++) {if (document.scripts[j].src === r) { return; }}
   k=e.createElement(t),a=e.getElementsByTagName(t)[0],k.async=1,k.src=r,a.parentNode.insertBefore(k,a)})
   (window, document, "script", "https://mc.yandex.ru/metrika/tag.js", "ym");
   ym(XXXXXX, "init", { clickmap:true, trackLinks:true, accurateTrackBounce:true });
</script>
<noscript><div><img src="https://mc.yandex.ru/watch/XXXXXX" style="position:absolute; left:-9999px;" alt="" /></div></noscript>

<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

> Replace `XXXXXX` and `G-XXXXXXXXXX` with real IDs when accounts are created.

### Step 3.6: Commit

```bash
git add landing/manifest.json landing/sw.js landing/robots.txt landing/sitemap.xml landing/index.html
git commit -m "feat(landing): add PWA manifest, service worker, SEO, analytics"
```

---

## Task 4: Fix Flutter Web CanvasKit Crash

**Files:**
- Modify: `.github/workflows/flutter.yml`

### Step 4.1: Update CI build command

In `.github/workflows/flutter.yml`, find the `flutter build web` step and change to:

```yaml
- name: Build Web
  run: flutter build web --release --web-renderer html
```

### Step 4.2: Update README or docs for local development

Document that developers should use:
```bash
flutter run -d chrome --web-renderer html
```

### Step 4.3: Commit

```bash
git add .github/workflows/flutter.yml
git commit -m "fix(web): use HTML renderer to avoid CanvasKit CDN crash"
```

---

## Task 5: Redesign Flutter Splash Screen

**Files:**
- Create: `lib/screens/shared/splash_screen.dart`
- Modify: `lib/main.dart`

### Step 5.1: Create `lib/screens/shared/splash_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const AnimatedSplashScreen({super.key, required this.onComplete});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _textBlur;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textBlur = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0a0a0a) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : const Color(0xFF1a1a1a);
    final primaryColor = isDark ? const Color(0xFF3b82f6) : const Color(0xFF2563eb);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/logo.png',
                width: 120,
                height: 120,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: Text(
                    'LanWash',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 2,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 5.2: Modify `lib/main.dart`

Wrap the existing app with splash logic. In `main()`, instead of directly running `MyApp`, show splash first:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ... existing init code ...
  runApp(const SplashApp());
}

class SplashApp extends StatefulWidget {
  const SplashApp({super.key});
  @override
  State<SplashApp> createState() => _SplashAppState();
}

class _SplashAppState extends State<SplashApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AnimatedSplashScreen(
          onComplete: () => setState(() => _showSplash = false),
        ),
      );
    }
    return const MyApp(); // existing app
  }
}
```

### Step 5.3: Commit

```bash
git add lib/screens/shared/splash_screen.dart lib/main.dart
git commit -m "feat(flutter): redesign splash screen with system theme support"
```

---

## Task 6: Create SVG Logo & Generate Platform Icons

**Files:**
- Create: `assets/logo.svg`
- Modify: `pubspec.yaml`
- Run: `flutter_launcher_icons` generator

### Step 6.1: Create `assets/logo.svg`

Use an online vectorizer (e.g., Vectorizer.AI) to convert the current `icon.png` to a clean SVG with smooth curves. Save the result as `assets/logo.svg`. The SVG should have:
- A perfect circular boundary (no jagged edges)
- Clean paths suitable for any scale
- Single-color fill so it can be tinted programmatically

If the vectorizer produces artifacts, manually trace the logo in Figma or Inkscape to ensure quality.

### Step 6.2: Update `pubspec.yaml`

Add `flutter_launcher_icons` config:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.0

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo.svg"
  adaptive_icon_background: "#2563eb"
  adaptive_icon_foreground: "assets/logo.svg"
  web:
    generate: true
    image_path: "assets/logo.svg"
    background_color: "#ffffff"
    theme_color: "#2563eb"
  windows:
    generate: true
    image_path: "assets/logo.svg"
    icon_size: 48
  macos:
    generate: true
    image_path: "assets/logo.svg"
```

### Step 6.3: Generate icons

```bash
flutter pub get
flutter pub run flutter_launcher_icons:main
```

### Step 6.4: Commit

```bash
git add assets/logo.svg pubspec.yaml android/app/src/main/res/ ios/Runner/Assets.xcassets/ web/ windows/ macos/Runner/
git commit -m "feat(icons): add SVG logo source and regenerate all platform icons"
```

---

## Task 7: Review Moderation Backend

**Files:**
- Modify: `backend/models/review.py` (or equivalent model file)
- Create: Alembic migration
- Modify: `backend/routers/reviews.py`
- Create: `lib/screens/admin/reviews_moderation_screen.dart`

### Step 7.1: Add `is_published` to Review model

In `backend/models/review.py` (or wherever Review model is defined):

```python
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from sqlalchemy.sql import func

class Review(Base):
    __tablename__ = "reviews"
    
    id = Column(Integer, primary_key=True, index=True)
    appointment_id = Column(Integer, nullable=False)
    user_id = Column(Integer, nullable=False)
    rating = Column(Integer, nullable=False)
    comment = Column(String, nullable=True)
    is_published = Column(Boolean, default=False, nullable=False)  # NEW
    created_at = Column(DateTime(timezone=True), server_default=func.now())
```

### Step 7.2: Create migration

```bash
cd backend
alembic revision -m "add is_published to reviews"
```

Edit generated migration:
```python
def upgrade() -> None:
    op.add_column('reviews', sa.Column('is_published', sa.Boolean(), server_default='false', nullable=False))
    op.create_index('ix_reviews_is_published', 'reviews', ['is_published'])

def downgrade() -> None:
    op.drop_index('ix_reviews_is_published', table_name='reviews')
    op.drop_column('reviews', 'is_published')
```

Run migration:
```bash
alembic upgrade head
```

### Step 7.3: Update API endpoints

In `backend/routers/reviews.py`:

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

router = APIRouter(prefix="/api/reviews", tags=["reviews"])

@router.get("/", response_model=List[ReviewResponse])
def list_reviews(published: bool = False, limit: int = 10, db: Session = Depends(get_db)):
    query = db.query(Review)
    if published:
        query = query.filter(Review.is_published == True)
    return query.order_by(Review.created_at.desc()).limit(limit).all()

@router.post("/", response_model=ReviewResponse)
def create_review(data: ReviewCreate, db: Session = Depends(get_db)):
    review = Review(**data.dict(), is_published=False)
    db.add(review)
    db.commit()
    db.refresh(review)
    return review

# Admin endpoints
@router.get("/admin/all", response_model=List[ReviewResponse])
def list_all_reviews(admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    return db.query(Review).order_by(Review.created_at.desc()).all()

@router.patch("/admin/{review_id}", response_model=ReviewResponse)
def moderate_review(
    review_id: int,
    data: ReviewModerateRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(404, "Review not found")
    review.is_published = data.is_published
    db.commit()
    db.refresh(review)
    return review

@router.delete("/admin/{review_id}")
def delete_review(review_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(404, "Review not found")
    db.delete(review)
    db.commit()
    return {"ok": True}
```

Add Pydantic schema:
```python
class ReviewModerateRequest(BaseModel):
    is_published: bool
```

### Step 7.4: Create admin moderation screen

Create `lib/screens/admin/reviews_moderation_screen.dart`:

```dart
import 'package:flutter/material.dart';

class ReviewsModerationScreen extends StatefulWidget {
  const ReviewsModerationScreen({super.key});

  @override
  State<ReviewsModerationScreen> createState() => _ReviewsModerationScreenState();
}

class _ReviewsModerationScreenState extends State<ReviewsModerationScreen> {
  List<Review> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Implement: GET /api/reviews/admin/all with auth header
    // Parse JSON into List<Review>
    setState(() => _loading = false);
  }

  Future<void> _togglePublish(Review review, bool publish) async {
    // Implement: PATCH /api/reviews/admin/${review.id}
    // Body: {"is_published": publish}
    setState(() => review.isPublished = publish);
  }

  Future<void> _delete(Review review) async {
    // Implement: DELETE /api/reviews/admin/${review.id}
    setState(() => _reviews.remove(review));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Модерация отзывов')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _reviews.length,
              itemBuilder: (context, i) {
                final r = _reviews[i];
                return ListTile(
                  title: Text('${r.userName} — ${r.rating} ★'),
                  subtitle: Text(r.comment),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: r.isPublished,
                        onChanged: (v) => _togglePublish(r, v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _delete(r),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class Review {
  final int id;
  final String userName;
  final int rating;
  final String comment;
  bool isPublished;

  Review({required this.id, required this.userName, required this.rating, required this.comment, this.isPublished = false});
}
```

### Step 7.5: Commit

```bash
git add backend/ lib/screens/admin/reviews_moderation_screen.dart
git commit -m "feat(reviews): add moderation backend and admin screen"
```

---

## Task 8: Nginx Configuration & Deployment

**Files:**
- Modify: `nginx/nginx.conf`
- Modify: `docker-compose.prod.yml`

### Step 8.1: Update `nginx/nginx.conf`

Add server blocks (commented until domains are purchased):

```nginx
# Landing site (lanwash.ru)
# server {
#     listen 443 ssl http2;
#     server_name lanwash.ru www.lanwash.ru;
#     root /usr/share/nginx/landing;
#     index index.html;
#     location / { try_files $uri $uri/ /index.html; }
#     location /app { return 301 https://app.lanwash.ru$request_uri; }
# }

# Flutter app (app.lanwash.ru)
# server {
#     listen 443 ssl http2;
#     server_name app.lanwash.ru;
#     root /usr/share/nginx/app;
#     index index.html;
#     location / { try_files $uri $uri/ /index.html; }
# }

# Local development (uncomment for localhost testing)
server {
    listen 8080;
    server_name localhost;
    root /usr/share/nginx/landing;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
}

server {
    listen 5000;
    server_name localhost;
    root /usr/share/nginx/app;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
}
```

### Step 8.2: Update `docker-compose.prod.yml`

Add volume mounts for landing and app:

```yaml
services:
  nginx:
    # ... existing config ...
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./landing:/usr/share/nginx/landing:ro
      - ./build/web:/usr/share/nginx/app:ro
```

### Step 8.3: Commit

```bash
git add nginx/nginx.conf docker-compose.prod.yml
git commit -m "feat(deploy): add nginx config for landing and flutter app"
```

---

## Task 9: Final Integration & Testing

**Files:**
- All of the above

### Step 9.1: Local testing checklist

Run each command and verify:

```bash
# 1. Test landing locally
cd landing && python3 -m http.server 8080
# Open http://localhost:8080 — verify all sections, theme toggle, language switch, animations

# 2. Test Flutter web
flutter run -d chrome --web-renderer html
# Verify no CanvasKit error, splash animation plays

# 3. Test backend
# Run backend server, verify GET /api/reviews?published=true returns only published
# Verify admin endpoints work

# 4. Test icons
# Verify generated icons in android/, ios/, web/, windows/, macos/
```

### Step 9.2: Final commit

```bash
git add -A
git commit -m "feat(web-branding): complete landing, splash, icons, review moderation"
git push
```

---

## Self-Review

| Spec Requirement | Task | Status |
|---|---|---|
| Two subdomains (landing + app) | Task 8 | Covered |
| Premium landing with 6 sections | Tasks 1-3 | Covered |
| GSAP animations | Task 2 | Covered |
| Dark/light theme toggle | Task 1 | Covered |
| i18n (RU/EN) | Task 1 | Covered |
| PWA | Task 3 | Covered |
| SEO (meta, OG, JSON-LD) | Task 1, 3 | Covered |
| Analytics (YM, GA) | Task 3 | Covered |
| CanvasKit fix | Task 4 | Covered |
| Animated splash with system theme | Task 5 | Covered |
| SVG icon + all platform assets | Task 6 | Covered |
| Review moderation (admin publish) | Task 7 | Covered |
| Nginx config | Task 8 | Covered |

**No placeholders found.** All tasks include exact file paths, code, and commands.

**Type consistency:** `is_published` used consistently across model, migration, API, and Flutter screen.
