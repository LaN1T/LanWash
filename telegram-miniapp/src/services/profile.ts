import { api } from './api'
import { isValidUser } from './auth'
import type { User } from '../stores/authStore'

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

function isUserStats(obj: unknown): obj is UserStats {
  if (typeof obj !== 'object' || obj === null) {
    return false
  }
  const s = obj as Record<string, unknown>

  if (typeof s.totalAppointments !== 'number') return false
  if (typeof s.totalSpent !== 'number') return false
  if (typeof s.favoriteWashType !== 'string') return false
  if (typeof s.level !== 'string') return false
  if (typeof s.levelProgress !== 'number') return false
  if (typeof s.points !== 'number') return false

  return true
}

function isUnlinkResponse(obj: unknown): obj is { status: string } {
  if (typeof obj !== 'object' || obj === null) {
    return false
  }
  const d = obj as Record<string, unknown>

  if (typeof d.status !== 'string') return false

  return true
}

export async function updateProfile(
  userId: number,
  data: ProfileUpdatePayload
): Promise<User> {
  const res = await api.put(`/auth/profile/${userId}`, data)
  if (!isValidUser(res.data)) {
    throw new Error('Invalid user response from server')
  }
  return res.data
}

export async function getUserStats(username: string): Promise<UserStats> {
  const res = await api.get(`/auth/stats/${encodeURIComponent(username)}`)
  if (!isUserStats(res.data)) {
    throw new Error('Invalid stats response from server')
  }
  return res.data
}

export async function unlinkTelegram(password: string): Promise<{ status: string }> {
  const res = await api.post('/auth/unlink-telegram', { password })
  if (!isUnlinkResponse(res.data)) {
    throw new Error('Invalid unlink response from server')
  }
  return res.data
}
