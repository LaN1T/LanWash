import React from 'react'
import { useAuthStore } from '../stores/authStore'
import BottomNav from './BottomNav'
import WasherNav from './WasherNav'
import AdminNav from './AdminNav'

interface LayoutProps {
  children: React.ReactNode
  hideNav?: boolean
}

function RoleNav() {
  const { user } = useAuthStore()

  if (user?.role === 'admin') return <AdminNav />
  if (user?.role === 'washer') return <WasherNav />
  return <BottomNav />
}

export default function Layout({ children, hideNav }: LayoutProps) {
  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg-page)', paddingBottom: hideNav ? 0 : 80 }}>
      {children}
      {!hideNav && <RoleNav />}
    </div>
  )
}
