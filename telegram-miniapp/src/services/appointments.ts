import { api } from './api'
import { statusMap, type AppointmentStatus } from '../utils/appointments'

export type { AppointmentStatus }

export interface BusySlot {
  date: string
  time: string
}

export interface AppointmentCreatePayload {
  id: string
  clientName: string
  carModel: string
  carNumber: string
  dateTime: string
  washTypeId: string
  additionalServices: string
  status: AppointmentStatus
  ownerUsername: string
  promoId?: string
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
  status: AppointmentStatus
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

export interface MyAppointmentListParams {
  status?: AppointmentStatus
}

export async function getMyAppointments(
  params: MyAppointmentListParams = {},
  signal?: AbortSignal,
): Promise<Appointment[]> {
  const res = await api.get('/appointments/by-owner/me', { params, signal })
  return res.data
}

export async function getAppointmentById(id: string, signal?: AbortSignal): Promise<Appointment> {
  const res = await api.get(`/appointments/${id}`, { signal })
  return res.data
}

export async function cancelAppointment(id: string, reason: string) {
  const res = await api.post(`/appointments/${id}/cancel-reason`, { reason })
  return res.data
}

export async function updateAppointmentStatus(
  id: string,
  status: AppointmentStatus,
  notes?: string,
): Promise<Appointment> {
  // Backend PUT /appointments/{id} expects a full AppointmentRequest payload.
  // We fetch the current appointment and send only the changed fields along with
  // the existing data; the backend enforces role-based field restrictions.
  const appt = await getAppointmentById(id)
  const payload = { ...appt, status, notes: notes ?? appt.notes }
  const res = await api.put(`/appointments/${id}`, payload)
  if (!isAppointment(res.data)) {
    throw new Error('Invalid appointment response')
  }
  return res.data
}

export async function reportLate(id: string, minutes: number) {
  const res = await api.post(`/appointments/${id}/late`, { minutes })
  return res.data
}

function isAppointmentStatus(value: unknown): value is AppointmentStatus {
  return typeof value === 'string' && value in statusMap
}

export function isAppointment(value: unknown): value is Appointment {
  if (typeof value !== 'object' || value === null) return false
  const appt = value as Record<string, unknown>

  return (
    typeof appt.id === 'string' &&
    (typeof appt.userId === 'number' || appt.userId === null) &&
    typeof appt.clientName === 'string' &&
    typeof appt.carModel === 'string' &&
    typeof appt.carNumber === 'string' &&
    typeof appt.dateTime === 'string' &&
    typeof appt.washTypeId === 'string' &&
    typeof appt.additionalServices === 'string' &&
    isAppointmentStatus(appt.status) &&
    typeof appt.notes === 'string' &&
    typeof appt.isFavorite === 'boolean' &&
    typeof appt.ownerUsername === 'string' &&
    typeof appt.promoPrice === 'number' &&
    typeof appt.paidPrice === 'number' &&
    typeof appt.isModifiedByAdmin === 'boolean' &&
    typeof appt.isModifiedByWasher === 'boolean' &&
    typeof appt.isSeenByClient === 'boolean' &&
    typeof appt.originalPrice === 'number' &&
    typeof appt.assignedWasher === 'string' &&
    (typeof appt.promoId === 'string' || appt.promoId === null) &&
    (typeof appt.subscriptionId === 'number' || appt.subscriptionId === null) &&
    typeof appt.box_index === 'number' &&
    typeof appt.late_minutes === 'number' &&
    typeof appt.cancel_reason === 'string'
  )
}

function isAppointmentArray(value: unknown): value is Appointment[] {
  return Array.isArray(value) && value.every(isAppointment)
}

export interface AppointmentListParams {
  date?: string
  page?: number
}

export interface BulkResult {
  processed: number
  failed: number
  errors: string[]
}

function isBulkResult(value: unknown): value is BulkResult {
  if (typeof value !== 'object' || value === null) return false
  const r = value as Record<string, unknown>

  return (
    typeof r.processed === 'number' &&
    typeof r.failed === 'number' &&
    Array.isArray(r.errors) &&
    r.errors.every((e: unknown) => typeof e === 'string')
  )
}

export async function getAppointments(
  params: AppointmentListParams = {},
  signal?: AbortSignal,
): Promise<Appointment[]> {
  const res = await api.get('/appointments', { params, signal })
  if (!isAppointmentArray(res.data)) {
    throw new Error('Invalid appointments list response')
  }
  return res.data
}

export async function assignWasher(id: string, washerUsername: string): Promise<Appointment> {
  const res = await api.post(`/appointments/${id}/assign-washer`, { washerUsername })
  if (!isAppointment(res.data)) {
    throw new Error('Invalid appointment response')
  }
  return res.data
}

export async function scanQr(qrData: string): Promise<Appointment> {
  const res = await api.post('/appointments/scan-qr', { qrData })
  if (!isAppointment(res.data)) {
    throw new Error('Invalid appointment response')
  }
  return res.data
}

export async function bulkAssignWasher(
  appointmentIds: string[],
  washerUsername: string,
): Promise<BulkResult> {
  const res = await api.post('/admin/bulk/assign-washer', { appointmentIds, washerUsername })
  if (!isBulkResult(res.data)) {
    throw new Error('Invalid bulk result response')
  }
  return res.data
}

export async function bulkCancel(
  appointmentIds: string[],
  reason?: string,
): Promise<BulkResult> {
  const res = await api.post('/admin/bulk/cancel', { appointmentIds, reason })
  if (!isBulkResult(res.data)) {
    throw new Error('Invalid bulk result response')
  }
  return res.data
}

export async function bulkUpdateStatus(
  appointmentIds: string[],
  status: AppointmentStatus,
): Promise<BulkResult> {
  const res = await api.post('/admin/bulk/update-status', { appointmentIds, status })
  if (!isBulkResult(res.data)) {
    throw new Error('Invalid bulk result response')
  }
  return res.data
}
