# Web & Branding — Design Spec

## Status
Approved by user. Ready for implementation planning.

## Overview
Split the current single-domain Flutter web app into two independent experiences:
- **Landing site** (`lanwash.ru`) — premium static site with GSAP animations, theme toggle, PWA, analytics, i18n.
- **Flutter app** (`app.lanwash.ru`) — fixed web build, animated splash with system theme support, proper icons.

## Goals
1. Fix Flutter web CanvasKit CDN crash (site does not load at all).
2. Create a premium landing page that acts as the public face of the business.
3. Redesign splash screen with "wow" effect and system dark/light mode support.
4. Fix app icon (cropped PNG, wrong Android size) by creating an SVG source and generating all platform assets.
5. Add Telegram Bot link as an alternative booking channel.

## Non-Goals
- No CMS (content is static, updated via code deployment).
- No backend changes for landing (except CORS for reviews API).
- No in-app chat or Telegram bot implementation (out of scope for this block).

---

## 1. Architecture & Domains

```
┌─────────────────────────────────────────────────────────────┐
│                        Nginx (443)                          │
│  ┌─────────────────────┐    ┌─────────────────────────────┐ │
│  │   lanwash.ru        │    │   app.lanwash.ru            │ │
│  │   Landing (C)       │    │   Flutter Web (B)           │ │
│  │                     │    │                             │ │
│  │  Static files       │    │  build/web/                 │ │
│  │  (HTML/CSS/JS)      │    │  (index.html + assets)      │ │
│  └─────────────────────┘    └─────────────────────────────┘ │
│           │                            │                    │
│           ▼                            ▼                    │
│    Docker volume                Docker volume               │
│    /usr/share/nginx/landing     /usr/share/nginx/app       │
└─────────────────────────────────────────────────────────────┘
```

- Both subdomains are served by the same Nginx instance already running on the server.
- `lanwash.ru` serves static files directly (no Node.js server needed).
- `app.lanwash.ru` serves the output of `flutter build web`.
- A new `location` block in `nginx.conf` routes each subdomain to its folder.

---

## 2. Landing Site (`lanwash.ru`) — Premium (C)

### Tech Stack
- HTML5, CSS3 (vanilla, no frameworks)
- GSAP (GreenSock) for scroll animations and entrance effects
- Vanilla JS for theme toggle, language switcher, mobile menu
- Google Fonts (or self-hosted if we want zero external dependencies)

### Sections (top to bottom)

#### 2.1 Header (fixed)
- Logo (SVG, left)
- Navigation links: Услуги, Почему мы, Отзывы, Контакты (smooth scroll to sections)
- Theme toggle: 🌙 / ☀️ icon (persists choice in `localStorage`)
- Language switcher: RU / EN

#### 2.2 Hero
- Fullscreen background: high-quality photo of a car being washed (dark overlay ~60% opacity)
- Large heading: "LanWash" (semi-transparent, elegant)
- Subheading: "Профессиональный уход за вашим авто" / "Professional car care"
- CTA button: "Записаться" / "Book now" → links to `https://app.lanwash.ru`
- Below button: small text "Или запишитесь через Telegram Bot" with `t.me/lanwash_bot` link
- Entrance animation: heading fades in + slides up, subheading follows with 0.2s delay, button scales up from 0.8

#### 2.3 Services
- Heading: "Наши услуги" / "Our Services"
- 4-6 service cards in a responsive grid (1 col mobile, 2-3 col desktop)
- Each card: icon + title + short description + "от X руб."
- Scroll animation: cards fade in + slide up with stagger (0.1s between cards)

#### 2.4 Why Us
- Heading: "Почему мы" / "Why choose us"
- 4-5 benefit blocks with numbers/icons
- Examples: быстрота, качество, удобная запись, цена
- Scroll animation: left-side elements slide from left, right-side from right

#### 2.5 Reviews
- Heading: "Отзывы клиентов" / "Customer Reviews"
- Horizontal carousel (swipeable on mobile, arrows on desktop)
- Each review: avatar placeholder + name + star rating + text
- Data fetched dynamically from backend API: `GET /api/reviews?limit=10&public=true`
- If API fails → show static placeholder reviews (graceful degradation)
- Scroll animation: carousel fades in

