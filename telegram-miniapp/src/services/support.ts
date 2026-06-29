import { api } from './api'

export interface SupportChat {
  id: number
  userId: number
  userName: string
  userPhone?: string | null
  status: string
  assignedAdminId?: number | null
  assignedAdminName?: string | null
  unreadByUser: number
  unreadByAdmin: number
  lastMessageAt?: string | null
  lastMessagePreview?: string | null
  createdAt: string
}

export interface SupportMessage {
  id: number
  chatId: number
  senderRole: string
  senderId?: number | null
  senderName?: string | null
  content: string
  isAiDraft: boolean
  createdAt: string
}

export interface AiDraft {
  draft?: string | null
}

export interface CreateChatPayload {
  firstMessage?: string
}

export interface SendMessagePayload {
  content: string
  isAiDraft?: boolean
}

function isSupportChat(value: unknown): value is SupportChat {
  if (typeof value !== 'object' || value === null) return false
  const c = value as Record<string, unknown>

  return (
    typeof c.id === 'number' &&
    typeof c.userId === 'number' &&
    typeof c.userName === 'string' &&
    typeof c.status === 'string' &&
    typeof c.unreadByUser === 'number' &&
    typeof c.unreadByAdmin === 'number' &&
    typeof c.createdAt === 'string'
  )
}

function isSupportChatArray(value: unknown): value is SupportChat[] {
  return Array.isArray(value) && value.every(isSupportChat)
}

export function isSupportMessage(value: unknown): value is SupportMessage {
  if (typeof value !== 'object' || value === null) return false
  const m = value as Record<string, unknown>

  return (
    typeof m.id === 'number' &&
    typeof m.chatId === 'number' &&
    typeof m.senderRole === 'string' &&
    typeof m.content === 'string' &&
    typeof m.isAiDraft === 'boolean' &&
    typeof m.createdAt === 'string'
  )
}

function isSupportMessageArray(value: unknown): value is SupportMessage[] {
  return Array.isArray(value) && value.every(isSupportMessage)
}

export async function createChat(payload: CreateChatPayload = {}): Promise<SupportChat> {
  const res = await api.post('/support/chats', payload)
  if (!isSupportChat(res.data)) {
    throw new Error('Invalid support chat response')
  }
  return res.data
}

export async function getMyChats(signal?: AbortSignal): Promise<SupportChat[]> {
  const res = await api.get('/support/chats/my', { signal })
  if (!isSupportChatArray(res.data)) {
    throw new Error('Invalid support chats response')
  }
  return res.data
}

export async function getAllChats(
  status?: string,
  signal?: AbortSignal,
): Promise<SupportChat[]> {
  const res = await api.get('/support/chats', { params: { status }, signal })
  if (!isSupportChatArray(res.data)) {
    throw new Error('Invalid support chats response')
  }
  return res.data
}

export async function getChatMessages(
  chatId: number,
  signal?: AbortSignal,
): Promise<SupportMessage[]> {
  const res = await api.get(`/support/chats/${chatId}/messages`, { signal })
  if (!isSupportMessageArray(res.data)) {
    throw new Error('Invalid support messages response')
  }
  return res.data
}

export async function sendMessage(
  chatId: number,
  payload: SendMessagePayload,
): Promise<SupportMessage> {
  const res = await api.post(`/support/chats/${chatId}/messages`, payload)
  if (!isSupportMessage(res.data)) {
    throw new Error('Invalid support message response')
  }
  return res.data
}

export async function generateAiDraft(chatId: number): Promise<AiDraft> {
  const res = await api.post(`/support/chats/${chatId}/ai-draft`)
  return res.data
}

export async function assignChat(chatId: number): Promise<unknown> {
  const res = await api.post(`/support/chats/${chatId}/assign`)
  return res.data
}

export async function closeChat(chatId: number): Promise<unknown> {
  const res = await api.post(`/support/chats/${chatId}/close`)
  return res.data
}

export async function markChatAsRead(chatId: number): Promise<unknown> {
  const res = await api.post(`/support/chats/${chatId}/read`)
  return res.data
}
