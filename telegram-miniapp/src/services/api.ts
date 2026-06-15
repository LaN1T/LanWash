import axios from 'axios'

export const api = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('lanwash_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('lanwash_token')
      // Prevent infinite reload loops if the server keeps rejecting the session.
      if (!sessionStorage.getItem('lanwash_auth_reload')) {
        sessionStorage.setItem('lanwash_auth_reload', '1')
        window.location.reload()
      }
    }
    return Promise.reject(error)
  }
)