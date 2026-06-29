import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function WasherTipsPage() {
  useRoleGuard(['washer'])
  return <div style={{ padding: 16 }}>Washer Tips Page</div>
}
