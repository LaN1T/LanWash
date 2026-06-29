interface CloudStorage {
  getItem(key: string, callback: (err: Error | null, value: string | null) => void): void
  setItem(key: string, value: string, callback: (err: Error | null, saved: boolean) => void): void
  removeItem(key: string, callback: (err: Error | null, removed: boolean) => void): void
}

interface TelegramWebApp {
  initData: string
  initDataUnsafe: {
    user?: {
      id: number
      first_name: string
      last_name?: string
      username?: string
      language_code?: string
      photo_url?: string
    }
  }
  expand: () => void
  ready: () => void
  CloudStorage?: CloudStorage
  HapticFeedback: {
    impactOccurred: (style: 'light' | 'medium' | 'heavy') => void
  }
  themeParams: Record<string, string>
  setHeaderColor: (color: string) => void
  close: () => void
}

declare global {
  interface Window {
    Telegram?: {
      WebApp?: TelegramWebApp
    }
  }
}

export {}