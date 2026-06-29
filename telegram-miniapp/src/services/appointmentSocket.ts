import type { Appointment } from './appointments'
import { type AppointmentStatus, statusMap } from '../utils/appointments'

type ServerMessage =
  | { type: 'appointment_updated'; event: string; appointment: unknown }
  | { type: 'ping' }

type SocketStatus = 'connecting' | 'open' | 'error' | 'closed'

const MAX_RETRIES = 10
const BASE_DELAY_MS = 1000
const MAX_DELAY_MS = 30000

function isAppointmentStatus(value: unknown): value is AppointmentStatus {
  return typeof value === 'string' && value in statusMap
}

function isAppointment(value: unknown): value is Appointment {
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

export interface SocketCallbacks {
  onUpdate: (appt: Appointment) => void
  onStatusChange?: (status: SocketStatus) => void
}

export function connectAppointmentsSocket(
  token: string,
  callbacks: SocketCallbacks | ((appt: Appointment) => void),
): () => void {
  const { onUpdate, onStatusChange } =
    typeof callbacks === 'function' ? { onUpdate: callbacks, onStatusChange: undefined } : callbacks

  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  const host = window.location.host
  const url = `${protocol}//${host}/ws/appointments`

  let intentionalClose = false
  let retryCount = 0
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null
  let socket: WebSocket | null = null

  const setStatus = (status: SocketStatus) => {
    onStatusChange?.(status)
  }

  const clearReconnect = () => {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
  }

  const connect = () => {
    if (intentionalClose) return

    setStatus('connecting')
    socket = new WebSocket(url)

    socket.onopen = () => {
      retryCount = 0
      setStatus('open')
      socket?.send(JSON.stringify({ type: 'auth', token }))
    }

    socket.onmessage = (event) => {
      if (typeof event.data !== 'string') {
        console.warn('[appointmentSocket] Ignored non-text message:', event.data)
        return
      }

      try {
        const message = JSON.parse(event.data) as ServerMessage

        if (message.type === 'ping') {
          if (socket?.readyState === WebSocket.OPEN) {
            socket.send(JSON.stringify({ type: 'pong' }))
          }
          return
        }

        if (message.type === 'appointment_updated') {
          if (isAppointment(message.appointment)) {
            onUpdate(message.appointment)
          } else {
            console.warn('[appointmentSocket] Invalid appointment shape:', message.appointment)
          }
        }
      } catch (err) {
        console.error('[appointmentSocket] Failed to parse message:', err)
      }
    }

    socket.onerror = (err) => {
      console.error('[appointmentSocket] WebSocket error:', err)
      setStatus('error')
    }

    socket.onclose = () => {
      setStatus('closed')
      socket = null

      if (intentionalClose) return

      if (retryCount < MAX_RETRIES) {
        const delay = Math.min(BASE_DELAY_MS * 2 ** retryCount, MAX_DELAY_MS)
        retryCount += 1
        reconnectTimer = setTimeout(connect, delay)
      } else {
        console.error('[appointmentSocket] Reconnect limit reached')
      }
    }
  }

  connect()

  return () => {
    intentionalClose = true
    clearReconnect()
    socket?.close()
    socket = null
  }
}
