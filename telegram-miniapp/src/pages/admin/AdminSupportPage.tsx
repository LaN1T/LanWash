import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminSupportPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Support Page</div>
}
