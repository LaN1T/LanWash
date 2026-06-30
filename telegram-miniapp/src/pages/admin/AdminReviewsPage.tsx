import { useEffect, useState } from 'react'
import { getAllReviews, moderateReview, deleteReview } from '../../services/reviews'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function AdminReviewsPage() {
  useRoleGuard(['admin'])
  const [reviews, setReviews] = useState<import('../../services/reviews').Review[]>([])
  const [loading, setLoading] = useState(false)

  const fetchReviews = (signal?: AbortSignal) => {
    setLoading(true)
    getAllReviews(100, signal)
      .then(setReviews)
      .catch((err) => {
        if (err.name !== 'AbortError') alert('Не удалось загрузить отзывы')
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchReviews(controller.signal)
    return () => controller.abort()
  }, [])

  const handleModerate = async (id: number, isPublished: boolean) => {
    try {
      await moderateReview(id, { isPublished })
      fetchReviews()
    } catch {
      alert('Ошибка')
    }
  }

  const handleDelete = async (id: number) => {
    if (!window.confirm('Удалить отзыв?')) return
    try {
      await deleteReview(id)
      fetchReviews()
    } catch {
      alert('Ошибка удаления')
    }
  }

  return (
    <div style={{ padding: 16, paddingBottom: 100 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>Отзывы</h2>

      {loading ? (
        <p>Загрузка...</p>
      ) : reviews.length === 0 ? (
        <p style={{ color: '#64748B' }}>Отзывов нет</p>
      ) : (
        reviews.map((r) => (
          <div
            key={r.id}
            style={{
              background: '#fff',
              borderRadius: 12,
              padding: 12,
              marginBottom: 8,
              border: '1px solid #E2E8F0',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <strong style={{ color: '#0F172A' }}>{r.userName}</strong>
              <span style={{ color: '#F59E0B', fontWeight: 700 }}>{'★'.repeat(r.rating)}{'☆'.repeat(5 - r.rating)}</span>
            </div>
            <div style={{ fontSize: 14, color: '#0F172A', marginBottom: 8 }}>{r.comment}</div>
            <div style={{ fontSize: 12, color: '#64748B', marginBottom: 8 }}>
              {new Date(r.createdAt).toLocaleDateString('ru-RU')} ·{' '}
              {r.isPublished ? 'Опубликован' : 'На модерации'}
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              {!r.isPublished && (
                <button
                  onClick={() => handleModerate(r.id, true)}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: 'none',
                    background: '#10B981',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Опубликовать
                </button>
              )}
              {r.isPublished && (
                <button
                  onClick={() => handleModerate(r.id, false)}
                  style={{
                    padding: '6px 12px',
                    borderRadius: 6,
                    border: 'none',
                    background: '#F59E0B',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Скрыть
                </button>
              )}
              <button
                onClick={() => handleDelete(r.id)}
                style={{
                  padding: '6px 12px',
                  borderRadius: 6,
                  border: 'none',
                  background: '#FEF2F2',
                  color: '#DC2626',
                  cursor: 'pointer',
                }}
              >
                Удалить
              </button>
            </div>
          </div>
        ))
      )}
    </div>
  )
}