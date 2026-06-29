import { api } from './api'

export interface BusySlot {
  date: string
  time: string
}

export interface AppointmentCreatePayload {
  clientName: string
  carModel: string
  carNumber: string
  dateTime: string
  washTypeId: string
  additionalServices: string
  status: string
  ownerUsername: string
  promoCode?: string
}

export interface Appointment {
  id: string
  userId: number | null
  clientName: string
  carModel: string
  carNumber: string
  dateTime: string
  washTypeId: string
  additionalServices: string
  status: string
  notes: string
  isFavorite: boolean
  ownerUsername: string
  promoPrice: number
  paidPrice: number
  isModifiedByAdmin: boolean
  isModifiedByWasher: boolean
  isSeenByClient: boolean
  originalPrice: number
  assignedWasher: string
  promoId: string | null
  subscriptionId: number | null
  box_index: number
  late_minutes: number
  cancel_reason: string
}

export async function getBusySlots(date: string, signal?: AbortSignal): Promise<BusySlot[]> {
  const res = await api.get('/appointments/busy-slots', { params: { date }, signal })
  return res.data
}

export async function createAppointment(data: AppointmentCreatePayload, signal?: AbortSignal) {
  const res = await api.post('/appointments', data, { signal })
  return res.data
}

export async function getMyAppointments(): Promise<Appointment[]> {
  const res = await api.get('/appointments/by-owner/me')
  return res.data
}

export async function cancelAppointment(id: string, reason: string) {
  const res = await api.post(`/appointments/${id}/cancel-reason`, { reason })
  return res.data
}

export async function reportLate(id: string, minutes: number) {
  const res = await api.post(`/appointments/${id}/late`, { minutes })
  return res.data
}
