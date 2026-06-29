import type { Appointment } from './appointments'

type ServerMessage =
  | { type: 'appointment_updated'; event: string; appointment: unknown }
  | { type: 'ping' }

function isAppointment(value: unknown): value is Appointment {
  if (typeof value !== 'object' || value === null) return false
  const appt = value as Record<string, unknown>
  return (
    typeof appt.id === 'string' &&
    typeof appt.clientName === 'string' &&
    typeof appt.carModel === 'string' &&
    typeof appt.carNumber === 'string' &&
    typeof appt.dateTime === 'string' &&
    typeof appt.status === 'string'
  )
}

export function connectAppointmentsSocket(
  token: string,
  onUpdate: (appt: Appointment) => void,
): () => void {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  const host = window.location.host
  const url = `${protocol}//${host}/ws/appointments`

  const socket = new WebSocket(url)
  let closed = false

  socket.onopen = () => {
    socket.send(token)
  }

  socket.onmessage = (event) => {
    try {
      const message = JSON.parse(event.data as string) as ServerMessage

      if (message.type === 'ping') {
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
  }

  socket.onclose = () => {
    if (!closed) {
      console.log('[appointmentSocket] WebSocket closed')
    }
  }

  return () => {
    closed = true
    socket.close()
  }
}
