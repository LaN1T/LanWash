import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function WasherProfilePage() {
  useRoleGuard(['washer'])
  return <div style={{ padding: 16 }}>Washer Profile Page</div>
}
