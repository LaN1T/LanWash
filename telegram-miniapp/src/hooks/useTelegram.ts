import { useEffect, useState } from 'react'

export function useTelegram() {
  const [initData, setInitData] = useState('')

  useEffect(() => {
    const tg = window.Telegram?.WebApp
    if (!tg) return
    tg.expand()
    tg.ready()
    setInitData(tg.initData)
  }, [])

  return {
    initData,
    tg: window.Telegram?.WebApp,
  }
}