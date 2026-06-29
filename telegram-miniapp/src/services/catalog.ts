import { api } from './api'

export interface Service {
  id: string
  name: string
  price: number
  category?: string
}

export interface Promo {
  id: string
  title: string
  description: string
  discountPercent?: number
}

export async function getServices(): Promise<Service[]> {
  const res = await api.get('/services')
  return res.data
}

export async function getPromos(): Promise<Promo[]> {
  const res = await api.get('/services/promos')
  return res.data
}
