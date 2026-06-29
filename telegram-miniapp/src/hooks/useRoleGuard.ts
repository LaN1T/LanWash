import { useAuthStore } from '../stores/authStore'

type Role = 'client' | 'washer' | 'admin'

export function useRoleGuard(requiredRoles: Role[]) {
  const { user } = useAuthStore()
  const allowed = user ? requiredRoles.includes(user.role) : false
  return { allowed, role: user?.role }
}
