import { Link } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { useAuthStore } from '../../stores/authStore'
import { api } from '../../services/api'
import { getGreeting } from '../../utils/validators'

export default function HomePage() {
  const { user } = useAuthStore()
  const [promoCount, setPromoCount] = useState(0)

  useEffect(() => {
    api.get('/services/promos').then((res) => {
      setPromoCount((res.data || []).length)
    }).catch(() => {
      setPromoCount(0)
    })
  }, [])

  return (
    <div style={{ padding: 16 }}>
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

      {/* Promos button */}
      <Link to="/promos" style={{ textDecoration: 'none' }}>
        <div
          style={{
            background: '#FFFFFF',
            borderRadius: 16,
            border: '1px solid #E2E8F0',
            boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
            padding: '16px 18px',
            marginBottom: 20,
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            cursor: 'pointer',
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 12,
              background: '#EFF4FF',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#1A56DB" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M7 7h10l-3 7H7z"/>
              <path d="M20.4 7H22l-3 7h-1.4"/>
              <circle cx="9" cy="19" r="1.5"/>
              <circle cx="17" cy="19" r="1.5"/>
              <path d="M7 7l-2-2"/>
              <path d="M17 7l2-2"/>
            </svg>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 600, color: '#0F172A' }}>
              Акции и спецпредложения
            </div>
            <div style={{ fontSize: 13, color: '#64748B' }}>
              {promoCount === 0
                ? 'Нет активных акций'
                : `${promoCount} ${promoCount === 1 ? 'предложение' : promoCount < 5 ? 'предложения' : 'предложений'}`}
            </div>
          </div>
          {promoCount > 0 && (
            <div
              style={{
                padding: '4px 10px',
                borderRadius: 8,
                background: 'linear-gradient(135deg, #1A56DB, #3B82F6)',
                color: 'white',
                fontSize: 12,
                fontWeight: 700,
              }}
            >
              {promoCount}
            </div>
          )}
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#64748B" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M9 18l6-6-6-6"/>
          </svg>
        </div>
      </Link>

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
    </div>
  )
}
