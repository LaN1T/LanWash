export type AppointmentStatus =
  | 'scheduled'
  | 'confirmed'
  | 'in_progress'
  | 'completed'
  | 'cancelled'

export const statusMap: Record<
  AppointmentStatus,
  { label: string; color: string; bg: string }
> = {
  scheduled: { label: 'Запланирована', color: '#1A56DB', bg: '#EFF4FF' },
  confirmed: { label: 'Подтверждена', color: '#1A56DB', bg: '#EFF4FF' },
  in_progress: { label: 'В процессе', color: '#7C3AED', bg: '#F5F3FF' },
  completed: { label: 'Завершена', color: '#059669', bg: '#ECFDF5' },
  cancelled: { label: 'Отменена', color: '#DC2626', bg: '#FEF2F2' },
}

export function parseWashers(assignedWasher: string): string[] {
  try {
    const parsed = JSON.parse(assignedWasher)
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}
