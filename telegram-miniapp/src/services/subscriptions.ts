import { api } from './api'

export interface Subscription {
  id: string
  name: string
  discountPercent: number
}

export async function getMySubscriptions(): Promise<Subscription[]> {
  const res = await api.get('/subscriptions/my')
  return res.data
}
