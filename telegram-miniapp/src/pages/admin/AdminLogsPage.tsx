import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminLogsPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Logs Page</div>
}
