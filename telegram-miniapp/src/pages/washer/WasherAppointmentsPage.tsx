import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function WasherAppointmentsPage() {
  useRoleGuard(['washer'])
  return <div style={{ padding: 16 }}>Washer Appointments Page</div>
}
