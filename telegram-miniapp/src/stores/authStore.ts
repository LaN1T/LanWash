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
  error: string | null
  hydrated: boolean
  setAuth: (user: User, token: string) => Promise<void>
  setLoading: (loading: boolean) => void
  logout: () => Promise<void>
  clearError: () => void
  init: () => Promise<void>
}

const formatError = (err: unknown): string =>
  err instanceof Error ? err.message : 'Auth persistence error'

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  isLoading: true,
  error: null,
  hydrated: false,
  setAuth: async (user, token) => {
    try {
      await Promise.all([
        cloudStorage.setItem(cloudStorage.STORAGE_KEYS.USER, JSON.stringify(user)),
        cloudStorage.setItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN, token),
      ])
      set({ user, token, isLoading: false, error: null, hydrated: true })
    } catch (err) {
      set({ error: formatError(err), isLoading: false })
      throw err
    }
  },
  setLoading: (loading) => set({ isLoading: loading }),
  logout: async () => {
    try {
      await Promise.all([
        cloudStorage.removeItem(cloudStorage.STORAGE_KEYS.USER),
        cloudStorage.removeItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN),
      ])
      set({ user: null, token: null, isLoading: false, error: null })
    } catch (err) {
      set({ error: formatError(err), isLoading: false })
      throw err
    }
  },
  clearError: () => set({ error: null }),
  init: async () => {
    try {
      const [userRaw, token] = await Promise.all([
        cloudStorage.getItem(cloudStorage.STORAGE_KEYS.USER),
        cloudStorage.getItem(cloudStorage.STORAGE_KEYS.ACCESS_TOKEN),
      ])

      let user: User | null = null
      if (userRaw) {
        try {
          user = JSON.parse(userRaw) as User
        } catch {
          await cloudStorage.removeItem(cloudStorage.STORAGE_KEYS.USER)
          user = null
        }
      }

      set({ user, token, isLoading: false, error: null, hydrated: true })
    } catch (err) {
      set({ error: formatError(err), isLoading: false, hydrated: true })
    }
  },
}))
