import { useAuthStore } from '../../stores/authStore'

export default function ProfilePage() {
  const { user, logout } = useAuthStore()

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ marginBottom: 16 }}>Профиль</h2>
      <div
        style={{
          background: 'var(--tg-theme-secondary-bg-color)',
          borderRadius: 12,
          padding: 16,
          marginBottom: 16,
        }}
      >
        <div style={{ marginBottom: 8 }}>
          <strong>Имя:</strong> {user?.displayName}
        </div>
        <div style={{ marginBottom: 8 }}>
          <strong>Телефон:</strong> {user?.phone || '—'}
        </div>
        <div style={{ marginBottom: 8 }}>
          <strong>Авто:</strong> {user?.carModel || '—'}
        </div>
        <div>
          <strong>Номер:</strong> {user?.carNumber || '—'}
        </div>
      </div>
      <button
        onClick={logout}
        style={{
          width: '100%',
          background: 'var(--tg-theme-secondary-bg-color)',
          color: 'var(--tg-theme-text-color)',
        }}
      >
        Выйти
      </button>
    </div>
  )
}