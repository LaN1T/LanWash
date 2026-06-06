import { useState, useEffect } from 'react'
import { api } from '../../services/api'
import { useAuthStore } from '../../stores/authStore'
import { BookingData } from '../../pages/client/BookingPage'

interface WashType {
  id: string
  name: string
  basePrice: number
  durationMinutes: number
}

interface Service {
  id: string
  name: string
  price: number
}

export default function Step1CarWash({
  data,
  updateData,
  onNext,
}: {
  data: BookingData
  updateData: (p: Partial<BookingData>) => void
  onNext: () => void
}) {
  const { user } = useAuthStore()
  const [washTypes, setWashTypes] = useState<WashType[]>([])
  const [services, setServices] = useState<Service[]>([])

  useEffect(() => {
    api.get('/wash-types/').then((res) => setWashTypes(res.data))
    api.get('/services/').then((res) => setServices(res.data))
    if (user) {
      updateData({
        clientName: user.displayName,
        carModel: user.carModel,
        carNumber: user.carNumber,
      })
    }
  }, [])

  const toggleService = (id: string) => {
    const next = data.additionalServices.includes(id)
      ? data.additionalServices.filter((s) => s !== id)
      : [...data.additionalServices, id]
    updateData({ additionalServices: next })
  }

  return (
    <div>
      <div style={{ marginBottom: 16 }}>
        <label>Имя</label>
        <input
          value={data.clientName}
          onChange={(e) => updateData({ clientName: e.target.value })}
          placeholder="Ваше имя"
        />
      </div>
      <div style={{ marginBottom: 16 }}>
        <label>Автомобиль</label>
        <input
          value={data.carModel}
          onChange={(e) => updateData({ carModel: e.target.value })}
          placeholder="Марка и модель"
        />
      </div>
      <div style={{ marginBottom: 16 }}>
        <label>Госномер</label>
        <input
          value={data.carNumber}
          onChange={(e) => updateData({ carNumber: e.target.value })}
          placeholder="А123БВ777"
        />
      </div>

      <div style={{ marginBottom: 16 }}>
        <label>Тип мойки</label>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
          {washTypes.map((wt) => (
            <div
              key={wt.id}
              onClick={() => updateData({ washTypeId: wt.id })}
              style={{
                padding: 12,
                borderRadius: 8,
                border: data.washTypeId === wt.id ? '2px solid var(--tg-theme-button-color)' : '1px solid var(--tg-theme-hint-color)',
                cursor: 'pointer',
              }}
            >
              <div style={{ fontWeight: 'bold' }}>{wt.name}</div>
              <div style={{ color: 'var(--tg-theme-hint-color)', fontSize: 14 }}>
                {wt.basePrice}₽ · {wt.durationMinutes} мин
              </div>
            </div>
          ))}
        </div>
      </div>

      <div style={{ marginBottom: 16 }}>
        <label>Доп. услуги</label>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 8 }}>
          {services.map((s) => (
            <label
              key={s.id}
              style={{
                padding: '8px 12px',
                borderRadius: 20,
                border: data.additionalServices.includes(s.id)
                  ? '2px solid var(--tg-theme-button-color)'
                  : '1px solid var(--tg-theme-hint-color)',
                cursor: 'pointer',
                fontSize: 14,
              }}
            >
              <input
                type="checkbox"
                checked={data.additionalServices.includes(s.id)}
                onChange={() => toggleService(s.id)}
                style={{ display: 'none' }}
              />
              {s.name} (+{s.price}₽)
            </label>
          ))}
        </div>
      </div>

      <button
        onClick={onNext}
        disabled={!data.clientName || !data.carModel || !data.carNumber || !data.washTypeId}
        style={{ width: '100%', opacity: (!data.washTypeId) ? 0.5 : 1 }}
      >
        Далее
      </button>
    </div>
  )
}