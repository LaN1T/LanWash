import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminUsersPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Users Page</div>
}
