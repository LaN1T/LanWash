import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminWashersPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Washers Page</div>
}
