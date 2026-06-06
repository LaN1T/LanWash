import { useEffect, useState } from 'react'

export function useTelegram() {
  const [initData, setInitData] = useState('')
  const [ready, setReady] = useState(false)

  useEffect(() => {
    let attempts = 0
    const maxAttempts = 50 // 5 seconds

    const checkTelegram = () => {
      const tg = window.Telegram?.WebApp
      if (tg) {
        tg.expand()
        tg.ready()
        setInitData(tg.initData || '')
        setReady(true)
        return true
      }
      return false
    }

    if (checkTelegram()) return

    const interval = setInterval(() => {
      attempts++
      if (checkTelegram() || attempts >= maxAttempts) {
        clearInterval(interval)
        if (attempts >= maxAttempts) {
          setReady(true) // No Telegram WebApp available
        }
      }
    }, 100)

    return () => clearInterval(interval)
  }, [])

  return {
    initData,
    ready,
    tg: window.Telegram?.WebApp,
    isInTelegram: !!window.Telegram?.WebApp,
  }
}
