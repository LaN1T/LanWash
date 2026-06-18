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
  }
  access_token: string
  token_type: string
}

export async function telegramAuth(initData: string): Promise<AuthResponse> {
  const res = await api.post('/auth/telegram', { initData })
  return res.data
}

export async function linkAccount(username: string, password: string): Promise<AuthResponse> {
  const res = await api.post('/auth/link-telegram', { username, password })
  return res.data
}