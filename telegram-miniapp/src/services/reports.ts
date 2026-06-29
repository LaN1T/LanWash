import { api } from './api'

export interface DailyReport {
  report_date: string
  revenue: number
  appointments_count: number
  completed_count: number
  average_check: number
  box_occupancy: Record<string, number>
  top_services: Array<{
    name: string
    count: number
    revenue: number
  }>
  washers_on_shift: number
  consumables_alert: string[]
}

export interface FinancialReport {
  summary: Record<string, number>
  items: Array<{
    period: string
    appointments_count: number
    services_total: number
    discounts_total: number
    revenue: number
  }>
}

export interface WasherPayrollReport {
  items: Array<{
    washer_username: string
    washer_name: string
    appointments_count: number
    services_total: number
    tips_total: number
    total: number
  }>
}

export interface PromoEffectivenessReport {
  items: Array<{
    promo_id: string | null
    promo_name: string
    uses_count: number
    revenue: number
    discount_total: number
  }>
}

export interface CancellationsReport {
  summary: Record<string, number>
  items: Array<{
    appointment_id: string
    date: string
    client_name: string
    car_model: string
    reason: string | null
    cancelled_by: string
    lost_revenue: number
  }>
}

export interface PopularServicesReport {
  month: string
  category: string | null
  items: Array<{
    name: string
    count: number
    category: string | null
  }>
}

export interface MonthlyCheckVsPriceReport {
  month: string
  items: Array<{
    car_model: string
    avg_check: number
    visit_count: number
  }>
}

export interface ConsumablesUsageReport {
  month: string
  category: string | null
  items: Array<{
    consumable_name: string
    unit: string
    total_used: number
  }>
}

export interface ShiftLoadReport {
  startDate: string
  endDate: string
  targetWeeklyMinutesPerWasher: number
  dailyHours: Array<{
    date: string
    confirmedMinutes: number
    pendingMinutes: number
  }>
  washerStats: Array<{
    userId: number
    displayName: string
    confirmedMinutes: number
  }>
  statusCounts: Record<string, number>
  conflictCount: number
  availabilityCoverage: Record<string, number>
}

export async function getDailyReport(date: string, signal?: AbortSignal): Promise<DailyReport> {
  const res = await api.get('/reports/daily/', { params: { date }, signal })
  return res.data
}

export async function getFinancialReport(
  startDate: string,
  endDate: string,
  groupBy: 'day' | 'week' | 'month' = 'day',
  signal?: AbortSignal,
): Promise<FinancialReport> {
  const res = await api.get('/reports/financial/', {
    params: { start_date: startDate, end_date: endDate, group_by: groupBy },
    signal,
  })
  return res.data
}

export async function getWasherPayrollReport(
  startDate: string,
  endDate: string,
  washerUsername?: string,
  signal?: AbortSignal,
): Promise<WasherPayrollReport> {
  const res = await api.get('/reports/washer-payroll/', {
    params: { start_date: startDate, end_date: endDate, washer_username: washerUsername },
    signal,
  })
  return res.data
}

export async function getPromoEffectivenessReport(
  startDate: string,
  endDate: string,
  promoId?: string,
  signal?: AbortSignal,
): Promise<PromoEffectivenessReport> {
  const res = await api.get('/reports/promo-effectiveness/', {
    params: { start_date: startDate, end_date: endDate, promo_id: promoId },
    signal,
  })
  return res.data
}

export async function getCancellationsReport(
  startDate: string,
  endDate: string,
  params: {
    reason?: string
    washer_username?: string
    wash_type_id?: string
  } = {},
  signal?: AbortSignal,
): Promise<CancellationsReport> {
  const res = await api.get('/reports/cancellations/', {
    params: { start_date: startDate, end_date: endDate, ...params },
    signal,
  })
  return res.data
}

export async function getPopularAdditionalServicesReport(
  date: string,
  category?: string,
  signal?: AbortSignal,
): Promise<PopularServicesReport> {
  const res = await api.get('/reports/popular-additional-services/', {
    params: { date, category },
    signal,
  })
  return res.data
}

export async function getMonthlyCheckVsPriceReport(
  date: string,
  signal?: AbortSignal,
): Promise<MonthlyCheckVsPriceReport> {
  const res = await api.get('/reports/monthly-check-vs-price/', { params: { date }, signal })
  return res.data
}

export async function getConsumablesUsageReport(
  date: string,
  category?: string,
  signal?: AbortSignal,
): Promise<ConsumablesUsageReport> {
  const res = await api.get('/reports/consumables-usage/', {
    params: { date, category },
    signal,
  })
  return res.data
}

export async function getShiftLoadReport(
  startDate: string,
  endDate: string,
  targetWeeklyMinutes?: number,
  signal?: AbortSignal,
): Promise<ShiftLoadReport> {
  const res = await api.get('/reports/shift-load/', {
    params: {
      start_date: startDate,
      end_date: endDate,
      target_weekly_minutes: targetWeeklyMinutes,
    },
    signal,
  })
  return res.data
}