#### 2.6 Contacts
- Heading: "Контакты" / "Contact us"
- Address, working hours
- Phone button: `<a href="tel:+7999...">Позвонить</a>`
- Telegram button: `<a href="https://t.me/lanwash_bot">Написать в Telegram</a>`
- Embedded map (Yandex Maps or Google Maps iframe)

#### 2.7 Footer
- Copyright: "© LanWash 2025"
- Link to privacy policy (static page or modal)
- Social links (if any)

### Dark/Light Theme
- CSS variables for all colors
- Default: follows `prefers-color-scheme`
- User toggle overrides and persists in `localStorage`
- Both themes must pass WCAG AA contrast

### i18n (RU / EN)
- All text stored in a JS object dictionary
- Language switcher in header
- Default: RU (detect from browser, fallback RU)
- Persist choice in `localStorage`

### SEO
- `<title>`: "LanWash — Профессиональная автомойка в [Город]"
- `<meta name="description">`
- Open Graph tags (`og:title`, `og:description`, `og:image`) for social sharing
- Structured data (JSON-LD): `LocalBusiness` schema with address, phone, hours
- Semantic HTML (`header`, `main`, `section`, `footer`, `nav`)
- Sitemap.xml + robots.txt

### Analytics
- Yandex.Metrika counter (async loading)
- Google Analytics 4 (gtag.js, async)
- Events tracked: "Book button click", "TG bot click", "Phone click", "Theme toggle", "Language switch"

### PWA
- `manifest.json`: name, icons, theme color, display mode (standalone)
- Service Worker: caches static assets, shows offline fallback page
- Icons: 192x192, 512x512 from SVG source

### Performance
- All images optimized (WebP with JPEG fallback)
- Lazy loading for below-fold images (`loading="lazy"`)
- CSS and JS minified for production
- Preconnect to Google Fonts / CDN if used

---

## 3. Flutter Web (`app.lanwash.ru`) — Standard (B)

### 3.1 CanvasKit Fix
**Problem:** `flutter run -d Chrome` fails with:
```
Error: TypeError: Failed to fetch dynamically imported module: https://www.gstatic.com/flutter-canvaskit/.../canvaskit.js
```
**Solution:** Build Flutter web with HTML renderer instead of CanvasKit.
- Development: `flutter run -d chrome --web-renderer html`
- Production: `flutter build web --release --web-renderer html`
- Update CI (`flutter.yml`) to use `--web-renderer html`
- This removes the external CDN dependency entirely.

### 3.2 Splash Screen Redesign
**Requirements:**
- System theme aware (light / dark)
- "Wow" effect: elegant, not overdone
- Duration: ~2.5 seconds total

**Design:**
- Background: white (`#FFFFFF`) for light mode, dark (`#121212`) for dark mode
- Center: SVG logo
  - Light mode: logo in primary brand color
  - Dark mode: logo in white/light tint
- Animation sequence (GSAP or Flutter animation):
  1. 0.0s — blank screen
  2. 0.5s — logo appears with scale from 0.6 to 1.0 + opacity 0 to 1 (ease-out, 0.8s)
  3. 1.3s — text "LanWash" fades in below logo with blur-to-sharp effect (0.6s)
  4. 2.2s — subtle shimmer/glow passes through logo (optional premium touch)
  5. 2.5s — cross-fade to app home screen

**Implementation note:** Since this is Flutter, the splash must be implemented in Dart (not HTML). Use `AnimatedBuilder` or `flutter_animate` package for the sequence. The system theme is read via `MediaQuery.platformBrightnessOf(context)` before `MaterialApp` builds.

### 3.3 App Icons & Branding
**Problem:** Current `icon.png` is poorly cropped, not a perfect circle, too large on Android.

**Solution:**
1. Vectorize current raster logo into SVG (using Vectorizer.AI or manual trace)
2. From SVG, generate all required assets:

| Platform | Sizes / Formats |
|----------|-----------------|
| Android | Adaptive icon: foreground 108×108dp (safe zone 66dp), background color. MDPI–XXXHDPI PNGs. |
| iOS | 20×20, 29×29, 40×40, 60×60, 76×76, 83.5×83.5, 1024×1024 (@1x, @2x, @3x) |
| Web | favicon.ico (16, 32), favicon-192.png, favicon-512.png, apple-touch-icon.png |
| Windows | 16, 32, 48, 256 px .ico |
| macOS | 16, 32, 64, 128, 256, 512, 1024 px |
| Linux | 128, 256, 512 px |

