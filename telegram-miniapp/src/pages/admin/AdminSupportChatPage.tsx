import { useRoleGuard } from '../../hooks/useRoleGuard'
export default function AdminSupportChatPage() {
  useRoleGuard(['admin'])
  return <div style={{ padding: 16 }}>Admin Support Chat Page</div>
}
