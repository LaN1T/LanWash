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

export interface CreateNotePayload {
  title: string
  message?: string
  category?: string
}

export interface UnreadCount {
  count: number
}

export async function getNotes(signal?: AbortSignal): Promise<Note[]> {
  const res = await api.get('/notes/', { signal })
  return res.data
}

export async function getNotesByUser(
  username: string,
  signal?: AbortSignal,
): Promise<Note[]> {
  const res = await api.get(`/notes/by-user/${encodeURIComponent(username)}`, { signal })
  return res.data
}

export async function getUnreadNotesCount(signal?: AbortSignal): Promise<UnreadCount> {
  const res = await api.get('/notes/unread-count', { signal })
  return res.data
}

export async function createNote(
  username: string,
  payload: CreateNotePayload,
): Promise<Note> {
  const res = await api.post('/notes/', payload, { params: { username } })
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
