import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminSubscriptionPlansPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Subscription Plans Page</div>
}
