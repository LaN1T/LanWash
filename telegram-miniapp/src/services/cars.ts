import { api } from './api'

export interface Car {
  id: string
  model: string
  number: string
}

export async function getMyCars(): Promise<Car[]> {
  const res = await api.get('/cars')
  return res.data
}
