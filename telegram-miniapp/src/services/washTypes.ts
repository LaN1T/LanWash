import { api } from './api'

export interface WashType {
  id: string
  code: string
  name: string
  description: string
  basePrice: number
  durationMinutes: number
  sortOrder: number
  includedExtraIds: string[]
}

export interface WashTypePayload {
  id: string
  code: string
  name: string
  description?: string
  basePrice?: number
  durationMinutes?: number
  sortOrder?: number
  includedExtraIds?: string[]
}

function isWashType(value: unknown): value is WashType {
  if (typeof value !== 'object' || value === null) return false
  const w = value as Record<string, unknown>
  return (
    typeof w.id === 'string' &&
    typeof w.code === 'string' &&
    typeof w.name === 'string' &&
    typeof w.description === 'string' &&
    typeof w.basePrice === 'number' &&
    typeof w.durationMinutes === 'number' &&
    typeof w.sortOrder === 'number' &&
    Array.isArray(w.includedExtraIds) &&
    w.includedExtraIds.every((id) => typeof id === 'string')
  )
}

function isWashTypeArray(value: unknown): value is WashType[] {
  return Array.isArray(value) && value.every(isWashType)
}

export async function getWashTypes(signal?: AbortSignal): Promise<WashType[]> {
  const res = await api.get('/wash-types/', { signal })
  if (!isWashTypeArray(res.data)) throw new Error('Invalid wash types response')
  return res.data
}

export async function updateWashType(id: string, payload: WashTypePayload): Promise<WashType> {
  const res = await api.put(`/wash-types/${id}`, payload)
  if (!isWashType(res.data)) throw new Error('Invalid wash type response')
  return res.data
}