import { api } from './api'

export interface Note {
  id: number
  username: string
  title: string
  message: string
  category: string
  isRead: boolean
  createdAt: string
}

export function isNote(value: unknown): value is Note {
  if (typeof value !== 'object' || value === null) return false
  const n = value as Record<string, unknown>

  return (
    typeof n.id === 'number' &&
    typeof n.username === 'string' &&
    typeof n.title === 'string' &&
    typeof n.message === 'string' &&
    typeof n.category === 'string' &&
    typeof n.isRead === 'boolean' &&
    typeof n.createdAt === 'string'
  )
}

function isNoteArray(value: unknown): value is Note[] {
  return Array.isArray(value) && value.every(isNote)
}

export interface CreateNotePayload {
  title: string
  message?: string
  category?: string
}

export interface UnreadCount {
  count: number
}

export function isUnreadCount(value: unknown): value is UnreadCount {
  if (typeof value !== 'object' || value === null) return false
  const c = value as Record<string, unknown>
  return typeof c.count === 'number'
}

export async function getNotes(signal?: AbortSignal): Promise<Note[]> {
  const res = await api.get('/notes/', { signal })
  if (!isNoteArray(res.data)) {
    throw new Error('Invalid notes response')
  }
  return res.data
}

export async function getNotesByUser(
  username: string,
  signal?: AbortSignal,
): Promise<Note[]> {
  const res = await api.get(`/notes/by-user/${encodeURIComponent(username)}`, { signal })
  if (!isNoteArray(res.data)) {
    throw new Error('Invalid notes response')
  }
  return res.data
}

export async function getUnreadNotesCount(signal?: AbortSignal): Promise<UnreadCount> {
  const res = await api.get('/notes/unread-count', { signal })
  if (!isUnreadCount(res.data)) {
    throw new Error('Invalid unread count response')
  }
  return res.data
}

export async function createNote(
  username: string,
  payload: CreateNotePayload,
): Promise<Note> {
  const res = await api.post('/notes/', payload, { params: { username } })
  if (!isNote(res.data)) {
    throw new Error('Invalid note response')
  }
  return res.data
}

export async function markNoteAsRead(noteId: number): Promise<unknown> {
  const res = await api.put(`/notes/${noteId}/read`)
  return res.data
}

export async function markAllNotesAsRead(): Promise<unknown> {
  const res = await api.put('/notes/read-all')
  return res.data
}

export async function deleteNote(noteId: number): Promise<unknown> {
  const res = await api.delete(`/notes/${noteId}`)
  return res.data
}
