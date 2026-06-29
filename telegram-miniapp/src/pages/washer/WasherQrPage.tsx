import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function WasherQrPage() {
  useRoleGuard(['washer'])
  return <div style={{ padding: 16 }}>Washer QR Page</div>
}
