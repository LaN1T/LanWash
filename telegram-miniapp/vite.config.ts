import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    allowedHosts: ['localhost', '127.0.0.1'],
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
  build: {
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks(id: string) {
          const vendorDeps = ['react', 'react-dom', 'react-router-dom', 'axios', 'zustand']
          if (vendorDeps.some((dep) => id.includes(`node_modules/${dep}`))) {
            return 'vendor'
          }
          return null
        },
      },
    },
  },
  oxc: {
    drop_console: true,
    drop_debugger: true,
  },
})