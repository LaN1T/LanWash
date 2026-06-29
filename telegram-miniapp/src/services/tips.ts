import { api } from './api'
import type { Appointment } from './appointments'

export interface Tip {
  id: number
  appointmentId: string
  washerUsername: string
  amount: number
  method: string
  status: string
  createdAt: string
  sbpUrl?: string | null
}

export function isTip(value: unknown): value is Tip {
  if (typeof value !== 'object' || value === null) return false
  const t = value as Record<string, unknown>

  return (
    typeof t.id === 'number' &&
    typeof t.appointmentId === 'string' &&
    typeof t.washerUsername === 'string' &&
    typeof t.amount === 'number' &&
    typeof t.method === 'string' &&
    typeof t.status === 'string' &&
    typeof t.createdAt === 'string' &&
    (t.sbpUrl === undefined || t.sbpUrl === null || typeof t.sbpUrl === 'string')
  )
}

export interface TipWithAppointment extends Tip {
  appointment?: Appointment | null
}

export function isTipWithAppointment(value: unknown): value is TipWithAppointment {
  if (!isTip(value)) return false
  const t = value as unknown as Record<string, unknown>
  return t.appointment === undefined || t.appointment === null || typeof t.appointment === 'object'
}

export interface TipStats {
  totalTips: number
  totalAmount: number
  pendingAmount: number
}

export function isTipStats(value: unknown): value is TipStats {
  if (typeof value !== 'object' || value === null) return false
  const t = value as Record<string, unknown>

  return (
    typeof t.totalTips === 'number' &&
    typeof t.totalAmount === 'number' &&
    typeof t.pendingAmount === 'number'
  )
}

export async function getMyTips(signal?: AbortSignal): Promise<TipWithAppointment[]> {
  const res = await api.get('/tips/my', { signal })
  return res.data
}

export async function getTipStats(signal?: AbortSignal): Promise<TipStats> {
  const res = await api.get('/tips/stats', { signal })
  if (!isTipStats(res.data)) {
    throw new Error('Invalid tip stats response')
  }
  return res.data
}

export async function markTipAsPaid(tipId: number): Promise<Tip> {
  const res = await api.post(`/tips/${tipId}/mark-paid`)
  if (!isTip(res.data)) {
    throw new Error('Invalid tip response')
  }
  return res.data
}
