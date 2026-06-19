import { create } from 'zustand'

interface User {
  id: number
  username: string
  role: string
  displayName: string
  phone: string
  carModel: string
  carNumber: string
  avatarUrl: string
}

interface AuthState {
  user: User | null
  token: string | null
  isLoading: boolean
  setAuth: (user: User, token: string) => void
  setLoading: (loading: boolean) => void
  logout: () => void
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  isLoading: true,
  setAuth: (user, token) => {
    set({ user, token, isLoading: false })
  },
  setLoading: (loading) => set({ isLoading: loading }),
  logout: () => {
    set({ user: null, token: null })
  },
}))