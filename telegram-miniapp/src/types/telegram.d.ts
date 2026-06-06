declare global {
  interface Window {
    Telegram: {
      WebApp: {
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
        HapticFeedback: {
          impactOccurred: (style: 'light' | 'medium' | 'heavy') => void
        }
        themeParams: Record<string, string>
        setHeaderColor: (color: string) => void
        close: () => void
      }
    }
  }
}

export {}