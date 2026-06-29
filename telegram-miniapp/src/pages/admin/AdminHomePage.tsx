import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminHomePage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Home Page</div>
}
