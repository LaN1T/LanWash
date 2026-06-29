import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminNotesPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Notes Page</div>
}
