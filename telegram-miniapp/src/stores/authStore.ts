import { create } from 'zustand'
import { cloudStorage } from '../lib/cloudStorage'

export interface User {
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

interface AuthState {
  user: User | null
  token: string | null
  isLoading: boolean
  setAuth: (user: User, token: string) => void
  setLoading: (loading: boolean) => void
  logout: () => void
  init: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  isLoading: true,
  setAuth: (user, token) => {
    set({ user, token, isLoading: false })
    cloudStorage.setItem(cloudStorage.STORAGE_KEYS.USER, JSON.stringify(user))
    cloudStorage.setItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN, token)
  },
  setLoading: (loading) => set({ isLoading: loading }),
  logout: () => {
    cloudStorage.removeItem(cloudStorage.STORAGE_KEYS.USER)
    cloudStorage.removeItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN)
    set({ user: null, token: null, isLoading: false })
  },
  init: async () => {
    try {
      const [userRaw, token] = await Promise.all([
        cloudStorage.getItem(cloudStorage.STORAGE_KEYS.USER),
        cloudStorage.getItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN),
      ])
      const user = userRaw ? JSON.parse(userRaw) : null
      set({ user, token, isLoading: false })
    } catch {
      set({ user: null, token: null, isLoading: false })
    }
  },
}))
