import { api } from './api'

export interface LogEntry {
  id: number
  username: string
  action: string
  details: string
  timestamp: string
}

function isLogEntry(value: unknown): value is LogEntry {
  if (typeof value !== 'object' || value === null) return false
  const l = value as Record<string, unknown>
  return (
    typeof l.id === 'number' &&
    typeof l.username === 'string' &&
    typeof l.action === 'string' &&
    typeof l.details === 'string' &&
    typeof l.timestamp === 'string'
  )
}

function isLogEntryArray(value: unknown): value is LogEntry[] {
  return Array.isArray(value) && value.every(isLogEntry)
}

export async function getLogs(limit = 200, signal?: AbortSignal): Promise<LogEntry[]> {
  const res = await api.get('/logs/', { params: { limit }, signal })
  if (!isLogEntryArray(res.data)) throw new Error('Invalid logs response')
  return res.data
}

export async function clearLogs(): Promise<void> {
  await api.delete('/logs/')
}