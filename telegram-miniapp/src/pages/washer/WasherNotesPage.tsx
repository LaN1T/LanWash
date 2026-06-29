import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function WasherNotesPage() {
  useRoleGuard(['washer'])
  return <div style={{ padding: 16 }}>Washer Notes Page</div>
}
