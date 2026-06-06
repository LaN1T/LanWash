import React from 'react'
import BottomNav from './BottomNav'

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ minHeight: '100vh', paddingBottom: 70 }}>
      {children}
      <BottomNav />
    </div>
  )
}