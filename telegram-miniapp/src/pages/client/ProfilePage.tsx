import { useEffect, useState } from 'react'
import { useAuthStore } from '../../stores/authStore'
import type { User } from '../../stores/authStore'
import {
  getUserStats,
  updateProfile,
  unlinkTelegram,
  type UserStats,
  type ProfileUpdatePayload,
} from '../../services/profile'

export default function ProfilePage() {
  const { user, token, logout, setAuth } = useAuthStore()

  const [stats, setStats] = useState<UserStats | null>(null)
  const [loadingStats, setLoadingStats] = useState(true)
  const [statsError, setStatsError] = useState<string | null>(null)
  const [editMode, setEditMode] = useState(false)
  const [form, setForm] = useState({
    displayName: '',
    phone: '',
    email: '',
    carModel: '',
    carNumber: '',
    currentPassword: '',
    newPassword: '',
    confirmNewPassword: '',
  })
  const [saving, setSaving] = useState(false)
  const [unlinking, setUnlinking] = useState(false)
  const [showUnlinkPassword, setShowUnlinkPassword] = useState(false)
  const [unlinkPassword, setUnlinkPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  useEffect(() => {
    if (user?.username) {
      setLoadingStats(true)
      setStatsError(null)
      getUserStats(user.username)
        .then(setStats)
        .catch((err) => {
          console.error(err)
          setStatsError('Не удалось загрузить статистику')
        })
        .finally(() => setLoadingStats(false))
    } else {
      setLoadingStats(false)
    }
  }, [user])

  useEffect(() => {
    if (user) {
      setForm((prev) => ({
        ...prev,
        displayName: user.displayName || '',
        phone: user.phone || '',
        email: user.email || '',
        carModel: user.carModel || '',
        carNumber: user.carNumber || '',
      }))
    }
  }, [user])

  const handleChange =
    (field: keyof typeof form) =>
    (e: React.ChangeEvent<HTMLInputElement>) => {
      setForm((prev) => ({ ...prev, [field]: e.target.value }))
    }

  const resetEdit = () => {
    setEditMode(false)
    setError(null)
    setSuccess(null)
    setForm((prev) => ({
      ...prev,
      currentPassword: '',
      newPassword: '',
      confirmNewPassword: '',
    }))
  }

  const handleSave = async () => {
    if (!user || token === null) return

    setSaving(true)
    setError(null)
    setSuccess(null)

    try {
      if (form.newPassword && form.newPassword !== form.confirmNewPassword) {
        throw new Error('Новые пароли не совпадают')
      }

      const payload: ProfileUpdatePayload = {
        displayName: form.displayName.trim() || undefined,
        phone: form.phone.trim() || undefined,
        email: form.email.trim() || undefined,
        carModel: form.carModel.trim() || undefined,
        carNumber: form.carNumber.trim() || undefined,
      }

      if (form.newPassword) {
        if (!form.currentPassword) {
          throw new Error('Для смены пароля введите текущий пароль')
        }
        payload.currentPassword = form.currentPassword
        payload.newPassword = form.newPassword
      }

      const updated: User = await updateProfile(user.id, payload)
      await setAuth(updated, token)
      resetEdit()
      setSuccess('Профиль обновлён')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка сохранения профиля')
    } finally {
      setSaving(false)
    }
  }

  const handleUnlink = async () => {
    if (!user || token === null) return

    setUnlinking(true)
    setError(null)
    setSuccess(null)

    try {
      await unlinkTelegram(unlinkPassword)
      await setAuth({ ...user, telegramLinked: false }, token)
      setSuccess('Telegram отвязан от аккаунта')
      setShowUnlinkPassword(false)
      setUnlinkPassword('')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка отвязки Telegram')
    } finally {
      setUnlinking(false)
    }
  }

  const handleLogout = async () => {
    if (!window.confirm('Вы уверены, что хотите выйти из аккаунта?')) return
    await logout()
  }

  const infoRow = (label: string, value: string) => (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        padding: '14px 0',
        borderBottom: '1px solid #E2E8F0',
      }}
    >
      <span style={{ fontSize: 14, color: '#64748B' }}>{label}</span>
      <span style={{ fontSize: 14, fontWeight: 500, color: '#0F172A' }}>
        {value || '—'}
      </span>
    </div>
  )

  const inputStyle: React.CSSProperties = {
    width: '100%',
    padding: '12px 14px',
    borderRadius: 10,
    border: '1px solid #E2E8F0',
    fontSize: 15,
    outline: 'none',
    boxSizing: 'border-box',
  }

  const labelStyle: React.CSSProperties = {
    display: 'block',
    fontSize: 13,
    color: '#64748B',
    marginBottom: 4,
    fontWeight: 500,
  }

  const buttonPrimaryStyle: React.CSSProperties = {
    width: '100%',
    padding: '14px 24px',
    borderRadius: 12,
    background: '#1A56DB',
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: 600,
    border: 'none',
    cursor: 'pointer',
  }

  const buttonSecondaryStyle: React.CSSProperties = {
    width: '100%',
    padding: '14px 24px',
    borderRadius: 12,
    background: '#FFFFFF',
    color: '#0F172A',
    fontSize: 15,
    fontWeight: 600,
    border: '1px solid #E2E8F0',
    cursor: 'pointer',
  }

  const telegramLinked = user?.telegramLinked ?? false

  return (
    <div style={{ padding: 16 }}>
      {(error || success) && (
        <div
          style={{
            background: error ? '#FEF2F2' : '#F0FDF4',
            color: error ? '#B91C1C' : '#15803D',
            borderRadius: 12,
            padding: '12px 16px',
            marginBottom: 16,
            fontSize: 14,
            fontWeight: 500,
          }}
        >
          {error || success}
        </div>
      )}

      {/* Avatar + Name */}
      <div
        style={{
          background: '#FFFFFF',
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          boxShadow:
            '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
          padding: 24,
          marginBottom: 16,
          textAlign: 'center',
        }}
      >
        <div
          style={{
            width: 80,
            height: 80,
            borderRadius: '50%',
            background: 'linear-gradient(135deg, #1A56DB 0%, #3B82F6 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 16px',
            color: 'white',
            fontSize: 28,
            fontWeight: 700,
            boxShadow: '0 8px 24px rgba(26, 86, 219, 0.35)',
          }}
        >
          {(user?.displayName || 'U').charAt(0).toUpperCase()}
        </div>
        <div
          style={{
            fontSize: 20,
            fontWeight: 700,
            color: '#0F172A',
            marginBottom: 4,
          }}
        >
          {user?.displayName || 'Пользователь'}
        </div>
        <div
          style={{
            display: 'inline-block',
            padding: '4px 12px',
            borderRadius: 8,
            background: '#EFF4FF',
            color: '#1A56DB',
            fontSize: 12,
            fontWeight: 600,
          }}
        >
          {user?.role === 'admin'
            ? 'Администратор'
            : user?.role === 'washer'
              ? 'Мойщик'
              : 'Клиент'}
        </div>
      </div>

      {/* Stats Card */}
      {!loadingStats && stats && (
        <div
          style={{
            background: '#FFFFFF',
            borderRadius: 16,
            border: '1px solid #E2E8F0',
            boxShadow:
              '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
            padding: 20,
            marginBottom: 16,
          }}
        >
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: 12,
            }}
          >
            <div style={{ fontSize: 14, fontWeight: 600, color: '#0F172A' }}>
              {stats.level}
            </div>
            <div style={{ fontSize: 12, color: '#64748B' }}>
              {stats.points} баллов
            </div>
          </div>
          <div
            style={{
              height: 8,
              borderRadius: 4,
              background: '#F1F5F9',
              overflow: 'hidden',
              marginBottom: 12,
            }}
          >
            <div
              style={{
                height: '100%',
                width: `${Math.min(100, Math.max(0, stats.levelProgress))}%`,
                borderRadius: 4,
                background: 'linear-gradient(90deg, #1A56DB, #3B82F6)',
                transition: 'width 0.5s ease',
              }}
            />
          </div>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr 1fr',
              gap: 16,
              marginTop: 16,
            }}
          >
            <div style={{ textAlign: 'center' }}>
              <div
                style={{ fontSize: 20, fontWeight: 700, color: '#1A56DB' }}
              >
                {stats.totalAppointments}
              </div>
              <div style={{ fontSize: 12, color: '#64748B' }}>Всего записей</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div
                style={{ fontSize: 20, fontWeight: 700, color: '#059669' }}
              >
                {stats.totalSpent}₽
              </div>
              <div style={{ fontSize: 12, color: '#64748B' }}>Потрачено</div>
            </div>
          </div>
        </div>
      )}
      {!loadingStats && statsError && !stats && (
        <div
          style={{
            background: '#FEF2F2',
            borderRadius: 16,
            border: '1px solid #FECACA',
            padding: 20,
            marginBottom: 16,
            color: '#B91C1C',
            fontSize: 14,
            fontWeight: 500,
          }}
        >
          {statsError}
        </div>
      )}

      {/* Info Card */}
      <div
        style={{
          background: '#FFFFFF',
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          boxShadow:
            '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
          padding: '8px 20px 20px',
          marginBottom: 16,
        }}
      >
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            padding: '12px 0 8px',
          }}
        >
          <div
            style={{
              fontSize: 11,
              fontWeight: 600,
              color: '#64748B',
              letterSpacing: 0.8,
            }}
          >
            ЛИЧНЫЕ ДАННЫЕ
          </div>
          {!editMode && (
            <button
              onClick={() => {
                setEditMode(true)
                setError(null)
                setSuccess(null)
              }}
              style={{
                background: 'transparent',
                border: 'none',
                color: '#1A56DB',
                fontSize: 13,
                fontWeight: 600,
                cursor: 'pointer',
                padding: 0,
              }}
            >
              Редактировать
            </button>
          )}
        </div>

        {editMode ? (
          <form
            onSubmit={(e) => {
              e.preventDefault()
              void handleSave()
            }}
          >
            <div style={{ marginBottom: 12 }}>
              <label htmlFor="displayName" style={labelStyle}>
                Имя
              </label>
              <input
                id="displayName"
                type="text"
                placeholder="Ваше имя"
                value={form.displayName}
                onChange={handleChange('displayName')}
                disabled={saving}
                style={inputStyle}
              />
            </div>
            <div style={{ marginBottom: 12 }}>
              <label htmlFor="phone" style={labelStyle}>
                Телефон
              </label>
              <input
                id="phone"
                type="tel"
                placeholder="+7..."
                value={form.phone}
                onChange={handleChange('phone')}
                disabled={saving}
                style={inputStyle}
              />
            </div>
            <div style={{ marginBottom: 12 }}>
              <label htmlFor="email" style={labelStyle}>
                Email
              </label>
              <input
                id="email"
                type="email"
                placeholder="email@example.com"
                value={form.email}
                onChange={handleChange('email')}
                disabled={saving}
                style={inputStyle}
              />
            </div>
            <div style={{ marginBottom: 12 }}>
              <label htmlFor="carModel" style={labelStyle}>
                Автомобиль
              </label>
              <input
                id="carModel"
                type="text"
                placeholder="Марка и модель"
                value={form.carModel}
                onChange={handleChange('carModel')}
                disabled={saving}
                style={inputStyle}
              />
            </div>
            <div style={{ marginBottom: 16 }}>
              <label htmlFor="carNumber" style={labelStyle}>
                Госномер
              </label>
              <input
                id="carNumber"
                type="text"
                placeholder="А000АА00"
                value={form.carNumber}
                onChange={handleChange('carNumber')}
                disabled={saving}
                style={inputStyle}
              />
            </div>

            <div
              style={{
                background: '#F8FAFC',
                borderRadius: 12,
                padding: 16,
                marginBottom: 16,
              }}
            >
              <div
                style={{
                  fontSize: 13,
                  fontWeight: 600,
                  color: '#0F172A',
                  marginBottom: 12,
                }}
              >
                Смена пароля
              </div>
              <div style={{ marginBottom: 12 }}>
                <label htmlFor="currentPassword" style={labelStyle}>
                  Текущий пароль
                </label>
                <input
                  id="currentPassword"
                  type="password"
                  placeholder="••••••••"
                  value={form.currentPassword}
                  onChange={handleChange('currentPassword')}
                  disabled={saving}
                  style={inputStyle}
                />
              </div>
              <div style={{ marginBottom: 12 }}>
                <label htmlFor="newPassword" style={labelStyle}>
                  Новый пароль
                </label>
                <input
                  id="newPassword"
                  type="password"
                  placeholder="••••••••"
                  value={form.newPassword}
                  onChange={handleChange('newPassword')}
                  disabled={saving}
                  style={inputStyle}
                />
              </div>
              <div>
                <label htmlFor="confirmNewPassword" style={labelStyle}>
                  Подтвердите новый пароль
                </label>
                <input
                  id="confirmNewPassword"
                  type="password"
                  placeholder="••••••••"
                  value={form.confirmNewPassword}
                  onChange={handleChange('confirmNewPassword')}
                  disabled={saving}
                  style={inputStyle}
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={saving}
              style={{
                ...buttonPrimaryStyle,
                opacity: saving ? 0.7 : 1,
                marginBottom: 10,
              }}
            >
              {saving ? 'Сохранение...' : 'Сохранить'}
            </button>
            <button
              type="button"
              disabled={saving}
              onClick={resetEdit}
              style={{
                ...buttonSecondaryStyle,
                opacity: saving ? 0.7 : 1,
              }}
            >
              Отмена
            </button>
          </form>
        ) : (
          <>
            {infoRow('Телефон', user?.phone || '')}
            {user?.email && infoRow('Email', user.email)}
            {infoRow('Автомобиль', user?.carModel || '')}
            {infoRow('Госномер', user?.carNumber || '')}
            {infoRow('Логин', user?.username || '')}
          </>
        )}
      </div>

      {/* Telegram */}
      <div
        style={{
          background: '#FFFFFF',
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          boxShadow:
            '0 4px 16px rgba(26, 86, 219, 0.06), 0 1px 4px rgba(0, 0, 0, 0.03)',
          padding: 20,
          marginBottom: 16,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: telegramLinked ? 16 : 0,
          }}
        >
          <div>
            <div
              style={{
                fontSize: 14,
                fontWeight: 600,
                color: '#0F172A',
                marginBottom: 4,
              }}
            >
              Telegram
            </div>
            <div style={{ fontSize: 13, color: '#64748B' }}>
              {telegramLinked
                ? 'Аккаунт привязан к Telegram'
                : 'Telegram не привязан'}
            </div>
          </div>
          {telegramLinked && (
            <div
              style={{
                width: 10,
                height: 10,
                borderRadius: '50%',
                background: '#22C55E',
              }}
            />
          )}
        </div>
        {telegramLinked && !showUnlinkPassword && (
          <button
            onClick={() => setShowUnlinkPassword(true)}
            disabled={unlinking}
            style={{
              width: '100%',
              padding: '14px 24px',
              borderRadius: 12,
              background: '#FFFFFF',
              color: '#DC2626',
              fontSize: 15,
              fontWeight: 600,
              border: '1px solid #E2E8F0',
              cursor: 'pointer',
              opacity: unlinking ? 0.7 : 1,
            }}
          >
            {unlinking ? 'Отвязка...' : 'Отвязать Telegram'}
          </button>
        )}
        {telegramLinked && showUnlinkPassword && (
          <div
            style={{
              background: '#F8FAFC',
              borderRadius: 12,
              padding: 16,
            }}
          >
            <div style={{ marginBottom: 12 }}>
              <label htmlFor="unlinkPassword" style={labelStyle}>
                Введите пароль для подтверждения
              </label>
              <input
                id="unlinkPassword"
                type="password"
                placeholder="••••••••"
                value={unlinkPassword}
                onChange={(e) => setUnlinkPassword(e.target.value)}
                disabled={unlinking}
                style={inputStyle}
              />
            </div>
            <button
              onClick={() => void handleUnlink()}
              disabled={unlinking || !unlinkPassword}
              style={{
                ...buttonPrimaryStyle,
                opacity: unlinking || !unlinkPassword ? 0.7 : 1,
                marginBottom: 10,
              }}
            >
              {unlinking ? 'Отвязка...' : 'Подтвердить отвязку'}
            </button>
            <button
              type="button"
              disabled={unlinking}
              onClick={() => {
                setShowUnlinkPassword(false)
                setUnlinkPassword('')
              }}
              style={{
                ...buttonSecondaryStyle,
                opacity: unlinking ? 0.7 : 1,
              }}
            >
              Отмена
            </button>
          </div>
        )}
      </div>

      {/* Logout */}
      <button
        onClick={() => void handleLogout()}
        style={{
          width: '100%',
          padding: '16px 24px',
          borderRadius: 12,
          background: '#FFFFFF',
          color: '#DC2626',
          fontSize: 15,
          fontWeight: 600,
          border: '1px solid #E2E8F0',
          cursor: 'pointer',
        }}
      >
        Выйти из аккаунта
      </button>
    </div>
  )
}
