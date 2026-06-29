import { api } from './api'

export interface Subscription {
  id: string
  name: string
  discountPercent: number
}

export async function getMySubscriptions(signal?: AbortSignal): Promise<Subscription[]> {
  const res = await api.get('/subscriptions/my', { signal })
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
