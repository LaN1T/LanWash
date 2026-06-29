import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminAppointmentDetailPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Appointment Detail Page</div>
}
