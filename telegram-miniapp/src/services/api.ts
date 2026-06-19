import axios from 'axios'
import { useAuthStore } from '../stores/authStore'

export const api = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000,
  withCredentials: true,
})

let refreshPromise: Promise<string | null> | null = null

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config
    if (error.response?.status === 401 && originalRequest) {
      if (originalRequest.url === '/auth/refresh') {
        return Promise.reject(error)
      }

      if (!refreshPromise) {
        refreshPromise = api
          .post('/auth/refresh', {}, { withCredentials: true })
          .then((res) => {
            const { user, access_token } = res.data
            useAuthStore.getState().setAuth(user, access_token)
            return access_token as string
          })
          .catch(() => {
            useAuthStore.getState().logout()
            return null
          })
          .finally(() => {
            refreshPromise = null
          })
      }

      const newToken = await refreshPromise
      if (!newToken) {
        return Promise.reject(error)
      }

      originalRequest.headers.Authorization = `Bearer ${newToken}`
      return api(originalRequest)
    }
    return Promise.reject(error)
  }
)