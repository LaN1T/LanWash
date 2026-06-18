# Firebase Hardening — API Key Restrictions & App Check

Этот документ описывает, как защитить Firebase-проект LanWash от злоупотреблений.

---

## 1. API Key Restrictions

API keys видны в клиентском коде (`android/app/google-services.json`, `lib/firebase_options.dart`). Без ограничений любой может использовать их для вызовов Firebase API.

### Шаги

1. Открой [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → APIs & Services → Credentials.
2. Найди API keys с названиями похожими на `Android key (auto created by Firebase)`, `iOS key`, `Browser key`.
3. Для каждого ключа нажми **Edit** и настрой ограничения:

#### Android key
- **Application restrictions** → `Android apps`
- Добавь package name: `com.example.lanwash`
- Добавь SHA-1 (debug и release):
  ```bash
  # Debug SHA-1
  cd android && ./gradlew signingReport
  ```
- **API restrictions** → `Restrict key` → выбери только:
  - Firebase Cloud Messaging API
  - Firebase Installations API

#### iOS key
- **Application restrictions** → `iOS apps`
- Добавь bundle ID: `com.example.lanwash`
- **API restrictions** → `Restrict key` → выбери только:
  - Firebase Cloud Messaging API
  - Firebase Installations API

#### Web key (если используешь Flutter web)
- **Application restrictions** → `HTTP referrers (web sites)`
- Добавь домены: `localhost`, `your-domain.com/*`
- **API restrictions** → `Restrict key` → выбери только нужные API

---

## 2. App Check

App Check защищает Firebase сервисы (FCM) от вызовов с неавторизованных клиентов.

### Firebase Console — включение

1. Открой [Firebase Console](https://console.firebase.google.com/) → Project Settings → App Check.
2. Для **Android**:
   - Выбери `Play Integrity API` (рекомендуется) или `SafetyNet` (deprecated).
   - Если у тебя ещё нет Play Integrity API key — следуй [инструкции Google](https://developer.android.com/google/play/integrity/setup).
   - В development используется `Debug provider` — смотри раздел ниже.
3. Для **iOS**:
   - Выбери `DeviceCheck`.
   - Загрузи private key (получаешь в Apple Developer Portal).
   - В development используется `Debug provider`.
4. Для **Web**:
   - Выбери `reCAPTCHA v3`.
   - Создай site key в [reCAPTCHA Admin Console](https://www.google.com/recaptcha/admin).
   - Вставь site key в `lib/main.dart` в `webProvider`.

### Debug tokens (development)

В debug-режиме App Check использует debug tokens вместо настоящих проверок.

1. Запусти приложение на эмуляторе/симуляторе.
2. В логах поищи строку:
   ```
   D/FirebaseAppCheck: Enter this debug secret into the allow list in the Firebase Console:
   <your-debug-token>
   ```
3. Открой Firebase Console → App Check → Manage debug tokens → Add token.
4. Вставь скопированный token и сохрани.

### Backend — включение enforcement

По умолчанию backend **не требует** App Check token (`APP_CHECK_ENFORCED=false`).

Чтобы включить в production:

1. В `backend/.env` установи:
   ```
   APP_CHECK_ENFORCED=true
   ```
2. Перезапусти backend.
3. **Важно:** Flutter-клиент должен отправлять `X-Firebase-AppCheck` header с каждым запросом. Если включишь enforcement — нужно будет добавить это в `ApiClient`.

> **Совет:** не включай `APP_CHECK_ENFORCED` пока не протестируешь полный цикл с production build на реальном устройстве.

---

## 3. Проверка

После настройки:

1. Собери release APK/IPA.
2. Установи на реальное устройство (эмулятор не подойдёт для Play Integrity).
3. Проверь что push-уведомления приходят.
4. В Firebase Console → App Check → Metrics должны появиться графики verified vs unverified requests.

---

## 4. Что уже сделано в коде

- ✅ `firebase_app_check` добавлен в `pubspec.yaml`
- ✅ App Check инициализируется в `lib/main.dart`:
  - Debug providers в development
  - Play Integrity / DeviceCheck в release
- ✅ Backend middleware для проверки App Check token (`backend/core/app_check.py`)
- ✅ `APP_CHECK_ENFORCED` env variable в `backend/.env.example`
