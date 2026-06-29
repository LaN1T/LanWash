import { api } from './api'

export interface AuthResponse {
  user: {
    id: number
    username: string
    role: string
    displayName: string
    phone: string
    carModel: string
    carNumber: string
    avatarUrl: string
    telegramLinked?: boolean
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

export async function telegramAuth(initData: string): Promise<AuthResponse> {
  const res = await api.post('/auth/telegram', { initData })
  return res.data
}

export async function linkTelegram(
  initData: string,
  username: string,
  password: string
): Promise<AuthResponse> {
  const res = await api.post('/auth/link-telegram', { initData, username, password })
  return res.data
}

export async function registerTelegram(
  initData: string,
  data: RegisterData
): Promise<AuthResponse> {
  const res = await api.post('/auth/telegram-register', { initData, ...data })
  return res.data
}

export async function logoutBackend(token: string): Promise<void> {
  await api.post('/auth/logout', {}, { headers: { Authorization: `Bearer ${token}` } })
}
