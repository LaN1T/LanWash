interface CloudStorage {
  getItem(key: string, callback: (err: Error | null, value: string | null) => void): void
  setItem(key: string, value: string, callback: (err: Error | null, saved: boolean) => void): void
  removeItem(key: string, callback: (err: Error | null, removed: boolean) => void): void
}

interface TelegramWebApp {
  initData: string
  initDataUnsafe: { user?: { id: number; username?: string; first_name?: string; photo_url?: string } }
  expand(): void
  ready(): void
  CloudStorage?: CloudStorage
}

const STORAGE_KEYS = {
  ACCESS_TOKEN: 'lw_access_token',
  USER: 'lw_user',
} as const

function getTg(): TelegramWebApp | undefined {
  return window.Telegram?.WebApp
}

export async function getItem(key: string): Promise<string | null> {
  const tg = getTg()
  const storage = tg?.CloudStorage
  if (storage) {
    return new Promise((resolve) => {
      storage.getItem(key, (err, value) => {
        if (err || value == null || value === '') {
          resolve(null)
        } else {
          resolve(value)
        }
      })
    })
  }
  return localStorage.getItem(key)
}

export async function setItem(key: string, value: string): Promise<void> {
  const tg = getTg()
  const storage = tg?.CloudStorage
  if (storage) {
    return new Promise((resolve, reject) => {
      storage.setItem(key, value, (err, saved) => {
        if (err || !saved) {
          reject(err)
        } else {
          resolve()
        }
      })
    })
  }
  localStorage.setItem(key, value)
}

export async function removeItem(key: string): Promise<void> {
  const tg = getTg()
  const storage = tg?.CloudStorage
  if (storage) {
    return new Promise((resolve, reject) => {
      storage.removeItem(key, (err, removed) => {
        if (err || !removed) {
          reject(err)
        } else {
          resolve()
        }
      })
    })
  }
  localStorage.removeItem(key)
}

export const cloudStorage = { STORAGE_KEYS, getItem, setItem, removeItem }
