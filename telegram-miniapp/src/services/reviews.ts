import { api } from './api'

export interface Review {
  id: number
  userId: number
  userName: string
  rating: number
  comment: string
  isPublished: boolean
  createdAt: string
  appointmentId: string | null
}

export interface ReviewModeratePayload {
  isPublished: boolean
}

function isReview(value: unknown): value is Review {
  if (typeof value !== 'object' || value === null) return false
  const r = value as Record<string, unknown>
  return (
    typeof r.id === 'number' &&
    typeof r.userId === 'number' &&
    typeof r.userName === 'string' &&
    typeof r.rating === 'number' &&
    typeof r.comment === 'string' &&
    typeof r.isPublished === 'boolean' &&
    typeof r.createdAt === 'string' &&
    (r.appointmentId === null || typeof r.appointmentId === 'string')
  )
}

function isReviewArray(value: unknown): value is Review[] {
  return Array.isArray(value) && value.every(isReview)
}

export async function getAllReviews(limit = 100, signal?: AbortSignal): Promise<Review[]> {
  const res = await api.get('/reviews/admin/all', { params: { limit }, signal })
  if (!isReviewArray(res.data)) throw new Error('Invalid reviews response')
  return res.data
}

export async function moderateReview(id: number, payload: ReviewModeratePayload): Promise<Review> {
  const res = await api.patch(`/reviews/admin/${id}`, payload)
  if (!isReview(res.data)) throw new Error('Invalid review response')
  return res.data
}

export async function deleteReview(id: number): Promise<void> {
  await api.delete(`/reviews/admin/${id}`)
}