import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminServicesPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Services Page</div>
}
