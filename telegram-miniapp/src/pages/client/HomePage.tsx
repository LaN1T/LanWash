import { Link } from 'react-router-dom'
import { useEffect, useRef, useState } from 'react'
import { useAuthStore } from '../../stores/authStore'
import { useCatalogStore } from '../../stores/catalogStore'
import { getGreeting } from '../../utils/validators'

const formatPrice = (price: number): string =>
  `${price.toLocaleString('ru-RU')} ₽`

export default function HomePage() {
  const { user } = useAuthStore()
  const { services, promos, loading, error, fetch } = useCatalogStore()
  const [refreshing, setRefreshing] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)
  const touchStartY = useRef<number | null>(null)
  const pullDistance = useRef<number>(0)

  useEffect(() => {
    fetch()
  }, [fetch])

  const handleRefresh = async () => {
    setRefreshing(true)
    await fetch()
    setRefreshing(false)
  }

  const onTouchStart = (e: React.TouchEvent) => {
    const el = containerRef.current
    if (!el) return
    if (el.scrollTop === 0) {
      touchStartY.current = e.touches[0].clientY
      pullDistance.current = 0
    }
  }

  const onTouchMove = (e: React.TouchEvent) => {
    if (touchStartY.current === null) return
    const y = e.touches[0].clientY
    const delta = y - touchStartY.current
    if (delta > 0 && containerRef.current?.scrollTop === 0) {
      pullDistance.current = Math.min(delta, 80)
    }
  }

  const onTouchEnd = () => {
    if (pullDistance.current > 60) {
      void handleRefresh()
    }
    touchStartY.current = null
    pullDistance.current = 0
  }

  const displayedServices = services.slice(0, 6)

  return (
    <div
      ref={containerRef}
      onTouchStart={onTouchStart}
      onTouchMove={onTouchMove}
      onTouchEnd={onTouchEnd}
      style={{
        padding: 16,
        minHeight: '100vh',
        overflowY: 'auto',
        overscrollBehaviorY: 'contain',
      }}
    >
      {/* Pull-to-refresh indicator */}
      {(refreshing || pullDistance.current > 0) && (
        <div
          style={{
            height: refreshing ? 40 : pullDistance.current,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#64748B',
            fontSize: 13,
            transition: refreshing ? undefined : 'height 0.1s ease-out',
          }}
        >
          {refreshing ? 'Обновление...' : 'Отпустите для обновления'}
        </div>
      )}

      {/* Header with time-based greeting */}
      <div style={{ marginBottom: 20 }}>
        <p style={{ fontSize: 15, color: '#64748B', marginBottom: 4 }}>
          {getGreeting()},{' '}
          <span style={{ color: '#0F172A', fontWeight: 600 }}>
            {user?.displayName || 'друг'}
          </span>
        </p>
      </div>

      {/* Main CTA Card */}
      <Link to="/booking" style={{ textDecoration: 'none' }}>
        <div
          style={{
            background: 'linear-gradient(135deg, #1A56DB 0%, #3B82F6 100%)',
            borderRadius: 20,
            padding: '28px 24px',
            marginBottom: 16,
            boxShadow: '0 8px 24px rgba(26, 86, 219, 0.35)',
            color: 'white',
            cursor: 'pointer',
            textAlign: 'center',
          }}
        >
          <div
            style={{
              width: 68,
              height: 68,
              borderRadius: '50%',
              background: 'rgba(255,255,255,0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              margin: '0 auto 14px',
            }}
          >
            <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/>
              <circle cx="7" cy="17" r="2"/>
              <path d="M9 17h6"/>
              <circle cx="17" cy="17" r="2"/>
            </svg>
          </div>
          <h2 style={{ fontSize: 20, fontWeight: 700, marginBottom: 6 }}>
            Записаться на мойку
          </h2>
          <p style={{ fontSize: 14, opacity: 0.8, marginBottom: 18 }}>
            Выберите дату, время и услуги
          </p>
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              background: 'white',
              color: '#1A56DB',
              padding: '10px 24px',
              borderRadius: 10,
              fontSize: 15,
              fontWeight: 700,
            }}
          >
            Записаться
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#1A56DB" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12h14M12 5l7 7-7 7"/>
            </svg>
          </div>
        </div>
      </Link>

      {/* Loading state */}
      {loading && !refreshing && (
        <div style={{ marginBottom: 20 }}>
          <div
            style={{
              height: 120,
              borderRadius: 16,
              background: '#E2E8F0',
              marginBottom: 12,
              animation: 'pulse 1.5s infinite',
            }}
          />
          <div
            style={{
              height: 80,
              borderRadius: 16,
              background: '#E2E8F0',
              animation: 'pulse 1.5s infinite',
            }}
          />
        </div>
      )}

      {/* Error state */}
      {!loading && error && (
        <div
          style={{
            background: '#FEF2F2',
            border: '1px solid #FECACA',
            borderRadius: 16,
            padding: 16,
            marginBottom: 20,
            color: '#B91C1C',
            fontSize: 14,
          }}
        >
          {error}
          <button
            onClick={handleRefresh}
            style={{
              marginTop: 10,
              padding: '8px 16px',
              borderRadius: 8,
              border: 'none',
              background: '#1A56DB',
              color: 'white',
              fontSize: 13,
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Повторить
          </button>
        </div>
      )}

      {/* Promos section */}
      {!loading && promos.length > 0 && (
        <div style={{ marginBottom: 20 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <h3 style={{ fontSize: 16, fontWeight: 600, color: '#0F172A', margin: 0 }}>
              Акции и спецпредложения
            </h3>
            <Link to="/promos" style={{ fontSize: 13, color: '#1A56DB', textDecoration: 'none', fontWeight: 600 }}>
              Все
            </Link>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {promos.map((promo) => (
              <Link
                key={promo.id}
                to={`/booking?promo=${promo.id}`}
                style={{ textDecoration: 'none' }}
              >
                <div
                  style={{
                    background: '#FFFFFF',
                    borderRadius: 16,
                    border: '1px solid #E2E8F0',
                    boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
                    padding: '14px 16px',
                    cursor: 'pointer',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div
                      style={{
                        width: 40,
                        height: 40,
                        borderRadius: 12,
                        background: '#EFF4FF',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0,
                        color: '#1A56DB',
                        fontSize: 14,
                        fontWeight: 700,
                      }}
                    >
                      {promo.discountPercent ? `-${promo.discountPercent}%` : '%'}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: 15, fontWeight: 600, color: '#0F172A', marginBottom: 2 }}>
                        {promo.title}
                      </div>
                      <div style={{ fontSize: 13, color: '#64748B', lineHeight: 1.4 }}>
                        {promo.description}
                      </div>
                    </div>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#94A3B8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M9 18l6-6-6-6"/>
                    </svg>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Services section */}
      {!loading && displayedServices.length > 0 && (
        <div style={{ marginBottom: 20 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <h3 style={{ fontSize: 16, fontWeight: 600, color: '#0F172A', margin: 0 }}>
              Популярные услуги
            </h3>
            <Link to="/services" style={{ fontSize: 13, color: '#1A56DB', textDecoration: 'none', fontWeight: 600 }}>
              Все
            </Link>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            {displayedServices.map((service) => (
              <Link
                key={service.id}
                to="/booking"
                style={{ textDecoration: 'none' }}
              >
                <div
                  style={{
                    background: '#FFFFFF',
                    borderRadius: 16,
                    border: '1px solid #E2E8F0',
                    boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
                    padding: 14,
                    cursor: 'pointer',
                    height: '100%',
                    boxSizing: 'border-box',
                  }}
                >
                  <div style={{ fontSize: 14, fontWeight: 600, color: '#0F172A', marginBottom: 6 }}>
                    {service.name}
                  </div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: '#1A56DB' }}>
                    {formatPrice(service.price)}
                  </div>
                  {service.category && (
                    <div style={{ fontSize: 11, color: '#64748B', marginTop: 6, textTransform: 'uppercase', letterSpacing: 0.3 }}>
                      {service.category}
                    </div>
                  )}
                </div>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Empty catalog state */}
      {!loading && !error && services.length === 0 && promos.length === 0 && (
        <div
          style={{
            background: '#FFFFFF',
            borderRadius: 16,
            border: '1px solid #E2E8F0',
            padding: 24,
            marginBottom: 20,
            textAlign: 'center',
            color: '#64748B',
            fontSize: 14,
          }}
        >
          Услуги и акции скоро появятся
        </div>
      )}

      {/* How it works */}
      <div style={{ marginBottom: 8 }}>
        <h3 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12, color: '#0F172A' }}>
          Как записаться
        </h3>
      </div>
      <div
        style={{
          background: '#FFFFFF',
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
          padding: 20,
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {[
            { num: '1', title: 'Укажите данные авто', sub: 'Марка, модель и государственный номер' },
            { num: '2', title: 'Выберите услуги', sub: 'Тип мойки и дополнительные опции' },
            { num: '3', title: 'Выберите дату и время', sub: 'Удобный слот из доступного расписания' },
            { num: '4', title: 'Подтвердите запись', sub: 'Проверьте итог и нажмите «Записаться»' },
          ].map((step) => (
            <div key={step.num} style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
              <div
                style={{
                  width: 28,
                  height: 28,
                  borderRadius: '50%',
                  background: 'linear-gradient(135deg, #1A56DB, #3B82F6)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: 'white',
                  fontSize: 12,
                  fontWeight: 700,
                  flexShrink: 0,
                }}
              >
                {step.num}
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: '#0F172A' }}>
                  {step.title}
                </div>
                <div style={{ fontSize: 12, color: '#64748B', marginTop: 2 }}>
                  {step.sub}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <style>{`
        @keyframes pulse {
          0% { opacity: 1; }
          50% { opacity: 0.5; }
          100% { opacity: 1; }
        }
      `}</style>
    </div>
  )
}
