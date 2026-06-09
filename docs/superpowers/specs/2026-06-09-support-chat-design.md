# Support Chat with AI Draft Replies — Design Spec

## Goal
Add a customer support chat inside the Flutter app with AI-assisted replies. Clients write from the mobile app, admins reply from the admin panel. Simple FAQ questions (prices, working hours, how to book) are answered automatically by a free Gemini model. For complex cases the admin sees a "Generate AI reply" button, edits the draft, and sends it.

## Current State
- Flutter app has separate client and admin flows
- FastAPI backend with JWT auth, role checks, rate limiting
- `FcmToken` table stores encrypted push tokens
- `User` table distinguishes `client`, `admin`, `washer`
- `Appointment` table stores client booking history
- No messaging or chat infrastructure exists

## Missing
- Chat data model and messages API
- WebSocket endpoint for live message delivery
- Gemini integration for FAQ auto-replies and admin drafts
- Admin UI for ticket list and conversation
- Client UI for support chat
- Push notifications for new messages

## Architecture

**Data flow:**
1. Client opens support screen and sends first message
2. Backend creates `SupportChat` + `SupportMessage`
3. Backend calls `ai_draft_service.classify_and_reply()`
4. If Gemini returns a direct answer → save as `senderRole='ai'`, set status `ai_handled`
5. If Gemini returns `ADMIN_NEEDED` → set status `waiting_admin`, push admins
6. Admin opens chat list, sees new chat with unread badge
7. Admin taps 🤖 → backend generates draft with context → admin edits/sends
8. On send backend broadcasts via WebSocket to everyone in this chat and pushes the client

**Transport:**
- HTTP REST for lists, history, sending, AI draft generation
- WebSocket `/ws/support/chats/{chat_id}` for live delivery while chat is open
- Polling as fallback when app returns from background or WS is disconnected

## Components

### Backend

**File:** `backend/db_models.py`
- `SupportChat` table
- `SupportMessage` table

**File:** `backend/models.py`
- `SupportChatCreateRequest`, `SupportMessageCreateRequest`
- `SupportChatResponse`, `SupportMessageResponse`
- `AiDraftRequest`, `AiDraftResponse`

**File:** `backend/routers/support.py`
- Client endpoints under `/api/support/chats/*`
- Admin endpoints under `/api/support/chats/*` with `check_roles(['admin'])`
- Rate limits applied via `core.limiter`

**File:** `backend/services/ai_draft_service.py`
- `classify_and_reply(chat, messages, context)` → direct answer or `ADMIN_NEEDED`
- `generate_admin_draft(chat, messages, context)` → draft text for admin
- Uses `google-generativeai` library with `gemini-1.5-flash`

**File:** `backend/main.py`
- Register `support` router
- Register WebSocket endpoint `/ws/support/chats/{chat_id}`

**File:** `backend/alembic/versions/2026_06_09_add_support_chat.py`
- Migration for new tables

### Frontend

**File:** `lib/models/support_chat.dart`, `lib/models/support_message.dart`
- Dart models with `fromMap` / `toMap`

**File:** `lib/services/api_service.dart`
- `createSupportChat`, `getMySupportChats`
- `getSupportMessages`, `sendSupportMessage`
- `generateAiDraft`, `markChatRead`, `assignChat`, `closeChat`

**File:** `lib/providers/support_provider.dart`
- Ticket/message list state
- Unread count
- WebSocket management

**File:** `lib/screens/admin/support_tickets_screen.dart`
- Chat list with filters and unread badges

**File:** `lib/screens/admin/support_chat_screen.dart`
- Conversation with AI draft card and quick replies

**File:** `lib/screens/client/support_chats_screen.dart`
- Client chat list

**File:** `lib/screens/client/support_chat_screen.dart`
- Client conversation view

**File:** `lib/screens/admin/home_shell.dart`
- Add "Поддержка" drawer item with badge

**File:** `lib/services/notification_service.dart`
- Handle `support_chat` push payload

## Data Model

```python
class SupportChat(Base):
    __tablename__ = 'support_chats'
    id = Column(Integer, primary_key=True, autoincrement=True)
    userId = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    status = Column(String, nullable=False, default='open')
        # open | ai_handled | waiting_admin | admin_assigned | closed
    assignedAdminId = Column(Integer, ForeignKey('users.id'), nullable=True)
    unreadByUser = Column(Integer, nullable=False, default=0)
    unreadByAdmin = Column(Integer, nullable=False, default=0)
    lastMessageAt = Column(String, nullable=True)
    createdAt = Column(String, nullable=False)
    updatedAt = Column(String, nullable=False)

class SupportMessage(Base):
    __tablename__ = 'support_messages'
    id = Column(Integer, primary_key=True, autoincrement=True)
    chatId = Column(Integer, ForeignKey('support_chats.id', ondelete='CASCADE'), nullable=False)
    senderRole = Column(String, nullable=False)  # client | admin | ai
    senderId = Column(Integer, ForeignKey('users.id'), nullable=True)
    content = Column(String, nullable=False)
    isAiDraft = Column(Integer, nullable=False, default=0)
    createdAt = Column(String, nullable=False)
```

## API Endpoints

