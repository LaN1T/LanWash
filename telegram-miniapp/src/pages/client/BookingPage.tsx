import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../../services/api'
import { useAuthStore } from '../../stores/authStore'
import { validateName, validateCarModel, validatePlate, formatPlate } from '../../utils/validators'

interface WashType {
  id: string
  name: string
  description: string
  basePrice: number
  durationMinutes: number
  includedExtraIds: string[]
  sortOrder: number
}

interface Service {
  id: string
  name: string
  price: number
  durationMinutes: number
  category: string
}

interface BusySlot {
  start: string
  end: string
}

export default function BookingPage() {
  const { user } = useAuthStore()
  const navigate = useNavigate()
  const [step, setStep] = useState(0)
  const [isSaving, setIsSaving] = useState(false)

  // Form state
  const [name, setName] = useState(user?.displayName || '')
  const [car, setCar] = useState(user?.carModel || '')
  const [plate, setPlate] = useState(user?.carNumber || '')
  const [washTypeId, setWashTypeId] = useState('')
  const [extras, setExtras] = useState<Set<string>>(new Set())

  // Date/time state
  const [selectedDate, setSelectedDate] = useState(() => {
    const d = new Date()
    d.setHours(0, 0, 0, 0)
    return d
  })
  const [selectedSlot, setSelectedSlot] = useState(-1)
  const [busySlots, setBusySlots] = useState<BusySlot[][]>([])
  const [loadingSlots, setLoadingSlots] = useState(false)

  // Data
  const [washTypes, setWashTypes] = useState<WashType[]>([])
  const [services, setServices] = useState<Service[]>([])
  const [loading, setLoading] = useState(true)

  // Errors
  const [errors, setErrors] = useState<Record<string, string>>({})

  const pageRef = useRef<HTMLDivElement>(null)

  // Load data
  useEffect(() => {
    Promise.all([api.get('/wash-types/'), api.get('/services/')]).then(([wtRes, svcRes]) => {
      const wts = wtRes.data.sort((a: WashType, b: WashType) => a.sortOrder - b.sortOrder)
      setWashTypes(wts)
      setServices(svcRes.data)

      // Set default wash type
      const basic = wts.find((w: WashType) => w.name.toLowerCase().includes('базовая') || w.name.toLowerCase().includes('basic')) || wts[0]
      if (basic) {
        setWashTypeId(basic.id)
        setExtras(new Set(basic.includedExtraIds || []))
      }
      setLoading(false)
    })
  }, [])

  // Load busy slots when date changes
  useEffect(() => {
    if (!washTypeId) return
    const dateStr = selectedDate.toISOString().split('T')[0]
    setLoadingSlots(true)
    api.get(`/appointments/busy-slots?date=${dateStr}`).then((res) => {
      setBusySlots(res.data.busy_slots || [])
      setLoadingSlots(false)
    }).catch(() => {
      setBusySlots([])
      setLoadingSlots(false)
    })
  }, [selectedDate, washTypeId])

  const selectedWashType = washTypes.find((w) => w.id === washTypeId)

  const getDuration = () => {
    let duration = selectedWashType?.durationMinutes || 30
    for (const id of extras) {
      if (!selectedWashType?.includedExtraIds?.includes(id)) {
        const svc = services.find((s) => s.id === id)
        duration += svc?.durationMinutes || 0
      }
    }
    return duration
  }

  const getFinalPrice = () => {
    let price = selectedWashType?.basePrice || 0
    for (const id of extras) {
      if (!selectedWashType?.includedExtraIds?.includes(id)) {
        const svc = services.find((s) => s.id === id)
        price += svc?.price || 0
      }
    }
    return price
  }

  const isSlotAvailable = (hour: number, minute: number) => {
    const dt = new Date(selectedDate)
    dt.setHours(hour, minute, 0, 0)
    if (dt < new Date()) return false

    const duration = getDuration()
    const totalMinutes = hour * 60 + minute + duration + 5
    if (totalMinutes > 22 * 60) return false

    const start = dt
    const end = new Date(dt.getTime() + duration * 60000)

    for (const boxSlots of busySlots) {
      let isBoxFree = true
      for (const slot of boxSlots) {
        const slotStart = new Date(slot.start)
        const slotEnd = new Date(slot.end)
        if (start < slotEnd && end > slotStart) {
          isBoxFree = false
          break
        }
      }
      if (isBoxFree) return true
    }
    return busySlots.length === 0 // No boxes configured = all free
  }

  const getFinalDateTime = () => {
    if (selectedSlot === -1) return new Date()
    const hour = 8 + Math.floor(selectedSlot / 2)
    const minute = (selectedSlot % 2) * 30
    return new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate(), hour, minute)
  }

  const validateStep0 = () => {
    const newErrors: Record<string, string> = {}
    const nameErr = validateName(name)
    if (nameErr) newErrors.name = nameErr
    const carErr = validateCarModel(car)
    if (carErr) newErrors.car = carErr
    const plateErr = validatePlate(plate)
    if (plateErr) newErrors.plate = plateErr
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleNext = () => {
    if (step === 0) {
      if (!validateStep0()) {
        pageRef.current?.scrollTo({ top: 0, behavior: 'smooth' })
        return
      }
    }
    if (step === 1 && selectedSlot === -1) {
      alert('Пожалуйста, выберите время для записи.')
      return
    }
    if (step < 2) {
      setStep(step + 1)
    }
  }

  const handleBack = () => {
    if (step > 0) {
      setStep(step - 1)
    } else {
      navigate('/')
    }
  }

  const handleConfirm = async () => {
    if (isSaving) return
    setIsSaving(true)
    try {
      await api.post('/appointments/', {
        id: crypto.randomUUID(),
        clientName: name.trim(),
        carModel: car.trim(),
        carNumber: plate.replace(/\s/g, '').toUpperCase(),
        dateTime: getFinalDateTime().toISOString(),
        washTypeId,
        additionalServices: JSON.stringify(Array.from(extras)),
        status: 'scheduled',
        ownerUsername: user?.username || '',
      })
      navigate('/bookings')
    } catch (e) {
      alert('Не удалось создать запись. Попробуйте ещё раз.')
    } finally {
      setIsSaving(false)
    }
  }

  const toggleExtra = (id: string) => {
    if (selectedWashType?.includedExtraIds?.includes(id)) return // locked
    const next = new Set(extras)
    if (next.has(id)) next.delete(id)
    else next.add(id)
    setExtras(next)
  }

  const handleWashTypeChange = (wt: WashType) => {
    const next = new Set(extras)
    // Remove old included extras
    if (selectedWashType?.includedExtraIds) {
      for (const id of selectedWashType.includedExtraIds) next.delete(id)
    }
    // Add new included extras
    if (wt.includedExtraIds) {
      for (const id of wt.includedExtraIds) next.add(id)
    }
    setWashTypeId(wt.id)
    setExtras(next)
  }

  const handlePlateChange = (val: string) => {
    // Allow only valid chars
    const cleaned = val.toUpperCase().replace(/[^АВЕКМНОРСТУХABEKMHOPCTYX0-9\s]/g, '')
    setPlate(cleaned)
    if (errors.plate) {
      setErrors((prev) => { const n = { ...prev }; delete n.plate; return n })
    }
  }

  // Generate days
  const days = Array.from({ length: 14 }, (_, i) => {
    const d = new Date()
    d.setDate(d.getDate() + i)
    d.setHours(0, 0, 0, 0)
    return d
  })

  // Extra services sorted by price, excluding promos
  const extraServices = services
    .filter((s) => s.category !== 'Акции')
    .sort((a, b) => a.price - b.price)

  const steps = ['Услуга', 'Дата и время', 'Подтверждение']

  if (loading) {
    return (
      <div style={{ padding: 16, textAlign: 'center', color: '#64748B', marginTop: 60 }}>
        Загрузка...
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh' }}>
      {/* Step Indicator */}
      <div style={{ background: '#FFFFFF', borderBottom: '1px solid #E2E8F0', padding: '14px 20px' }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          {steps.map((label, idx) => (
            <div key={idx} style={{ display: 'flex', alignItems: 'center', flex: 1 }}>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 1 }}>
                <div
                  style={{
                    width: 32,
                    height: 32,
                    borderRadius: '50%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    background: idx < step ? '#1A56DB' : idx === step ? '#EFF4FF' : '#F1F5F9',
                    border: `2px solid ${idx < step || idx === step ? '#1A56DB' : '#E2E8F0'}`,
                  }}
                >
                  {idx < step ? (
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="20 6 9 17 4 12"/>
                    </svg>
                  ) : (
                    <span style={{ fontSize: 13, fontWeight: 700, color: idx === step ? '#1A56DB' : '#64748B' }}>
                      {idx + 1}
                    </span>
                  )}
                </div>
                <span
                  style={{
                    fontSize: 10,
                    marginTop: 5,
                    color: idx < step || idx === step ? '#1A56DB' : '#ADB5C8',
                    fontWeight: idx === step ? 600 : 400,
                  }}
                >
                  {label}
                </span>
              </div>
              {idx < steps.length - 1 && (
                <div
                  style={{
                    height: 2,
                    flex: 1,
                    background: idx < step ? '#1A56DB' : '#E2E8F0',
                    margin: '0 4px',
                    marginBottom: 16,
                  }}
                />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Content */}
      <div ref={pageRef} style={{ flex: 1, overflow: 'auto', padding: 16 }}>
        {step === 0 && (
          <Step0Service
            name={name} setName={setName}
            car={car} setCar={setCar}
            plate={plate} setPlate={handlePlateChange}
            washTypes={washTypes}
            washTypeId={washTypeId}
            onWashTypeChange={handleWashTypeChange}
            extras={extras}
            onExtraToggle={toggleExtra}
            extraServices={extraServices}
            errors={errors}
          />
        )}
        {step === 1 && (
          <Step1DateTime
            days={days}
            selectedDate={selectedDate}
            onDateChange={(d: Date) => { setSelectedDate(d); setSelectedSlot(-1) }}
            selectedSlot={selectedSlot}
            onSlotChange={setSelectedSlot}
            isSlotAvailable={isSlotAvailable}
            getDuration={getDuration}
            loadingSlots={loadingSlots}
          />
        )}
        {step === 2 && (
          <Step2Confirm
            date={getFinalDateTime()}
            washType={selectedWashType}
            extras={Array.from(extras)}
            services={services}
            name={name}
            car={car}
            plate={plate}
            finalPrice={getFinalPrice()}
            totalDuration={getDuration()}
          />
        )}
      </div>

      {/* Bottom Bar */}
      <div
        style={{
          background: '#FFFFFF',
          borderTop: '1px solid #E2E8F0',
          boxShadow: '0 -4px 12px rgba(0, 0, 0, 0.04)',
          padding: '12px 16px 28px',
          display: 'flex',
          gap: 12,
        }}
      >
        <button
          onClick={handleBack}
          style={{
            flex: 1,
            padding: '16px 24px',
            borderRadius: 12,
            background: '#FFFFFF',
            color: '#64748B',
            fontSize: 15,
            fontWeight: 600,
            border: '1px solid #E2E8F0',
          }}
        >
          {step === 0 ? 'Отмена' : 'Назад'}
        </button>
        <button
          onClick={step < 2 ? handleNext : handleConfirm}
          disabled={isSaving}
          style={{
            flex: 1,
            padding: '16px 24px',
            borderRadius: 12,
            background: '#1A56DB',
            color: 'white',
            fontSize: 15,
            fontWeight: 600,
            border: 'none',
            opacity: isSaving ? 0.7 : 1,
          }}
        >
          {isSaving ? 'Создание...' : step < 2 ? 'Далее' : 'Подтвердить'}
        </button>
      </div>
    </div>
  )
}

// ─── Step 0: Service ─────────────────────────────────────────────────────────
function Step0Service({
  name, setName, car, setCar, plate, setPlate,
  washTypes, washTypeId, onWashTypeChange,
  extras, onExtraToggle, extraServices, errors,
}: any) {
  const inputStyle = (hasError: boolean): React.CSSProperties => ({
    width: '100%',
    padding: '14px 16px',
    borderRadius: 12,
    border: `1px solid ${hasError ? '#DC2626' : '#E2E8F0'}`,
    fontSize: 15,
    background: '#FFFFFF',
    color: '#0F172A',
    outline: 'none',
    letterSpacing: plate ? 1.5 : 0,
    fontWeight: plate ? 600 : 400,
  })

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <h3 style={{ fontSize: 16, fontWeight: 600, color: '#0F172A' }}>Ваши данные</h3>

      <div>
        <input
          style={inputStyle(!!errors.name)}
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Ваше имя"
        />
        {errors.name && <div style={{ color: '#DC2626', fontSize: 12, marginTop: 4 }}>{errors.name}</div>}
      </div>

      <div>
        <input
          style={inputStyle(!!errors.car)}
          value={car}
          onChange={(e) => setCar(e.target.value)}
          placeholder="Марка и модель авто"
        />
        {errors.car && <div style={{ color: '#DC2626', fontSize: 12, marginTop: 4 }}>{errors.car}</div>}
      </div>

      <div>
        <input
          style={inputStyle(!!errors.plate)}
          value={formatPlate(plate)}
          onChange={(e) => setPlate(e.target.value)}
          placeholder="А 123 БВ 777"
          maxLength={14}
        />
        {errors.plate && <div style={{ color: '#DC2626', fontSize: 12, marginTop: 4 }}>{errors.plate}</div>}
      </div>

      <h3 style={{ fontSize: 16, fontWeight: 600, color: '#0F172A', marginTop: 8 }}>Выберите услугу</h3>

      {washTypes.map((wt: WashType) => {
        const selected = washTypeId === wt.id
        return (
          <div
            key={wt.id}
            onClick={() => onWashTypeChange(wt)}
            style={{
              padding: 16,
              borderRadius: 16,
              background: '#FFFFFF',
              border: `2px solid ${selected ? '#1A56DB' : '#E2E8F0'}`,
              boxShadow: selected
                ? '0 4px 10px rgba(26, 86, 219, 0.1)'
                : '0 2px 4px rgba(0, 0, 0, 0.02)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: 12,
            }}
          >
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 16, fontWeight: 700, color: '#0F172A' }}>{wt.name}</div>
              <div style={{ fontSize: 12, color: '#64748B', marginTop: 4 }}>{wt.description}</div>
              <div style={{ display: 'flex', gap: 16, marginTop: 8 }}>
                <span style={{ fontSize: 12, color: selected ? '#1A56DB' : '#64748B', fontWeight: 500 }}>
                  {wt.durationMinutes} мин
                </span>
                <span style={{ fontSize: 12, color: selected ? '#1A56DB' : '#64748B', fontWeight: 600 }}>
                  {wt.basePrice} ₽
                </span>
              </div>
            </div>
            {selected ? (
              <svg width="24" height="24" viewBox="0 0 24 24" fill="#1A56DB">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
              </svg>
            ) : (
              <div style={{ width: 24, height: 24, borderRadius: '50%', border: '2px solid #E2E8F0' }} />
            )}
          </div>
        )
      })}

      {extraServices.length > 0 && (
        <>
          <h3 style={{ fontSize: 16, fontWeight: 600, color: '#0F172A', marginTop: 8 }}>Дополнительно</h3>
          <div style={{ background: '#FFFFFF', borderRadius: 16, border: '1px solid #E2E8F0', overflow: 'hidden' }}>
            {extraServices.map((svc: Service, i: number) => {
              const checked = extras.has(svc.id)
              const isIncluded = washTypes.find((w: WashType) => w.id === washTypeId)?.includedExtraIds?.includes(svc.id)
              const isLast = i === extraServices.length - 1

              return (
                <div
                  key={svc.id}
                  onClick={() => !isIncluded && onExtraToggle(svc.id)}
                  style={{
                    padding: '14px 16px',
                    borderBottom: isLast ? 'none' : '1px solid #E2E8F0',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                    cursor: isIncluded ? 'default' : 'pointer',
                    opacity: isIncluded ? 0.5 : 1,
                  }}
                >
                  <div
                    style={{
                      width: 20,
                      height: 20,
                      borderRadius: 6,
                      border: checked ? 'none' : '2px solid #E2E8F0',
                      background: checked ? '#1A56DB' : 'transparent',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                    }}
                  >
                    {checked && (
                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                        <polyline points="20 6 9 17 4 12"/>
                      </svg>
                    )}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 14, fontWeight: 500, color: '#0F172A' }}>{svc.name}</div>
                  </div>
                  <div style={{ fontSize: 13, fontWeight: 600, color: '#1A56DB' }}>
                    {isIncluded ? 'Включено' : `+${svc.price} ₽`}
                  </div>
                </div>
              )
            })}
          </div>
        </>
      )}
    </div>
  )
}

