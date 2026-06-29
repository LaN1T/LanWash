import { api } from './api'

export interface AuthResponse {
  user: {
    id: number
    username: string
    role: 'client' | 'washer' | 'admin'
    displayName: string
    phone: string
    carModel: string
    carNumber: string
    avatarUrl: string
    telegramLinked: boolean
  }
  access_token: string
  token_type: string
}

export interface RegisterData {
  username: string
  password: string
  displayName: string
  phone?: string
  carModel?: string
  carNumber?: string
  referralCode?: string
}

function isValidUser(obj: unknown): obj is AuthResponse['user'] {
  if (typeof obj !== 'object' || obj === null) {
    return false
  }
  const u = obj as Record<string, unknown>

  if (typeof u.id !== 'number') return false
  if (typeof u.username !== 'string') return false
  if (typeof u.displayName !== 'string') return false
  if (typeof u.phone !== 'string') return false
  if (typeof u.carModel !== 'string') return false
  if (typeof u.carNumber !== 'string') return false
  if (typeof u.avatarUrl !== 'string') return false
  if (typeof u.telegramLinked !== 'boolean') return false

  const role = u.role
  if (role !== 'client' && role !== 'washer' && role !== 'admin') {
    return false
  }

  return true
}

export function isAuthResponse(data: unknown): data is AuthResponse {
  if (typeof data !== 'object' || data === null) {
    return false
  }
  const d = data as Record<string, unknown>

  if (typeof d.access_token !== 'string') return false
  if (typeof d.token_type !== 'string') return false
  if (!isValidUser(d.user)) return false

  return true
}

function validateAuthResponse(data: unknown): AuthResponse {
  if (!isAuthResponse(data)) {
    throw new Error('Invalid auth response from server')
  }
  return data
}

export async function telegramAuth(initData: string): Promise<AuthResponse> {
  const res = await api.post('/auth/telegram', { initData })
  return validateAuthResponse(res.data)
}

export async function linkTelegram(
  initData: string,
  username: string,
  password: string
): Promise<AuthResponse> {
  const res = await api.post('/auth/link-telegram', { initData, username, password })
  return validateAuthResponse(res.data)
}

export async function registerTelegram(
  initData: string,
  data: RegisterData
): Promise<AuthResponse> {
  const res = await api.post('/auth/telegram-register', { initData, ...data })
  return validateAuthResponse(res.data)
}

export async function logoutBackend(): Promise<void> {
  await api.post('/auth/logout')
}
