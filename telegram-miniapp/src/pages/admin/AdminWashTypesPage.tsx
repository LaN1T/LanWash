import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminWashTypesPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Wash Types Page</div>
}
