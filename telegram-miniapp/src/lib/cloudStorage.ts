export const STORAGE_KEYS = {
  ACCESS_TOKEN: 'lw_access_token',
  USER: 'lw_user',
} as const

function getTg() {
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
