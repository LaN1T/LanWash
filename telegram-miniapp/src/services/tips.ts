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

export interface TipWithAppointment extends Tip {
  appointment?: Appointment | null
}

export interface TipStats {
  totalTips: number
  totalAmount: number
  pendingAmount: number
}

export async function getMyTips(signal?: AbortSignal): Promise<TipWithAppointment[]> {
  const res = await api.get('/tips/my', { signal })
  return res.data
}

export async function getTipStats(signal?: AbortSignal): Promise<TipStats> {
  const res = await api.get('/tips/stats', { signal })
  return res.data
}

export async function markTipAsPaid(tipId: number): Promise<Tip> {
  const res = await api.post(`/tips/${tipId}/mark-paid`)
  return res.data
}
