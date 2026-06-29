import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminReviewsPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Reviews Page</div>
}
