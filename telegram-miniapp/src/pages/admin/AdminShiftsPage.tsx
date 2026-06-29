import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminShiftsPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Shifts Page</div>
}
