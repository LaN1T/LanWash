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

function isServiceArray(value: unknown): value is Service[] {
  return (
    Array.isArray(value) &&
    value.every(
      (item) =>
        typeof item === 'object' &&
        item !== null &&
        'id' in item &&
        'name' in item &&
        'price' in item &&
        typeof (item as Service).id === 'string' &&
        typeof (item as Service).name === 'string' &&
        typeof (item as Service).price === 'number',
    )
  )
}

function isPromoArray(value: unknown): value is Promo[] {
  return (
    Array.isArray(value) &&
    value.every(
      (item) =>
        typeof item === 'object' &&
        item !== null &&
        'id' in item &&
        'title' in item &&
        'description' in item &&
        typeof (item as Promo).id === 'string' &&
        typeof (item as Promo).title === 'string' &&
        typeof (item as Promo).description === 'string',
    )
  )
}

export async function getServices(): Promise<Service[]> {
  const res = await api.get('/services')
  if (!isServiceArray(res.data)) {
    throw new Error('Invalid service list response')
  }
  return res.data
}

export async function getPromos(): Promise<Promo[]> {
  const res = await api.get('/services/promos')
  if (!isPromoArray(res.data)) {
    throw new Error('Invalid promo list response')
  }
  return res.data
}
