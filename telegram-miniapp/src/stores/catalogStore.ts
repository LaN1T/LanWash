import { create } from 'zustand'
import { getServices, getPromos, type Service, type Promo } from '../services/catalog'

interface CatalogState {
  services: Service[]
  promos: Promo[]
  loading: boolean
  error: string | null
  fetch: () => Promise<void>
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
    } catch (e: any) {
      set({ error: e.message, loading: false })
    }
  },
}))
