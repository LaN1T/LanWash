import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminReportsPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Reports Page</div>
}