// ─── Step 1: Date & Time ─────────────────────────────────────────────────────
function Step1DateTime({
  days, selectedDate, onDateChange, selectedSlot, onSlotChange,
  isSlotAvailable, getDuration, loadingSlots,
}: any) {
  const monthNames = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек']
  const dayNames = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб']

  const isToday = (d: Date) => {
    const t = new Date()
    return d.getDate() === t.getDate() && d.getMonth() === t.getMonth() && d.getFullYear() === t.getFullYear()
  }

  const slots = Array.from({ length: 28 }, (_, i) => {
    const hour = 8 + Math.floor(i / 2)
    const minute = (i % 2) * 30
    const available = isSlotAvailable(hour, minute)
    const duration = getDuration()
    const startMinutes = hour * 60 + minute
    const endMinutes = startMinutes + duration + 5
    const overflow = endMinutes > 22 * 60 ? endMinutes - 22 * 60 : 0
    const isTooLong = overflow > 480
    return { index: i, hour, minute, available, overflow, isTooLong }
  })

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      <h3 style={{ fontSize: 16, fontWeight: 600, color: '#0F172A' }}>Выберите дату</h3>
      <div style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingBottom: 4 }}>
        {days.map((d: Date) => {
          const sel = d.getTime() === selectedDate.getTime()
          return (
            <div
              key={d.toISOString()}
              onClick={() => onDateChange(d)}
              style={{
                minWidth: 62,
                height: 82,
                borderRadius: 14,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 4,
                cursor: 'pointer',
                background: sel ? '#1A56DB' : '#FFFFFF',
                border: `1px solid ${sel ? '#1A56DB' : '#E2E8F0'}`,
                boxShadow: sel ? '0 3px 8px rgba(26, 86, 219, 0.25)' : 'none',
              }}
            >
              <span style={{ fontSize: 10, fontWeight: 600, color: sel ? 'rgba(255,255,255,0.7)' : '#64748B', textTransform: 'uppercase' }}>
                {isToday(d) ? 'Сегодня' : dayNames[d.getDay()]}
              </span>
              <span style={{ fontSize: 22, fontWeight: 700, color: sel ? 'white' : '#0F172A' }}>
                {d.getDate()}
              </span>
              <span style={{ fontSize: 11, color: sel ? 'rgba(255,255,255,0.7)' : '#64748B' }}>
                {monthNames[d.getMonth()]}
              </span>
            </div>
          )
        })}
      </div>

      <h3 style={{ fontSize: 16, fontWeight: 600, color: '#0F172A' }}>Выберите время</h3>

      {loadingSlots ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
          {Array.from({ length: 12 }).map((_, i) => (
            <div key={i} style={{ height: 44, borderRadius: 8, background: '#F1F5F9' }} />
          ))}
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
          {slots.map((slot) => {
            const sel = selectedSlot === slot.index
            const canSelect = !slot.isTooLong && slot.available
            const timeStr = `${String(slot.hour).padStart(2, '0')}:${String(slot.minute).padStart(2, '0')}`
            const overflowHour = slot.overflow > 0 ? Math.floor((8 * 60 + slot.overflow) / 60) : 0
            const overflowMin = slot.overflow > 0 ? (8 * 60 + slot.overflow) % 60 : 0

            return (
              <div
                key={slot.index}
                onClick={() => canSelect && onSlotChange(slot.index)}
                style={{
                  padding: '8px 4px',
                  borderRadius: 8,
                  textAlign: 'center',
                  cursor: canSelect ? 'pointer' : 'not-allowed',
                  background: sel ? '#1A56DB' : canSelect ? '#FFFFFF' : '#F1F5F9',
                  border: `2px solid ${sel ? '#1A56DB' : slot.overflow > 0 ? '#E53935' : '#E2E8F0'}`,
                }}
              >
                <div style={{ fontSize: 11, fontWeight: 700, color: sel ? 'white' : canSelect ? '#0F172A' : '#ADB5C8' }}>
                  {timeStr}
                </div>
                {slot.overflow > 0 && !slot.isTooLong && (
                  <div style={{ fontSize: 9, fontWeight: 600, color: '#E53935', marginTop: 2 }}>
                    Завтра до {String(overflowHour).padStart(2, '0')}:{String(overflowMin).padStart(2, '0')}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

// ─── Step 2: Confirm ─────────────────────────────────────────────────────────
function Step2Confirm({ date, washType, extras, services, name, car, plate, finalPrice, totalDuration }: any) {
  const formatDuration = (minutes: number) => {
    const h = Math.floor(minutes / 60)
    const m = minutes % 60
    if (h > 0 && m > 0) return `${h} ч ${m} мин`
    if (h > 0) return `${h} ч`
    return `${m} мин`
  }

  const extraList = extras
    .filter((id: string) => !washType?.includedExtraIds?.includes(id))
    .map((id: string) => services.find((s: Service) => s.id === id))
    .filter(Boolean)

  const infoRow = (label: string, value: string) => (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid #E2E8F0' }}>
      <span style={{ fontSize: 14, color: '#64748B' }}>{label}</span>
      <span style={{ fontSize: 14, fontWeight: 500, color: '#0F172A', textAlign: 'right' }}>{value}</span>
    </div>
  )

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div style={{ background: '#FFFFFF', borderRadius: 16, border: '1px solid #E2E8F0', boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)', padding: 20 }}>
        <h3 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#0F172A' }}>Подтверждение записи</h3>
        {infoRow('Дата и время', date.toLocaleString('ru-RU', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }))}
        {infoRow('Клиент', name)}
        {infoRow('Авто', `${car} · ${plate}`)}
        {infoRow('Услуга', washType?.name || '')}
        {extraList.length > 0 && infoRow('Дополнительно', extraList.map((s: Service) => s.name).join(', '))}
        {infoRow('Длительность', formatDuration(totalDuration))}
      </div>

      <div
        style={{
          background: 'linear-gradient(135deg, #1A56DB 0%, #3B82F6 100%)',
          borderRadius: 16,
          padding: 20,
          color: 'white',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <span style={{ fontSize: 15, fontWeight: 600 }}>Итого к оплате</span>
        <span style={{ fontSize: 24, fontWeight: 700 }}>{finalPrice} ₽</span>
      </div>
    </div>
  )
}
