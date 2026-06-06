import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../../services/api'
import { BookingData } from '../../pages/client/BookingPage'

export default function Step3Confirm({
  data,
  onBack,
}: {
  data: BookingData
  onBack: () => void
}) {
  const navigate = useNavigate()
  const [submitting, setSubmitting] = useState(false)

  const handleSubmit = async () => {
    setSubmitting(true)
    try {
      await api.post('/appointments/', {
        id: crypto.randomUUID(),
        clientName: data.clientName,
        carModel: data.carModel,
        carNumber: data.carNumber,
        dateTime: data.dateTime,
        washTypeId: data.washTypeId,
        additionalServices: JSON.stringify(data.additionalServices),
        status: 'scheduled',
        ownerUsername: '',
      })
      navigate('/bookings')
    } catch (e) {
      alert('Ошибка при создании записи')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div>
      <div
        style={{
          background: 'var(--tg-theme-secondary-bg-color)',
          borderRadius: 12,
          padding: 16,
          marginBottom: 16,
        }}
      >
        <h3 style={{ marginBottom: 12 }}>Подтверждение</h3>
        <div style={{ lineHeight: 1.8 }}>
          <div><strong>Имя:</strong> {data.clientName}</div>
          <div><strong>Авто:</strong> {data.carModel}</div>
          <div><strong>Номер:</strong> {data.carNumber}</div>
          <div><strong>Дата и время:</strong> {new Date(data.dateTime).toLocaleString('ru-RU')}</div>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 12 }}>
        <button
          onClick={onBack}
          style={{ flex: 1, background: 'var(--tg-theme-secondary-bg-color)', color: 'var(--tg-theme-text-color)' }}
          disabled={submitting}
        >
          Назад
        </button>
        <button onClick={handleSubmit} disabled={submitting} style={{ flex: 1 }}>
          {submitting ? 'Создание...' : '✅ Подтвердить запись'}
        </button>
      </div>
    </div>
  )
}