import { api } from './api'

export interface Shift {
  id: number
  userId: number
  date: string
  startTime: string
  endTime: string
  status: string
  createdBy: string
  createdAt: string
}

export interface CreateShiftPayload {
  userId: number
  date: string
  startTime: string
  endTime: string
}

function isShift(value: unknown): value is Shift {
  if (typeof value !== 'object' || value === null) return false
  const s = value as Record<string, unknown>
  return (
    typeof s.id === 'number' &&
    typeof s.userId === 'number' &&
    typeof s.date === 'string' &&
    typeof s.startTime === 'string' &&
    typeof s.endTime === 'string' &&
    typeof s.status === 'string' &&
    typeof s.createdBy === 'string' &&
    typeof s.createdAt === 'string'
  )
}

function isShiftArray(value: unknown): value is Shift[] {
  return Array.isArray(value) && value.every(isShift)
}

export async function getShifts(startDate: string, endDate: string, signal?: AbortSignal): Promise<Shift[]> {
  const res = await api.get('/shifts/', { params: { start_date: startDate, end_date: endDate }, signal })
  if (!isShiftArray(res.data)) throw new Error('Invalid shifts response')
  return res.data
}

export async function getTodayShifts(signal?: AbortSignal): Promise<Shift[]> {
  const res = await api.get('/shifts/today', { signal })
  if (!isShiftArray(res.data)) throw new Error('Invalid shifts response')
  return res.data
}

export async function createShift(payload: CreateShiftPayload): Promise<Shift> {
  const res = await api.post('/shifts/', payload)
  if (!isShift(res.data)) throw new Error('Invalid shift response')
  return res.data
}

export async function approveShift(id: number): Promise<Shift> {
  const res = await api.put(`/shifts/${id}/approve`)
  if (!isShift(res.data)) throw new Error('Invalid shift response')
  return res.data
}

export async function rejectShift(id: number): Promise<Shift> {
  const res = await api.put(`/shifts/${id}/reject`)
  if (!isShift(res.data)) throw new Error('Invalid shift response')
  return res.data
}

export async function reopenShift(id: number): Promise<Shift> {
  const res = await api.put(`/shifts/${id}/reopen`)
  if (!isShift(res.data)) throw new Error('Invalid shift response')
  return res.data
}

export async function deleteShift(id: number): Promise<void> {
  await api.delete(`/shifts/${id}`)
}