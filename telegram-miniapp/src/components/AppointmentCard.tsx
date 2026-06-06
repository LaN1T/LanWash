interface Props {
  appointment: {
    id: string
    dateTime: string
    carModel: string
    carNumber: string
    status: string
    box_index: number
  }
}

const statusMap: Record<string, { label: string; color: string }> = {
  scheduled: { label: 'Запланирована', color: '#3390ec' },
  in_progress: { label: 'В процессе', color: '#f5a623' },
  completed: { label: 'Завершена', color: '#34c759' },
  cancelled: { label: 'Отменена', color: '#ff3b30' },
}

export default function AppointmentCard({ appointment }: Props) {
  const status = statusMap[appointment.status] || { label: appointment.status, color: '#999' }

  return (
    <div
      style={{
        background: 'var(--tg-theme-secondary-bg-color)',
        borderRadius: 12,
        padding: 16,
        marginBottom: 12,
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <div style={{ fontWeight: 'bold', fontSize: 16 }}>
          {new Date(appointment.dateTime).toLocaleString('ru-RU', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}
        </div>
        <div
          style={{
            background: status.color + '20',
            color: status.color,
            padding: '4px 10px',
            borderRadius: 12,
            fontSize: 12,
            fontWeight: 'bold',
          }}
        >
          {status.label}
        </div>
      </div>
      <div style={{ color: 'var(--tg-theme-text-color)', marginBottom: 4 }}>
        {appointment.carModel}
      </div>
      <div style={{ color: 'var(--tg-theme-hint-color)', fontSize: 14 }}>
        {appointment.carNumber} · Бокс {appointment.box_index + 1}
      </div>
    </div>
  )
}