import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function WasherSchedulePage() {
  useRoleGuard(['washer'])
  return <div style={{ padding: 16 }}>Washer Schedule Page</div>
}
