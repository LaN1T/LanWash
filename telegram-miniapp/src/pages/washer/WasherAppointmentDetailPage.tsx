import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function WasherAppointmentDetailPage() {
  useRoleGuard(['washer'])
  return <div style={{ padding: 16 }}>Washer Appointment Detail Page</div>
}
