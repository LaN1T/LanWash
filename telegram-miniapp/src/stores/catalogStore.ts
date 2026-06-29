import { create } from 'zustand'
import { getServices, getPromos, type Service, type Promo } from '../services/catalog'

interface CatalogState {
  services: Service[]
  promos: Promo[]
  loading: boolean
  error: string | null
  fetch: () => Promise<void>
}

function getErrorMessage(e: unknown): string {
  if (e instanceof Error) return e.message
  if (typeof e === 'string') return e
  return 'Не удалось загрузить каталог'
}

export const useCatalogStore = create<CatalogState>((set) => ({
  services: [],
  promos: [],
  loading: false,
  error: null,
  fetch: async () => {
    set({ loading: true, error: null })
    try {
      const [services, promos] = await Promise.all([getServices(), getPromos()])
      set({ services, promos, loading: false })
    } catch (e: unknown) {
      set({ error: getErrorMessage(e), loading: false })
    }
  },
}))
