# Production Prep Design — LanWash Flutter App

**Date:** 2026-06-06  
**Scope:** Car autocomplete, dark theme overhaul, performance optimization  
**Status:** Draft

---

## 1. Goal

Prepare the LanWash Flutter application for production by:
1. Adding an instant car brand/model autocomplete during booking.
2. Fixing dark mode across all screens (no light widgets, no lags).
3. Optimizing performance (reduce rebuilds, add `const`, clean stale code).

---

## 2. Car Brand/Model Autocomplete

### 2.1 Data Source
- **Approach:** Local JSON asset (`assets/data/car_catalog.json`).
- **Rationale:** Instant response, offline-capable, car data changes rarely.
- **Size estimate:** ~400 brands × ~15 models avg = ~6,000 entries → ~300–400 KB uncompressed JSON.
- **Format:**
  ```json
  [
    {
      "brand": "Toyota",
      "models": ["Camry", "Corolla", "RAV4", "Land Cruiser", "Prius", ...]
    },
    ...
  ]
  ```

### 2.2 Data Loading
- `CarCatalogService` loads JSON once on first access, parses into:
  ```dart
  class CarBrand {
    final String name;
    final List<String> models;
  }
  ```
- Keeps two sorted `List<String>` in memory: `allBrands` and `modelsByBrand`.
- Search uses prefix filter (`where((s) => s.toLowerCase().startsWith(query))`) — O(n) on ~6K strings is trivial (<1ms).

### 2.3 UI/UX
- **Split single field into two fields** on booking screens:
  1. **Марка** — `Autocomplete<String>` with dropdown overlay. User types "to" → "Toyota".
  2. **Модель** — `Autocomplete<String>` enabled only after brand selected. User types "ca" → "Camry".
- Both fields keep existing transliteration helper (`applyTranslitEn`).
- Profile screen also updated to two fields (brand + model) for consistency with booking flow.
- Admin `AddEditAppointmentScreen` updated identically.

### 2.4 Backend Changes
- **None for the catalog itself** (data is local).
- Optional: add `carBrand` and `carModel` separate fields to backend `User` / `Appointment` models (currently only `carModel: String`).
  - If we split fields, we need a migration to parse existing `"Toyota Camry"` strings.
  - **Decision:** Keep backend `carModel` as single string for now, combine `brand + " " + model` client-side to avoid migration complexity. Revisit if analytics need separate brand/model grouping.

---

## 3. Dark Theme Overhaul

### 3.1 Cleanup
- **Delete stale duplicates:**
  - `lib/config/app_styles.dart` (older copy without adaptive helpers)
  - `lib/config/app_theme.dart` (unused light theme duplicate)
- **Fix `SystemUiOverlayStyle`:**
  - Remove hardcoded `statusBarIconBrightness: Brightness.dark` in `main.dart`.
  - Use `AnnotatedRegion<SystemUiOverlayStyle>` on each shell/screen or react to `ThemeProvider.themeMode` changes.

### 3.2 Systematic Color Migration
Replace in **all** screens (client + admin + shared + auth):

| Current (static/light) | Replacement (adaptive) |
|------------------------|------------------------|
| `AppStyles.cardDecoration` | `AppStyles.cardDecorationFor(context)` |
| `AppStyles.inputDecoration(...)` | `AppStyles.inputDecorationFor(context, ...)` |
| `AppStyles.textPrimary` | `AppStyles.adaptiveTextPrimary(context)` |
| `AppStyles.textSecondary` | `AppStyles.adaptiveTextSecondary(context)` |
| `AppStyles.bgPage` | `AppStyles.adaptiveBgPage(context)` |
| `AppStyles.border` | `AppStyles.adaptiveBorder(context)` |
| `Colors.white` as background | `Theme.of(context).colorScheme.surface` or `AppStyles.adaptiveCard(context)` |
| `Colors.black.withOpacity(x)` | `Colors.black.withValues(alpha: x)` or theme-derived overlay |
| `Colors.grey[xxx]` | `Theme.of(context).colorScheme.onSurface.withValues(alpha: ...)` |

