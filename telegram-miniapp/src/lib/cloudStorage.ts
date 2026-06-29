export const STORAGE_KEYS = {
  ACCESS_TOKEN: 'lw_access_token',
  USER: 'lw_user',
} as const

function getTg(): Window['Telegram']['WebApp'] | undefined {
  return window.Telegram?.WebApp
}

export async function getItem(key: string): Promise<string | null> {
  const tg = getTg()
  const storage = tg?.CloudStorage
  if (storage) {
    return new Promise((resolve) => {
      storage.getItem(key, (err, value) => {
        if (err) {
          console.warn('CloudStorage getItem error', err)
          resolve(null)
        } else if (value == null || value === '') {
          resolve(null)
        } else {
          resolve(value)
        }
      })
    })
  }
  try {
    return localStorage.getItem(key)
  } catch (e) {
    console.warn('localStorage getItem error', e)
    return null
  }
}

export async function setItem(key: string, value: string): Promise<void> {
  const tg = getTg()
  const storage = tg?.CloudStorage
  if (storage) {
    return new Promise((resolve, reject) => {
      storage.setItem(key, value, (err, saved) => {
        if (err || !saved) {
          console.warn('CloudStorage setItem error', err)
          reject(err ?? new Error(`CloudStorage setItem failed for key "${key}"`))
        } else {
          resolve()
        }
      })
    })
  }
  try {
    localStorage.setItem(key, value)
  } catch (e) {
    throw new Error(`localStorage setItem failed for key "${key}": ${e}`)
  }
}

export async function removeItem(key: string): Promise<void> {
  const tg = getTg()
  const storage = tg?.CloudStorage
  if (storage) {
    return new Promise((resolve, reject) => {
      storage.removeItem(key, (err, removed) => {
        if (err || !removed) {
          console.warn('CloudStorage removeItem error', err)
          reject(err ?? new Error(`CloudStorage removeItem failed for key "${key}"`))
        } else {
          resolve()
        }
      })
    })
  }
  try {
    localStorage.removeItem(key)
  } catch (e) {
    throw new Error(`localStorage removeItem failed for key "${key}": ${e}`)
  }
}

export const cloudStorage = { STORAGE_KEYS, getItem, setItem, removeItem }
