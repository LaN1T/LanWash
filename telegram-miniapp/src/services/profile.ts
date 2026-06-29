import { api } from './api'

export interface User {
  id: number
  username: string
  role: 'client' | 'washer' | 'admin'
  displayName: string
  phone: string
  email?: string
  carModel: string
  carNumber: string
  avatarUrl: string
  telegramLinked: boolean
}

export interface ProfileUpdatePayload {
  displayName?: string
  phone?: string
  email?: string
  carModel?: string
  carNumber?: string
  avatarUrl?: string
  currentPassword?: string
  newPassword?: string
}

export interface UserStats {
  totalAppointments: number
  totalSpent: number
  favoriteWashType: string
  level: string
  levelProgress: number
  points: number
}

export async function updateProfile(
  userId: number,
  data: ProfileUpdatePayload
): Promise<User> {
  const res = await api.put(`/auth/profile/${userId}`, data)
  return res.data as User
}

export async function getUserStats(username: string): Promise<UserStats> {
  const res = await api.get(`/auth/stats/${encodeURIComponent(username)}`)
  return res.data as UserStats
}

export async function unlinkTelegram(password: string): Promise<{ status: string }> {
  const res = await api.post('/auth/unlink-telegram', { password })
  return res.data as { status: string }
}
