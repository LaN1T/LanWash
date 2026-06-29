import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminProfilePage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Profile Page</div>
}
