import { api } from './api'
export { bulkAssignWasher, bulkCancel, bulkUpdateStatus } from './appointments'

export interface DashboardKpi {
  fromDate: string
  toDate: string
  totalRevenue: number
  totalAppointments: number
  completedAppointments: number
  cancelledAppointments: number
  averageCheck: number
  newClients: number
  returningClients: number
  averageRating: number
  dailyBreakdown: Array<{
    date: string
    revenue: number
    appointments: number
    completed: number
  }>
  topWashers: Array<{
    name: string
    revenue: number
    appointments: number
  }>
  topClients: Array<{
    name: string
    visits: number
    totalSpent: number
  }>
}

export interface ForecastSlot {
  date: string
  hour: number
  predicted_load: number
  capacity: number
  utilization_pct: number
}

export interface Forecast {
  items: ForecastSlot[]
  generated_at: string
}

export interface UserListItem {
  id: number
  username: string
  role: string
  displayName: string
  phone: string
  email: string
  carModel: string
  carNumber: string
  avatarUrl: string
  createdAt: string
  referralCode?: string | null
}

export interface UserListResponse {
  items: UserListItem[]
  total: number
}

export interface UserSearchParams {
  q?: string
  role?: string
  from_date?: string
  to_date?: string
  limit?: number
  offset?: number
}

function isUserListItem(value: unknown): value is UserListItem {
  if (typeof value !== 'object' || value === null) return false
  const u = value as Record<string, unknown>

  return (
    typeof u.id === 'number' &&
    typeof u.username === 'string' &&
    typeof u.role === 'string' &&
    typeof u.displayName === 'string' &&
    typeof u.phone === 'string' &&
    typeof u.email === 'string' &&
    typeof u.carModel === 'string' &&
    typeof u.carNumber === 'string' &&
    typeof u.avatarUrl === 'string' &&
    typeof u.createdAt === 'string'
  )
}

function isUserListResponse(value: unknown): value is UserListResponse {
  if (typeof value !== 'object' || value === null) return false
  const r = value as Record<string, unknown>
  return (
    Array.isArray(r.items) &&
    r.items.every(isUserListItem) &&
    typeof r.total === 'number'
  )
}

export async function getDashboard(
  fromDate: string,
  toDate: string,
  signal?: AbortSignal,
): Promise<DashboardKpi> {
  const res = await api.get('/admin/dashboard', {
    params: { from_date: fromDate, to_date: toDate },
    signal,
  })
  return res.data
}

export async function getForecast(days: number, signal?: AbortSignal): Promise<Forecast> {
  const res = await api.get('/admin/forecast', { params: { days }, signal })
  return res.data
}

export async function searchUsers(
  params: UserSearchParams = {},
  signal?: AbortSignal,
): Promise<UserListResponse> {
  const res = await api.get('/admin/users', { params, signal })
  if (!isUserListResponse(res.data)) {
    throw new Error('Invalid user list response')
  }
  return res.data
}
