import { api } from './api'

export interface Consumable {
  id: string
  name: string
  unit: string
  currentStock: number
  minStock: number
}

export interface ConsumableUsageLog {
  consumableId: string
  appointmentId: string
  quantityUsed: number
  timestamp: string
  appointmentDateTime: string
  carModel: string
  carNumber: string
  washTypeId: string
}

export interface ConsumableHistoryItem {
  type: 'consumption' | 'refill'
  id: number
  appointmentId?: string | null
  quantity: number
  timestamp: string
}

export interface ConsumableHistory {
  items: ConsumableHistoryItem[]
}

export interface ConsumableForecast {
  forecast_date: string
  predicted_usage: number
  recommended_refill: number
}

export interface ServiceConsumableLink {
  serviceId: string
  consumableId: string
  quantity_per_service: number
}

export interface WashTypeConsumableLink {
  washTypeId: string
  consumableId: string
  quantity_per_service: number
}

export interface InventoryForecast {
  items: Array<{
    consumable_id: string
    name: string
    unit: string
    predicted_usage: number
    current_stock: number
    recommended_refill: number
  }>
  generated_at: string
}

export async function getConsumables(signal?: AbortSignal): Promise<Consumable[]> {
  const res = await api.get('/consumables/', { signal })
  return res.data
}

export async function getLowStockAlerts(signal?: AbortSignal): Promise<Consumable[]> {
  const res = await api.get('/consumables/alerts/low-stock', { signal })
  return res.data
}

export async function getInventoryForecast(signal?: AbortSignal): Promise<InventoryForecast> {
  const res = await api.get('/consumables/forecast', { signal })
  return res.data
}

export async function getConsumableById(id: string, signal?: AbortSignal): Promise<Consumable> {
  const res = await api.get(`/consumables/${id}`, { signal })
  return res.data
}

export async function refillConsumable(id: string, amount: number): Promise<Consumable> {
  const res = await api.post(`/consumables/${id}/refill`, { amount })
  return res.data
}

export async function getRefillHistory(id: string, signal?: AbortSignal): Promise<unknown> {
  const res = await api.get(`/consumables/${id}/refill-history`, { signal })
  return res.data
}

export async function getUsageHistory(
  id: string,
  signal?: AbortSignal,
): Promise<ConsumableUsageLog[]> {
  const res = await api.get(`/consumables/${id}/usage-history`, { signal })
  return res.data
}

export async function getConsumableHistory(
  id: string,
  signal?: AbortSignal,
): Promise<ConsumableHistory> {
  const res = await api.get(`/consumables/${id}/history`, { signal })
  return res.data
}

export async function getConsumableForecast(
  id: string,
  signal?: AbortSignal,
): Promise<ConsumableForecast> {
  const res = await api.get(`/consumables/${id}/forecast`, { signal })
  return res.data
}

export async function exportConsumables(
  dateFrom?: string,
  dateTo?: string,
  signal?: AbortSignal,
): Promise<Blob> {
  const res = await api.get('/consumables/export', {
    params: { date_from: dateFrom, date_to: dateTo },
    responseType: 'blob',
    signal,
  })
  return res.data
}

export async function downloadImportTemplate(signal?: AbortSignal): Promise<Blob> {
  const res = await api.get('/consumables/import-template', {
    responseType: 'blob',
    signal,
  })
  return res.data
}

export async function importRefills(file: File): Promise<unknown> {
  const formData = new FormData()
  formData.append('file', file)
  const res = await api.post('/consumables/import-refills', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return res.data
}

export async function getServiceLinks(signal?: AbortSignal): Promise<ServiceConsumableLink[]> {
  const res = await api.get('/consumables/service-link', { signal })
  return res.data
}

export async function createServiceLink(link: ServiceConsumableLink): Promise<ServiceConsumableLink> {
  const res = await api.post('/consumables/service-link', link)
  return res.data
}

export async function deleteServiceLink(serviceId: string, consumableId: string): Promise<unknown> {
  const res = await api.delete(`/consumables/service-link/${serviceId}/${consumableId}`)
  return res.data
}

export async function getWashTypeLinks(signal?: AbortSignal): Promise<WashTypeConsumableLink[]> {
  const res = await api.get('/consumables/wash-type-link', { signal })
  return res.data
}

export async function createWashTypeLink(
  link: WashTypeConsumableLink,
): Promise<WashTypeConsumableLink> {
  const res = await api.post('/consumables/wash-type-link', link)
  return res.data
}

export async function deleteWashTypeLink(
  washTypeId: string,
  consumableId: string,
): Promise<unknown> {
  const res = await api.delete(`/consumables/wash-type-link/${washTypeId}/${consumableId}`)
  return res.data
}
