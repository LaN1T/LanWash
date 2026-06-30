import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { scanQr } from '../../services/appointments'
import { useRoleGuard } from '../../hooks/useRoleGuard'

export default function WasherQrPage() {
  useRoleGuard(['washer'])
  const navigate = useNavigate()
  const [qrId, setQrId] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!qrId.trim()) return
    setLoading(true)
    try {
      await scanQr(qrId.trim())
      navigate(`/appointments/${qrId.trim()}`)
    } catch (err: any) {
      const msg = err?.response?.data?.detail || 'Не удалось обработать QR'
      alert(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ padding: 16 }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 22, color: '#0F172A' }}>QR-сканер</h2>
      <p style={{ color: '#64748B', marginBottom: 20 }}>
        Введите ID записи вручную или отсканируйте QR-код клиента.
      </p>

      <form onSubmit={handleSubmit}>
        <label style={{ display: 'block', fontSize: 14, color: '#64748B', marginBottom: 6 }}>ID записи</label>
        <input
          value={qrId}
          onChange={(e) => setQrId(e.target.value)}
          placeholder="Например: 550e8400-e29b-41d4"
          style={{
            width: '100%',
            padding: 12,
            borderRadius: 10,
            border: '1px solid #E2E8F0',
            fontSize: 15,
            marginBottom: 12,
            boxSizing: 'border-box',
          }}
        />
        <button
          type="submit"
          disabled={loading || !qrId.trim()}
          style={{
            width: '100%',
            padding: '14px 0',
            borderRadius: 12,
            border: 'none',
            background: '#1A56DB',
            color: '#fff',
            fontWeight: 700,
            fontSize: 16,
            cursor: 'pointer',
            opacity: loading || !qrId.trim() ? 0.7 : 1,
          }}
        >
          {loading ? 'Обработка...' : 'Найти запись'}
        </button>
      </form>
    </div>
  )
}