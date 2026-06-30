import { api } from './api'

export interface Service {
  id: string
  name: string
  description: string
  price: number
  durationMinutes: number
  category: string
  isFavorite: boolean
  isFromApi: boolean
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

export interface ServicePayload {
  id: string
  name: string
  description?: string
  price?: number
  durationMinutes?: number
  category?: string
  isFavorite?: boolean
  isFromApi?: boolean
}

export async function getServices(): Promise<Service[]> {
  const res = await api.get('/services')
  if (!isServiceArray(res.data)) {
    throw new Error('Invalid service list response')
  }
  return res.data
}

export async function getServiceCategories(): Promise<string[]> {
  const res = await api.get('/services/categories')
  return Array.isArray(res.data) ? res.data : []
}

export async function createService(payload: ServicePayload): Promise<Service> {
  const res = await api.post('/services/', payload)
  if (!isService(res.data)) throw new Error('Invalid service response')
  return res.data
}

export async function updateService(id: string, payload: ServicePayload): Promise<Service> {
  const res = await api.put(`/services/${id}`, payload)
  if (!isService(res.data)) throw new Error('Invalid service response')
  return res.data
}

export async function deleteService(id: string): Promise<void> {
  await api.delete(`/services/${id}`)
}

export async function getPromos(): Promise<Promo[]> {
  const res = await api.get('/services/promos')
  if (!isPromoArray(res.data)) {
    throw new Error('Invalid promo list response')
  }
  return res.data
}

function isService(value: unknown): value is Service {
  return (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as Service).id === 'string' &&
    typeof (value as Service).name === 'string' &&
    typeof (value as Service).price === 'number'
  )
}
