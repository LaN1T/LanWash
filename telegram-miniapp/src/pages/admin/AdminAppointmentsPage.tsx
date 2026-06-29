import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminAppointmentsPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Appointments Page</div>
}
