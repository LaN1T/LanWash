import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../../services/api'

interface Promo {
  id: string
  name: string
  description: string
  discountPercent: number
  price: number
  weekendOnly: boolean
  washTypeId: string
  includedExtraIds: string[]
}

export default function PromosPage() {
  const navigate = useNavigate()
  const [promos, setPromos] = useState<Promo[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/services/promos').then((res) => {
      setPromos(res.data || [])
      setLoading(false)
    }).catch(() => {
      setPromos([])
      setLoading(false)
    })
  }, [])

  if (loading) {
    return (
      <div style={{ padding: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
          <button
            onClick={() => navigate('/')}
            style={{
              background: 'none',
              border: 'none',
              padding: 8,
              cursor: 'pointer',
            }}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#64748B" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M19 12H5M12 19l-7-7 7-7"/>
            </svg>
          </button>
          <h2 style={{ fontSize: 18, fontWeight: 700, color: '#0F172A' }}>Акции</h2>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {[1, 2].map((i) => (
            <div key={i} style={{ height: 140, borderRadius: 16, background: '#F1F5F9' }} />
          ))}
        </div>
      </div>
    )
  }

  return (
    <div style={{ padding: 16 }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <button
          onClick={() => navigate('/')}
          style={{
            background: 'none',
            border: 'none',
            padding: 8,
            cursor: 'pointer',
          }}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#64748B" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5M12 19l-7-7 7-7"/>
          </svg>
        </button>
        <h2 style={{ fontSize: 18, fontWeight: 700, color: '#0F172A' }}>Акции и спецпредложения</h2>
      </div>

      {promos.length === 0 ? (
        <div style={{ textAlign: 'center', padding: 40, color: '#64748B' }}>
          <p style={{ fontSize: 15 }}>Нет активных акций</p>
          <p style={{ fontSize: 13, marginTop: 4 }}>Загляните позже</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {promos.map((promo) => (
            <div
              key={promo.id}
              style={{
                background: '#FFFFFF',
                borderRadius: 16,
                border: '1px solid #E2E8F0',
                boxShadow: '0 4px 16px rgba(26, 86, 219, 0.06)',
                padding: 20,
                position: 'relative',
                overflow: 'hidden',
              }}
            >
              {/* Discount badge */}
              {promo.discountPercent > 0 && (
                <div
                  style={{
                    position: 'absolute',
                    top: 16,
                    right: 16,
                    background: 'linear-gradient(135deg, #DC2626, #EF4444)',
                    color: 'white',
                    padding: '6px 12px',
                    borderRadius: 20,
                    fontSize: 13,
                    fontWeight: 700,
                  }}
                >
                  -{promo.discountPercent}%
                </div>
              )}

              <h3 style={{ fontSize: 18, fontWeight: 700, color: '#0F172A', marginBottom: 8, paddingRight: 60 }}>
                {promo.name}
              </h3>
              <p style={{ fontSize: 14, color: '#64748B', marginBottom: 16, lineHeight: 1.5 }}>
                {promo.description}
              </p>

              {promo.weekendOnly && (
                <div
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 6,
                    background: '#FFFBEB',
                    color: '#D97706',
                    padding: '6px 12px',
                    borderRadius: 8,
                    fontSize: 12,
                    fontWeight: 600,
                    marginBottom: 12,
                  }}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#D97706" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="10"/>
                    <path d="M12 16v-4M12 8h.01"/>
                  </svg>
                  Только по выходным
                </div>
              )}

              <button
                onClick={() => navigate(`/booking?promo=${promo.id}`)}
                style={{
                  width: '100%',
                  padding: '14px 24px',
                  borderRadius: 12,
                  background: '#1A56DB',
                  color: 'white',
                  fontSize: 15,
                  fontWeight: 600,
                  border: 'none',
                  cursor: 'pointer',
                }}
              >
                Записаться по акции
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
