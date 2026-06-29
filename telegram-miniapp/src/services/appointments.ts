import { api } from './api'

export interface BusySlot {
  date: string
  time: string
}

export async function getBusySlots(date: string): Promise<BusySlot[]> {
  const res = await api.get('/appointments/busy-slots', { params: { date } })
  return res.data
}

export async function createAppointment(data: any) {
  const res = await api.post('/appointments', data)
  return res.data
}
