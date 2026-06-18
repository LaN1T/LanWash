interface Props {
  appointment: {
    id: string
    dateTime: string
    carModel: string
    carNumber: string
    status: string
    box_index: number | null
  }
}

const statusMap: Record<string, { label: string; color: string; bg: string }> = {
  scheduled: { label: 'Запланирована', color: '#1A56DB', bg: '#EFF4FF' },
  in_progress: { label: 'В процессе', color: '#7C3AED', bg: '#F5F3FF' },
  completed: { label: 'Завершена', color: '#059669', bg: '#ECFDF5' },
  cancelled: { label: 'Отменена', color: '#DC2626', bg: '#FEF2F2' },
}

export default function AppointmentCard({ appointment }: Props) {
  const status = statusMap[appointment.status] || { label: appointment.status, color: '#999', bg: '#F1F5F9' }
  const dt = new Date(appointment.dateTime)

  return (
    <div
      style={{
        background: '#FFFFFF',
        borderRadius: 16,
        padding: 16,
        marginBottom: 12,
        border: '1px solid #E2E8F0',
        boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
        <div>
          <div style={{ fontWeight: 700, fontSize: 18, color: '#0F172A', marginBottom: 4 }}>
            {dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' })}
          </div>
          <div style={{ fontSize: 14, color: '#64748B' }}>
            {dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}
          </div>
        </div>
        <div
          style={{
            background: status.bg,
            color: status.color,
            padding: '4px 10px',
            borderRadius: 6,
            fontSize: 11,
            fontWeight: 600,
            letterSpacing: 0.3,
          }}
        >
          {status.label}
        </div>
      </div>

      <div style={{ height: 1, background: '#E2E8F0', margin: '12px 0' }} />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div
          style={{
            width: 36,
            height: 36,
            borderRadius: 10,
            background: '#EFF4FF',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#1A56DB" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/>
            <circle cx="7" cy="17" r="2"/>
            <path d="M9 17h6"/>
            <circle cx="17" cy="17" r="2"/>
          </svg>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 15, fontWeight: 500, color: '#0F172A' }}>{appointment.carModel}</div>
          <div style={{ fontSize: 13, color: '#64748B' }}>
            {appointment.carNumber}
            {appointment.box_index !== null && appointment.box_index !== undefined && (
              <span style={{ marginLeft: 8, color: '#1A56DB', fontWeight: 600 }}>
                Бокс {appointment.box_index + 1}
              </span>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