### Client

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/api/support/chats` | client | Create chat with first message |
| `GET` | `/api/support/chats/my` | client | List my chats |
| `GET` | `/api/support/chats/{id}/messages` | client | Get messages |
| `POST` | `/api/support/chats/{id}/messages` | client | Send message |
| `POST` | `/api/support/chats/{id}/read` | client | Mark read by user |

### Admin

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/api/support/chats` | admin | List all chats with `?status=` filter |
| `GET` | `/api/support/chats/{id}/messages` | admin | Get messages |
| `POST` | `/api/support/chats/{id}/messages` | admin | Reply |
| `POST` | `/api/support/chats/{id}/ai-draft` | admin | Generate AI draft |
| `POST` | `/api/support/chats/{id}/assign` | admin | Take chat |
| `POST` | `/api/support/chats/{id}/close` | admin | Close chat |
| `POST` | `/api/support/chats/{id}/read` | admin | Mark read by admin |

### WebSocket

| Endpoint | Auth |
|---|---|
| `WS /ws/support/chats/{chat_id}?token=JWT` | JWT in query string |

**Server → Client events:**
- `new_message` — новое сообщение в чате
- `status_update` — изменился статус или назначенный админ
- `ping` / `pong` — heartbeat каждые 30 сек
- `error` — ошибка соединения

## AI Logic

### FAQ Auto-Reply

System prompt:
```
Ты — ассистент автомойки LanWash.
Если вопрос клиента можно ответить по FAQ — дай краткий вежливый ответ.
Если вопрос требует администратора (жалоба, конкретная ситуация с записью, просьба перенести/отменить) — ответь только: ADMIN_NEEDED

FAQ:
- Экспресс-мойка: 500₽, 15 минут
- Стандартная мойка: 800₽, 30 минут
- Комплексная: 1500₽, 60 минут
- Премиум: 2500₽, 90 минут
- Работаем с 8:00 до 22:00 без выходных
- Записаться можно в приложении в разделе "Запись"
```

### Admin Draft

Context includes:
- Last 10 messages
- Client profile (name, car model, phone)
- Last 5 appointments
- FAQ list

Prompt:
```
Ты — опытный администратор автомойки LanWash.
Напиши вежливый, профессиональный ответ клиенту.
Будь кратким (не более 3-4 предложений).
Если не хватает информации — предложи клиенту уточнить детали.
```

### Rate limits

- `POST /chats` — `10/minute`
- `POST /messages` — `30/minute`
- `POST /ai-draft` — `20/minute`
- `GET /chats` — `60/minute`

## Notifications

| Event | Recipient | Channel | Payload |
|---|---|---|---|
| Client wrote, AI routed to admin | All admins | FCM | `{"type": "support_chat", "chat_id": "7"}` |
| Admin replied | Client | FCM | `{"type": "support_chat", "chat_id": "7"}` |
| Chat assigned | Assigned admin | FCM | `{"type": "support_chat", "chat_id": "7"}` |
| AI auto-replied | — | none | — |

If an admin is currently connected to this chat via WebSocket, the FCM push is skipped for that admin.

## UI/UX

### Admin

**Drawer item:**
- Icon `Icons.support_agent`
- Red badge with `unreadByAdmin` count
- Label "Поддержка"

**Chat list screen:**
- Filter tabs: Все / Новые / В работе / Закрыты
- Each row: client name, last message preview, time, status badge, unread dot
- Pull-to-refresh + 10s polling

**Chat screen:**
- Bubble messages (client left/gray, admin right/blue, AI left/purple)
- Bottom bar: [🤖 AI] [⚡ Quick reply] [Text field] [Send]
- AI draft card appears above input with Edit / Send buttons
- AppBar actions: Assign to me / Close chat / Client info

### Client

**Entry point:**
- Drawer/BottomNav item or Profile button "Чат с поддержкой"

**Chat list:**
- Own chats + "Написать в поддержку" button
- Unread badge

**Chat screen:**
- Same bubble style without admin controls
- WebSocket connect when open

## Testing

**Backend:** `backend/tests/test_support.py`
- Create chat as client
- List chats with role access checks
- Send message and unread counter update
- FAQ auto-reply with mocked Gemini returning direct answer
- `ADMIN_NEEDED` routing with mocked Gemini
- AI draft generation endpoint
- Admin reply triggers FCM mock
- WebSocket auth and broadcast

**Frontend:**
- Unit tests for `SupportChat.fromMap` / `SupportMessage.fromMap`
- Widget test for chat list with unread badge
- Widget test for AI draft card

**Manual:**
1. Client asks price → AI replies automatically
2. Client says "want to complain" → admin gets push
3. Admin generates draft, edits, sends → client receives push
4. Two devices in same chat → WS delivers instantly

## Future Improvements

- Telegram bot channel for clients without the app
- Redis Pub/Sub for multi-instance WebSocket broadcast
- Admin typing indicator
- File attachments (photos of defects)
- AI confidence scoring and analytics dashboard
- Quick-reply templates configurable by admin

## Self-Review

- [x] No placeholders
- [x] Builds on existing auth, FCM, and admin navigation
- [x] Clear separation: REST + WS + AI service
- [x] Gemini free tier fits expected support volume
- [x] Testable with mocked AI responses
