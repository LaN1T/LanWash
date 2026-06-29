import { api } from './api'

export interface Subscription {
  id: number
  userId: number
  name: string
  type: string
  washTypeId: string
  totalWashes: number
  usedWashes: number
  validUntil: string | null
  planId: number | null
  price: number
  originalPrice: number
  selectedExtras: string
  paymentStatus: string
  createdAt: string
}

export function isSubscription(value: unknown): value is Subscription {
  if (typeof value !== 'object' || value === null) return false
  const s = value as Record<string, unknown>

  return (
    typeof s.id === 'number' &&
    typeof s.userId === 'number' &&
    typeof s.name === 'string' &&
    typeof s.type === 'string' &&
    typeof s.washTypeId === 'string' &&
    typeof s.totalWashes === 'number' &&
    typeof s.usedWashes === 'number' &&
    (s.validUntil === null || typeof s.validUntil === 'string') &&
    (s.planId === null || typeof s.planId === 'number') &&
    typeof s.price === 'number' &&
    typeof s.originalPrice === 'number' &&
    typeof s.selectedExtras === 'string' &&
    typeof s.paymentStatus === 'string' &&
    typeof s.createdAt === 'string'
  )
}

function isSubscriptionArray(value: unknown): value is Subscription[] {
  return Array.isArray(value) && value.every(isSubscription)
}

export async function getMySubscriptions(signal?: AbortSignal): Promise<Subscription[]> {
  const res = await api.get('/subscriptions/my', { signal })
  if (!isSubscriptionArray(res.data)) {
    throw new Error('Invalid subscriptions response')
  }
  return res.data
}

export interface SubscriptionPlan {
  id: number
  code: string
  name: string
  description?: string | null
  type: 'package' | 'unlimited'
  washCount?: number | null
  unlimitedDays?: number | null
  discountPercent: number
  washTypePrices?: Record<string, number> | null
  sortOrder: number
  isActive: boolean
}

export interface CreateSubscriptionPlanPayload {
  code: string
  name: string
  description?: string
  type: 'package' | 'unlimited'
  washCount?: number
  unlimitedDays?: number
  discountPercent?: number
  washTypePrices?: Record<string, number>
  sortOrder?: number
  isActive?: boolean
}

export interface UpdateSubscriptionPlanPayload {
  name?: string
  description?: string
  washCount?: number
  unlimitedDays?: number
  discountPercent?: number
  washTypePrices?: Record<string, number>
  sortOrder?: number
  isActive?: boolean
}

export async function getAdminPlans(signal?: AbortSignal): Promise<SubscriptionPlan[]> {
  const res = await api.get('/subscriptions/admin/plans', { signal })
  return res.data
}

export async function createAdminPlan(
  payload: CreateSubscriptionPlanPayload,
): Promise<SubscriptionPlan> {
  const res = await api.post('/subscriptions/admin/plans', payload)
  return res.data
}

export async function updateAdminPlan(
  id: number,
  payload: UpdateSubscriptionPlanPayload,
): Promise<SubscriptionPlan> {
  const res = await api.put(`/subscriptions/admin/plans/${id}`, payload)
  return res.data
}

export async function deleteAdminPlan(id: number): Promise<unknown> {
  const res = await api.delete(`/subscriptions/admin/plans/${id}`)
  return res.data
}