3. Update `pubspec.yaml` flutter_icons / flutter_launcher_icons config to point to the SVG source
4. Run generator to replace all platform assets

---

## 4. Deployment

### 4.1 Landing Site
- Source code in repo: `landing/` folder at project root
- Build: no build step (static files)
- Deploy: `rsync` or Docker volume mount to `/usr/share/nginx/landing`
- Nginx config:
```nginx
server {
    listen 443 ssl http2;
    server_name lanwash.ru www.lanwash.ru;
    root /usr/share/nginx/landing;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
    # redirect /app to app subdomain
    location /app { return 301 https://app.lanwash.ru$request_uri; }
}
```

### 4.2 Flutter Web
- Build: `flutter build web --release --web-renderer html`
- Deploy: output `build/web/` → `/usr/share/nginx/app`
- Nginx config:
```nginx
server {
    listen 443 ssl http2;
    server_name app.lanwash.ru;
    root /usr/share/nginx/app;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
}
```

### 4.3 CI/CD Updates
- `.github/workflows/flutter.yml`: add `--web-renderer html` to build step
- Add new workflow or step to deploy `landing/` folder on push

---

## 5. Data Flow

### Reviews API (landing → backend)
```
Landing page (JS fetch)
    → GET https://api.lanwash.ru/api/reviews?limit=10&public=true
    → Response: [{id, name, rating, comment, created_at}]
    → Render in carousel
```
- Backend endpoint must allow CORS from `lanwash.ru`
- Endpoint already exists (part of Reviews & Ratings block), but may need `public=true` filter

---

## 6. Error Handling

| Scenario | Handling |
|----------|----------|
| Reviews API fails | Show 3 static placeholder reviews, hide carousel arrows |
| Theme preference corrupted | Fallback to system preference |
| Language preference missing | Fallback to Russian |
| Flutter web offline | Standard browser offline page (handled by browser) |
| Landing offline | Service Worker shows cached version or offline fallback HTML |

---

## 7. Testing Checklist

- [ ] Landing loads in < 2s on 3G
- [ ] Theme toggle works and persists across reloads
- [ ] Language switcher works and persists
- [ ] All buttons (phone, TG, book) work on mobile
- [ ] Reviews carousel swipeable on mobile
- [ ] Flutter web loads without CanvasKit error
- [ ] Splash animation plays correctly in light and dark mode
- [ ] App icon looks correct on Android (adaptive), iOS, web favicon
- [ ] PWA install prompt appears on mobile
- [ ] Yandex.Metrika / GA4 events fire correctly
- [ ] Open Graph preview renders correctly in Telegram/VK

---

## 8. Open Questions / Future

- **Video background:** User explicitly rejected video in favor of photo. If we want video later, use a 5-10s compressed loop (H.264, <2MB) with `muted autoplay loop playsinline`.
- **Booking iframe:** Instead of redirecting to `app.lanwash.ru`, we could embed Flutter app in an iframe on landing. Out of scope for now.
- **CMS:** If content changes frequently, consider Strapi/WordPress headless later.

---

## 9. Files to Create / Modify

### New files
- `landing/index.html`
- `landing/css/style.css`
- `landing/js/main.js`
- `landing/js/translations.js`
- `landing/manifest.json`
- `landing/sw.js` (service worker)
- `landing/sitemap.xml`
- `landing/robots.txt`
- `landing/assets/logo.svg`
- `landing/assets/hero-bg.webp`
- `landing/assets/service-*.webp`
- `assets/logo.svg` (Flutter app SVG source)

### Modified files
- `macos/Podfile` (if icon generation touches macOS)
- `pubspec.yaml` (flutter_launcher_icons config)
- `web/index.html` (favicon, meta tags, PWA manifest link)
- `lib/main.dart` (splash screen logic)
- `nginx/nginx.conf` (new server blocks)
- `.github/workflows/flutter.yml` (add `--web-renderer html`)
- `docker-compose.prod.yml` (mount landing volume)
