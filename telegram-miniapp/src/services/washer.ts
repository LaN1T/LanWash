import { api } from './api'
import type { Appointment } from './appointments'

export interface Shift {
  id: number
  userId: number
  date: string
  startTime: string
  endTime: string
  status: string
  createdBy: string
  createdAt: string
  updatedAt: string
}

export interface AvailabilityEntry {
  date: string
  status: string
}

export interface WasherAvailability {
  id: number
  userId: number
  date: string
  status: string
  updatedAt: string
}

export interface AvailabilityRangeParams {
  start_date: string
  end_date: string
}

export interface DeleteAvailabilityResult {
  deleted: number
}

export async function getMyShifts(signal?: AbortSignal): Promise<Shift[]> {
  const res = await api.get('/shifts/my', { signal })
  return res.data
}

export async function getWasherAppointments(
  username: string,
  signal?: AbortSignal,
): Promise<Appointment[]> {
  const res = await api.get(`/appointments/by-washer/${encodeURIComponent(username)}`, { signal })
  return res.data
}

export async function getAvailability(
  userId: number,
  params: AvailabilityRangeParams,
  signal?: AbortSignal,
): Promise<WasherAvailability[]> {
  const res = await api.get(`/washers/${userId}/availability`, { params, signal })
  return res.data
}

export async function updateAvailability(
  userId: number,
  entries: AvailabilityEntry[],
): Promise<WasherAvailability[]> {
  const res = await api.put(`/washers/${userId}/availability`, { entries })
  return res.data
}

export async function deleteAvailability(
  userId: number,
  params: AvailabilityRangeParams,
): Promise<DeleteAvailabilityResult> {
  const res = await api.delete(`/washers/${userId}/availability`, { params })
  return res.data
}
