import { api } from './api'

export interface Consumable {
  id: string
  name: string
  unit: string
  currentStock: number
  minStock: number
}

export function isConsumable(value: unknown): value is Consumable {
  if (typeof value !== 'object' || value === null) return false
  const c = value as Record<string, unknown>

  return (
    typeof c.id === 'string' &&
    typeof c.name === 'string' &&
    typeof c.unit === 'string' &&
    typeof c.currentStock === 'number' &&
    typeof c.minStock === 'number'
  )
}

function isConsumableArray(value: unknown): value is Consumable[] {
  return Array.isArray(value) && value.every(isConsumable)
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

export interface InventoryForecastItem {
  consumable_id: string
  name: string
  unit: string
  current_stock: number
  min_stock: number
  avg_daily_usage: number
  planned_usage_7d: number
  days_until_low: number | null
  days_until_empty: number | null
  recommended_order_amount: number
  status: 'critical' | 'warning' | 'ok'
}

export interface InventoryForecast {
  items: InventoryForecastItem[]
  generated_at: string
}

function isInventoryForecast(value: unknown): value is InventoryForecast {
  if (typeof value !== 'object' || value === null) return false
  const f = value as Record<string, unknown>

  return (
    Array.isArray(f.items) &&
    f.items.every((item: unknown) => {
      if (typeof item !== 'object' || item === null) return false
      const i = item as Record<string, unknown>
      return (
        typeof i.consumable_id === 'string' &&
        typeof i.name === 'string' &&
        typeof i.unit === 'string' &&
        typeof i.current_stock === 'number' &&
        typeof i.min_stock === 'number' &&
        typeof i.avg_daily_usage === 'number' &&
        typeof i.planned_usage_7d === 'number' &&
        (i.days_until_low === null || typeof i.days_until_low === 'number') &&
        (i.days_until_empty === null || typeof i.days_until_empty === 'number') &&
        typeof i.recommended_order_amount === 'number' &&
        typeof i.status === 'string' &&
        ['critical', 'warning', 'ok'].includes(i.status)
      )
    }) &&
    typeof f.generated_at === 'string'
  )
}

export async function getConsumables(signal?: AbortSignal): Promise<Consumable[]> {
  const res = await api.get('/consumables/', { signal })
  if (!isConsumableArray(res.data)) {
    throw new Error('Invalid consumables response')
  }
  return res.data
}

export async function getLowStockAlerts(signal?: AbortSignal): Promise<Consumable[]> {
  const res = await api.get('/consumables/alerts/low-stock', { signal })
  if (!isConsumableArray(res.data)) {
    throw new Error('Invalid low stock alerts response')
  }
  return res.data
}

export async function getInventoryForecast(signal?: AbortSignal): Promise<InventoryForecast> {
  const res = await api.get('/consumables/forecast', { signal })
  if (!isInventoryForecast(res.data)) {
    throw new Error('Invalid inventory forecast response')
  }
  return res.data
}

export async function getConsumableById(id: string, signal?: AbortSignal): Promise<Consumable> {
  const res = await api.get(`/consumables/${id}`, { signal })
  if (!isConsumable(res.data)) {
    throw new Error('Invalid consumable response')
  }
  return res.data
}

export async function refillConsumable(id: string, amount: number): Promise<Consumable> {
  const res = await api.post(`/consumables/${id}/refill`, { amount })
  if (!isConsumable(res.data)) {
    throw new Error('Invalid consumable response')
  }
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
  // Let Axios set the multipart boundary automatically.
  const res = await api.post('/consumables/import-refills', formData)
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