### 3.3 Deprecated API Migration
- Replace **all** `withOpacity()` calls with `withValues(alpha:)` across `lib/`.
- Target: ~80+ occurrences.

### 3.4 Known Style Bugs
- Fix `AppStyles.goldButton` — currently identical to `primaryButton` (copy-paste error). Change background to `AppStyles.gold`.
- Either use `darkGradient` or remove it if unused.

### 3.5 Priority Order
1. Client booking flow (`booking_wizard_screen`, `client_home`, `my_bookings`, `profile`) — highest user impact.
2. Client detail screens (`service_detail`, `promo_detail`, `appointment_detail`).
3. Auth screens (`login`, `register`).
4. Admin screens (`admin_schedule`, `appointments`, `add_edit_*`, `statistics`, `logs`, etc.).

---

## 4. Performance Optimization

### 4.1 Quick Wins
- **Add `const` constructors** wherever possible (`EdgeInsets`, `SizedBox`, `TextStyle`, `BoxDecoration`, widget subtrees that don’t depend on variables).
- **Remove duplicate style files** (see 3.1) — reduces binary size and confusion.
- **Replace `withOpacity` → `withValues`** — avoids deprecation overhead on Flutter 3.27+.

### 4.2 State Management
- **Split `AppProvider` god object** into domain-specific ChangeNotifiers:
  - `AppointmentProvider` — appointments, busy slots, pagination cache.
  - `CatalogProvider` — services, wash types, promos.
  - `NoteProvider` — notes + unread counts.
  - `FavoriteProvider` — favorites.
- **Benefit:** `notifyListeners()` only rebuilds widgets that care about that domain.
- **Migration strategy:** Extract each domain into a new provider file, keep `AppProvider` as a thin facade forwarding to sub-providers during transition, then update screens to watch specific providers.

### 4.3 API Layer
- **Keep `ApiService` as-is for now** — splitting into repositories is valuable but out of scope for this sprint. Focus on UI/UX and provider splitting.

### 4.4 Rendering
- Audit `ListView.builder` vs `ListView` — ensure heavy lists use `.builder`.
- Wrap expensive subtrees (charts, calendars) with `RepaintBoundary` if they repaint independently.

---

## 5. Testing Plan

- **Unit:** `CarCatalogService` parsing and search.
- **Widget:** Booking wizard — brand autocomplete interaction, model filtering by brand.
- **Golden/screenshot:** Dark mode snapshots of key screens (client home, booking wizard, admin schedule) to prevent regressions.
- **Existing tests:** Must continue passing after provider split (update `MultiProvider` in test wrappers).

---

## 6. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Splitting `AppProvider` breaks existing tests | Update `test/mocks.dart` and provider wrappers incrementally; run full test suite after each provider extraction. |
| Dark theme migration touches 30+ files | Do it screen-by-screen, commit per screen, use grep to verify zero remaining `AppStyles.cardDecoration` / `Colors.white` usages. |
| Car JSON grows large | Compress JSON if needed (gzip asset + decode at runtime). Current estimate is safe. |
| User is used to single "brand model" field | Keep placeholder hint showing combined format; two fields are clearer and enable autocomplete. |

---

## 7. Implementation Order (Recommended)

1. **Cleanup** — delete stale files, fix `SystemUiOverlayStyle`, migrate `withOpacity` globally.
2. **Dark theme client screens** — booking flow, home, profile, auth.
3. **Car autocomplete** — add JSON asset, service, widget, integrate into booking wizard + profile.
4. **Dark theme admin screens** — remaining admin UI.
5. **Provider split** — extract `AppointmentProvider`, `CatalogProvider`, etc.
6. **Polish & tests** — const audit, golden tests, full test run.
