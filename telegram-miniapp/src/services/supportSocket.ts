import { isSupportMessage, type SupportMessage } from './support'
import { useAuthStore } from '../stores/authStore'

type ServerMessage =
  | { type: 'new_message'; data: unknown }
  | { type: 'status_update'; data: unknown }
  | { type: 'ping' }

type SocketStatus = 'connecting' | 'open' | 'error' | 'closed'

const MAX_RETRIES = 10
const BASE_DELAY_MS = 1000
const MAX_DELAY_MS = 30000

export interface SupportSocketCallbacks {
  onMessage: (message: SupportMessage) => void
  onStatusUpdate?: (data: unknown) => void
  onStatusChange?: (status: SocketStatus) => void
}

export interface SupportSocketOptions {
  token?: string
  getToken?: () => string | null
}

export function connectSupportSocket(
  chatId: number,
  callbacks: SupportSocketCallbacks | ((message: SupportMessage) => void),
  options: SupportSocketOptions = {},
): () => void {
  const { onMessage, onStatusUpdate, onStatusChange } =
    typeof callbacks === 'function'
      ? { onMessage: callbacks, onStatusUpdate: undefined, onStatusChange: undefined }
      : callbacks

  const getToken = (): string | null => {
    if (options.token) return options.token
    if (options.getToken) return options.getToken()
    return useAuthStore.getState().token
  }

  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  const host = window.location.host
  const url = `${protocol}//${host}/ws/support/chats/${chatId}`

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

    const token = getToken()
    if (!token) {
      console.error('[supportSocket] No auth token available')
      setStatus('error')
      return
    }

    setStatus('connecting')
    socket = new WebSocket(url)

    socket.onopen = () => {
      retryCount = 0
      setStatus('open')
      socket?.send(JSON.stringify({ type: 'auth', token }))
    }

    socket.onmessage = (event) => {
      if (typeof event.data !== 'string') {
        console.warn('[supportSocket] Ignored non-text message:', event.data)
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

        if (message.type === 'new_message') {
          if (isSupportMessage(message.data)) {
            onMessage(message.data)
          } else {
            console.warn('[supportSocket] Invalid message shape:', message.data)
          }
          return
        }

        if (message.type === 'status_update') {
          onStatusUpdate?.(message.data)
        }
      } catch (err) {
        console.error('[supportSocket] Failed to parse message:', err)
      }
    }

    socket.onerror = (err) => {
      console.error('[supportSocket] WebSocket error:', err)
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
        console.error('[supportSocket] Reconnect limit reached')
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
