import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminConsumablesPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Consumables Page</div>
}
