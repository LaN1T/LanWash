import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '../stores/authStore'

type Role = 'client' | 'washer' | 'admin'

export function useRoleGuard(requiredRoles: Role[]) {
  const { user } = useAuthStore()
  const navigate = useNavigate()
  const allowed = user ? requiredRoles.includes(user.role) : false

  useEffect(() => {
    if (user && !requiredRoles.includes(user.role)) {
      navigate('/', { replace: true })
    }
  }, [user, requiredRoles, navigate])

  return { allowed, role: user?.role }
}
