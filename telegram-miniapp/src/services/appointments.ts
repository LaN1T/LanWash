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

export async function getBusySlots(date: string, signal?: AbortSignal): Promise<BusySlot[]> {
  const res = await api.get('/appointments/busy-slots', { params: { date }, signal })
  return res.data
}

export async function createAppointment(data: AppointmentCreatePayload) {
  const res = await api.post('/appointments', data)
  return res.data
}
