import React from 'react'
import BottomNav from './BottomNav'

interface LayoutProps {
  children: React.ReactNode
  hideNav?: boolean
}

export default function Layout({ children, hideNav }: LayoutProps) {
  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg-page)', paddingBottom: hideNav ? 0 : 80 }}>
      {children}
      {!hideNav && <BottomNav />}
    </div>
  )
}
