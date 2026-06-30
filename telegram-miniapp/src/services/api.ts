import axios from 'axios'
import { useAuthStore } from '../stores/authStore'
import { isAuthResponse } from './auth'

export const api = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' },
  timeout: 10000,
  withCredentials: true,
})

let refreshPromise: Promise<string | null> | null = null

api.interceptors.request.use(async (config) => {
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
      if (originalRequest.url?.endsWith('/auth/refresh')) {
        useAuthStore.getState().logout()
        return Promise.reject(error)
      }

      if (!refreshPromise) {
        refreshPromise = api
          .post('/auth/refresh', {}, { withCredentials: true })
          .then(async (res) => {
            if (!isAuthResponse(res.data)) {
              await useAuthStore.getState().logout()
              return null
            }
            const { user, access_token } = res.data
            await useAuthStore.getState().setAuth(user, access_token)
            return access_token
          })
          .catch(async () => {
            await useAuthStore.getState().logout()
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
    if (error.response?.status === 403) {
      const msg = 'Доступ запрещён'
      if (window.Telegram?.WebApp?.showAlert) {
        window.Telegram.WebApp.showAlert(msg)
      } else {
        alert(msg)
      }
    }
    return Promise.reject(error)
  }
)
